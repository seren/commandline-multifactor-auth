commandline-multifactor-auth
===============

This is ruby script to output one-time passwords as an alternative to using Google Authenticator for multi-factor authentication.

On OS X, if it's given an argument that matches a single entry, that entry will be copied to the clipboard. It may or may not work on other platforms.

It can be used with the TOTP (time-based one-time passwords) that many sites and tools have adopted (eg. gmail, aws, wordpress, ssh, lastpass, dreamhost, cpanel, etc).


## Usage ##

`ruby mfa.rb [optional-secret-name]`

Example:

    $ ruby mfa.rb fred
    892654 fred@cheesypoofs.com <-- copied to clipboard

    $ ruby mfa.rb bob
    807194 bob-aws <-- copied to clipboard
    120680 bobby@gmail

    $ ruby mfa.rb
    355719 0 - b@gmail
    207986 1 - bobby@gmail
    751457 2 - bob-aws
    892654 3 - fred@cheesypoofs.com

    $ ruby mfa.rb 2
    751457 2 - bob-aws <-- copied to clipboard


