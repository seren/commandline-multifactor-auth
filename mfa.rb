# Author: Seren Thompson
# Description: Generates identical one-time passwords as Google Authenticator would generate, given the same secret.
# License: MIT
# Updated: 2016-08-16

# Note: QR code url: otpauth://totp/DESCRIPTION?secret=SECRET

require "base32"
require "openssl"
require "yaml"
require "keychain"

@interval = 30
@digits = 6
@digest = "sha1"

def get_secret_from_keychain(description)
  keychain_entry = Keychain.generic_passwords.where(:service => 'mfa-secret-'+description).first
  keychain_entry.nil? ? '' : keychain_entry.password
end

def save_secret_to_keychain(description, secret)
  Keychain.generic_passwords.create(:service => 'mfa-secret-'+description, :password => secret)
end

def prompt(default, *args)
  print(*args)
  result = STDIN.gets.chomp.strip
  return result.empty? ? default : result
end

def get_secret_from_user(id)
  secret = prompt("", "What is the secret for account '"+id+"'? ")
  save_secret_to_keychain(id, secret)
  secret
end

def timecode(time)
  time.utc.to_i / @interval
end

def byte_secret(secret)
  Base32.decode(secret)
end

def int_to_bytestring(int, padding = 8)
  result = []
  until int == 0
    result << (int & 0xFF).chr
    int >>= 8
  end
  result.reverse.join.rjust(padding, 0.chr)
end


def generate_otp(input,secret)
  hmac = OpenSSL::HMAC.digest(
    OpenSSL::Digest.new(@digest),
    byte_secret(secret),
    int_to_bytestring(input)
  )

  offset = hmac[19].ord & 0xf
  code = (hmac[offset].ord & 0x7f) << 24 |
    (hmac[offset + 1].ord & 0xff) << 16 |
    (hmac[offset + 2].ord & 0xff) << 8 |
    (hmac[offset + 3].ord & 0xff)
  code % 10 ** @digits
end


def secret_valid?(name,secret)
  begin
    Base32.decode(secret)
  rescue
    puts "#{name} has an invalid base32 secret:\n     #{secret}"
    raise
  end
end


def format_opt (int)
  "%06d" % int
end


# Check for typos in our secrets first
def check_for_typos(secrets)
  secrets.each { |s| secret_valid?(s[0], s[1]) }
end


def print_all_with_urls(secrets)
  secrets.each do |s|
    print "%06d  %s" % [generate_otp(timecode(Time.now),s[1]), s[0]]
    puts "   otpauth://totp/#{s[0]}?secret=#{s[1]}"
  end
end


def print_all_with_index(secrets)
  secrets.each_with_index do |s,i|
    puts "%06d  %s - %s" % [generate_otp(timecode(Time.now),s[1]), i, s[0]]
  end
end


def print_by_index_number(i, secrets)
  secret = secrets[ARGV[0].to_i]
  otp = format_opt( generate_otp(timecode(Time.now),secret[1]) )
  `echo #{otp} | pbcopy`
  puts ("#{otp} #{secret[0]}  <-- copied to clipboard")
end


def print_scored_matches(secrets_with_score)
  # Sort the matched secrets
  secrets_with_score_sorted = secrets_with_score.sort { |a,b| a[2]<=>b[2] }

  # Copy first match to clipboard
  copied_secret = secrets_with_score_sorted.first[1]
  otp = format_opt( generate_otp(timecode(Time.now),copied_secret) )
  `echo #{otp} | pbcopy`

  first=true
  secrets_with_score_sorted.each do |s|
    otp = format_opt( generate_otp(timecode(Time.now),s[1]) )
    print("#{otp} #{s[0]}")
    if first
      print(" <-- copied to clipboard\n")
      first=false
    else
      puts
    end
  end
end


def args_match?(arg0, secrets)
  reg = Regexp.new("^"+ARGV[0]+"(.*)")
  # Builds a hash of secrets (where the key matched the regexp), consisting of: the key, the secret, and regexp score
  matches = secrets.select { |s| reg.match(s[1]) }
end


def score_matches(arg0, secrets)
  reg = Regexp.new("^"+ARGV[0]+"(.*)")
  # Builds a hash of secrets (where the key matched the regexp), consisting of: the key, the secret, and regexp score

  secrets_with_score = secrets.map do |s|
    r = reg.match(s[0])
    if r.nil?
      nil
    else
      score = r[1]
      [s[0],s[1],score]
    end
  end.compact
end


def numeric?(object)
  true if Float(object) rescue false
end

def str_ok?(s)
  (s.nil? || s.empty?) ? false : s
end


## Main ##

# Read in descriptions and, potentially, secrets from yaml. If secrets are blank, we'll get them from the OS X keychain.
base_path = File.expand_path(File.dirname(__FILE__))
begin
  secrets = YAML.load(File.read(base_path + "/mfa.yml"))
rescue
  print("Couldn't find #{base_path}/mfa.yml. Using example secrets instead.\n")
  secrets = [
      ["b@gmail", "CSWKEH3YUILXYCEU2V7T5GNWNM2PAW4V2ZHFOW6JLW6MEGY2OGJO7RIIQ37IEI3D"],
      ["bobby@gmail", "7I4IW6KYA7JXNUQ55A33FNPHEVVVAOWJ2BWNV6ZMKYWMFRLLUPO5AFDL2RCDR77F"],
      ["bob@aws", "WI27ZBHPOF4IAZRPOCZKAPDNRZHPCB6ECWSMWJQGCWRVOGVUVC3WBMJI5NFFMG2B"],
      ["other service", "s4e4632x6n2d7a5h"]
    ]
end
# Make sure secret isn't empty. If it is, try to retrieve it from the OS X keychain, and if it's not there, prompt the user
secrets.map! do |s|
  id,secret = *s
  s[1] = str_ok?(secret) || str_ok?(get_secret_from_keychain(id)) || str_ok?(get_secret_from_user(id))
  s
end

# Make sure secrets are uppercase
secrets.map! { |s| [s[0],s[1].upcase]}

check_for_typos(secrets)

# If no arguments, output all OTPs
if ARGV.empty?
  print_all_with_index(secrets)
#  print_all_with_urls(secrets)
else
  # See if arg matches any of the secrets' descriptions
  secrets_with_score = score_matches(ARGV[0], secrets)
  # If nothing matched, the arg is either an index number or just wrong.
  unless secrets_with_score.empty?
    print_scored_matches(secrets_with_score)
  else
    # Check to see if the arg is a possible index.
    if numeric?(ARGV[0]) && (ARGV[0].to_i < secrets.count)
      print_by_index_number(ARGV[0].to_i, secrets)
    end
  end
end



