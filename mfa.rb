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

# terms:
#  sid = {:id, :secret}
#  secret= "xxxxx"

example_secrets = [
  {id: "b@gmail", secret: "CSWKEH3YUILXYCEU2V7T5GNWNM2PAW4V2ZHFOW6JLW6MEGY2OGJO7RIIQ37IEI3D"},
  {id: "bobby@gmail", secret: "7I4IW6KYA7JXNUQ55A33FNPHEVVVAOWJ2BWNV6ZMKYWMFRLLUPO5AFDL2RCDR77F"},
  {id: "bob@aws", secret: "WI27ZBHPOF4IAZRPOCZKAPDNRZHPCB6ECWSMWJQGCWRVOGVUVC3WBMJI5NFFMG2B"},
  {id: "other service", secret: "s4e4632x6n2d7a5h"}
]


# Make sure secret isn't empty. If it is, try to retrieve it from the OS X keychain, and if it's not there, prompt the user
def get_and_validate_secret_from_keychain(sid)
  sid['secret'] = ( str_ok?(sid['secret']) || str_ok?(get_secret_from_keychain(sid['id'])) || str_ok?(get_secret_from_user(sid['id'])) ).upcase
  secret_valid?(sid)
  sid
end

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


def secret_valid?(sid)
  begin
    Base32.decode(sid['secret'])
  rescue
    puts "#{sid['id']} has an invalid base32 secret:\n     #{sid['secret']}"
    raise
  end
end


def format_opt (int)
  "%06d" % int
end


# Check for typos in our secrets first
def check_for_typos(secrets)
  secrets.each { |sid| secret_valid?(sid) }
end


def print_all_with_urls(secrets)
  secrets.each do |sid|
    print "%06d  %s" % [generate_otp(timecode(Time.now),sid['id']), sid['secret']]
    puts "   otpauth://totp/#{sid['secret']}?secret=#{sid['id']}"
  end
end


def print_all_with_index(secrets)
  secrets.each_with_index do |sid,i|
    puts "%s - %s" % [i, sid['id']]
  end
end


def print_by_index_number(i, sid, quiet)
  otp = format_opt( generate_otp(timecode(Time.now),sid['secret']) )
  if quiet
    puts (otp)
  else
    `echo #{otp} | pbcopy`
    puts ("#{otp} #{sid[0]}  <-- copied to clipboard")
  end
end


def print_scored_matches(secrets_with_score, quiet)
  # Sort the matched secrets
  secrets_with_score_sorted = secrets_with_score.sort { |a,b| a[:score]<=>b[:score] }

  # Copy first match to clipboard
  copied_secret = secrets_with_score_sorted.first['secret']
  otp = format_opt( generate_otp(timecode(Time.now),copied_secret) )
  `echo #{otp} | pbcopy`

  if quiet
    sid = secrets_with_score_sorted.first
    puts format_opt( generate_otp(timecode(Time.now),sid['secret']) )
  else
    first=true
    secrets_with_score_sorted.each do |sid|
      otp = format_opt( generate_otp(timecode(Time.now),sid['id']) )
      print("#{otp} #{sid['secret']}")
      if first
        print(" <-- copied to clipboard\n")
        first=false
      else
        puts
      end
    end
  end
end


def args_match?(arg0, secrets)
  prefix_regex = Regexp.new("^"+ARGV[0]+"(.*)")
  wildcard_regex = Regexp.new(ARGV[0])
  # Builds a hash of secrets (where the key matched the regexp), consisting of: the key, the secret, and regexp score
  matches = secrets.select { |s| prefix_regex.match(s['id']) }
  puts matches
  if matches.empty?
    puts "no prefixes"
    matches = secrets.select { |s| wildcard_regex.match(s['id']) }
  end
  matches
end


def score_matches(arg0, secrets, quiet)
  prefix_regex = Regexp.new("^"+ARGV[0]+"(.*)")
  wildcard_regex = Regexp.new(ARGV[0])
  # Builds a hash of secrets (where the key matched the regexp), consisting of: the key, the secret, and regexp score
  def match_and_score(regex, secrets)
    secrets.map do |sid|
      r = regex.match(sid['secret'])
      # return nil (if nil) or the secret components plus the score (from the regex match)
      r && sid.merge({score: r[1]})
    end.compact
  end
  secrets_with_prefix_score = match_and_score(prefix_regex, secrets)
  secrets_with_wildcard_score = match_and_score(wildcard_regex, secrets)
  secrets_with_prefix_score.empty? ? secrets_with_wildcard_score : secrets_with_prefix_score
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
# Check that file exists
begin
  secrets = YAML.load(File.read(base_path + "/mfa.yml"))
rescue
  print("Couldn't find #{base_path}/mfa.yml. Using example secrets instead.\n")
  secrets = example_secrets
end

args = ARGV
if args.member?('-q')
  quiet = true
  args.delete('-q')
else
  quiet = false
end

# alias_method :get_and_validate_secret, :get_and_validate_secret_from_ruby
alias get_and_validate_secret get_and_validate_secret_from_keychain

# If no arguments, output all OTPs
if args.empty?
  unless quiet
    print_all_with_index(secrets)
  end
#  print_all_with_urls(secrets)
else
  arg = args[0]
  # Check to see if the arg is a possible index number
  if numeric?(arg) && (arg.to_i < secrets.count)
    print_by_index_number(arg.to_i, get_and_validate_secret(secrets[arg.to_i]), quiet)
  else
    # Print any secrets whose description the arg matches
    secrets_with_score = score_matches(arg, secrets, quiet)
    unless secrets_with_score.empty?
      secrets_with_score.map! { |s| get_and_validate_secret(s) }
      print_scored_matches(secrets_with_score, quiet)
    end
  end
end



