commandline-mfa
===============

A ruby script to output one-time passwords as an alternative to using Google Authenticator


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

