commandline-multifactor-auth
===============

This ruby script generates TOTPs (time-based one-time passwords) for multi-factor authentication, as an alternative to using a utility such as Google Authenticator.

On OS X, if it's given an argument that matches a single entry, that entry will be copied to the clipboard. It may or may not work on other platforms.

It can be used with the TOTPs that many sites and tools have adopted (eg. gmail, aws, wordpress, ssh, lastpass, dreamhost, cpanel, etc).

Security note: The secrets can be stored in a plaintext YML file, however it's recommended that the secrets be left blank which will cause the application to get them from the user and store them securely in the OS X keychain. If you choose to store the secrets in the YML file, you should take steps to secure this file, such as storing it on an encrypted volume (ex: TruCrypt, encrypted DMG, etc).


## Installation ##

Run these commands if you don't have ruby environments (rbenv) set-up already. Rbenv makes it easy to run multiple ruby versions and install gems without touching the default system version. It also works without sudo rights.

    brew install rbenv
    rbenv init - >> ~/.profile
    source ~/.profie
    rbenv install 2.3.1

Download the code and it's dependencies

    git clone https://github.com/seren/commandline-multifactor-auth.git
    cd commandline-multifactor-auth
    rbenv local 2.3.1  # this should be some recently version of ruby
    gem install bundler
    bundle install

Set up your first MFA secret

    echo "- - my-first-secret" > mfa.yml
    ruby mfa.rb



## Usage ##

`ruby mfa.rb [optional-secret-name]`

Example:

    $ ruby mfa.rb fred
    892654 fred@cheesypoofs.com <-- copied to clipboard

    $ ruby mfa.rb bob
    807194 bob-aws <-- copied to clipboard
    120680 bobby@gmail

    $ ruby mfa.rb    # no argument given, so nothing copied to clipboard
    355719 0 - b@gmail
    207986 1 - bobby@gmail
    751457 2 - bob-aws
    892654 3 - fred@cheesypoofs.com

    $ ruby mfa.rb 2
    751457 2 - bob-aws <-- copied to clipboard


## Tips ##

Create an alias for this in your .profile (eg. `alias mfa='ruby /Users/bob/scripts/mfa.rb'`) so it will work no matter what directory your are in.
