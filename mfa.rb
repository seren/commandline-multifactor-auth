# Author: Seren Thompson
# Description: Generates identical one-time passwords as Google Authenticator would generate, given the same secret.
# License: MIT


require "base32"
require "openssl"

# Secrets from gmail, aws, wordpress, ssh, lastpass, dreamhost, cpanel, etc
secrets={
"b@gmail" => "CSWKEH3YUILXYCEU2V7T5GNWNM2PAW4V2ZHFOW6JLW6MEGY2OGJO7RIIQ37IEI3D",
"bobby@gmail" => "7I4IW6KYA7JXNUQ55A33FNPHEVVVAOWJ2BWNV6ZMKYWMFRLLUPO5AFDL2RCDR77F",
"bob@aws" => "WI27ZBHPOF4IAZRPOCZKAPDNRZHPCB6ECWSMWJQGCWRVOGVUVC3WBMJI5NFFMG2B",
}


@interval = 30
@digits = 6
@digest = "sha1"

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
    OpenSSL::Digest::Digest.new(@digest),
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
    puts "#{name} has an invalide base32 secret:\n     #{secret}"
    raise
  end
end


# Check for typos in our secrets firsst
secrets.each { |k,v| secret_valid?(k,v) }

# If no arguments, output all OTPs
if ARGV.empty?
  secrets.each do |k,v|
    puts "%06d %s" % [generate_otp(timecode(Time.now),v), k]
  end

# If arguments, output matching OPTs ordered my match closness, and copy the first match to the clipboard (on OS X)
else
  reg = Regexp.new("^"+ARGV[0]+"(.*)")
  # Builds a hash of secrets (where the key matched the regexp), consisting of: the key, the secret, and regexp score
  secrets_with_score = secrets.reduce({}) do |a,(k,v)|
    r = reg.match(k)
    if r.nil?
      a
    else
      score = r[1]
      a[k]={:secret => v, :score => score}
      a
    end
  end

  unless secrets_with_score.empty?
    secrets_with_score_sorted = secrets_with_score.sort { |a,b| a[1][:score]<=>b[1][:score] }

    # Copy first match to clipboard
    copied_secret = secrets_with_score_sorted.first[1][:secret]
    otp = format_opt( generate_otp(timecode(Time.now),copied_secret) )
    `echo #{otp} | pbcopy`

    secrets_with_score_sorted.each do |k,v|
      otp = format_opt( generate_otp(timecode(Time.now),v[:secret]) )
      print("#{otp} #{k}")
      (k == secrets_with_score_sorted.first.first) ? puts(" <-- copied to clipboard") : puts("")
    end
 end

end


















