commandline-mfa
===============

This is ruby script to output one-time passwords as an alternative to using Google Authenticator.

It can be used with the TOTP (time-based one-time passwords) that many sites and tools have adopted (eg. gmail, aws, wordpress, ssh, lastpass, dreamhost, cpanel, etc).


## Usage ##

`ruby mfa.rb [optional-secret-name]`

Example:

    $ ruby mfa.rb
    355719 b@gmail
    207986 bobby@gmail
    751457 bob@aws

    $ ruby mfa.rb bob
    807194 bob@aws <-- copied to clipboard
    120680 bobby@gmail

