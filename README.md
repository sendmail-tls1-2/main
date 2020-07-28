# Fake sendmail for Windows with TLS v1.2 support
This is a revival of the fake sendmail program by Byron Jones (https://www.glob.com.au/sendmail/), if you don't need TLS v1.1 or v1.2 support please use the original version, there is no support available on both versions and they are both not actively maintained.

# ABOUT
sendmail.exe is a simple windows console application that emulates sendmail's -t option to deliver emails piped via stdin.

it is intended to ease running unix code that has /usr/lib/sendmail hardcoded as an email delivery means or program's that use the sendmail pipe method, for example as php on windows uses.

it doesn't support deferred delivery, and requires an smtp server to perform the actual delivery of the messages.

I've been using the fake sendmail program for quite a few years, but when using Office 365 smtp servers TLS v1.0 isn't enough any more, they require TLS v1.2, so I tried to recompile the source that Byron Jones included in the release on his site. With a little fiddle and some minor changes I was able to recompile the Delphi 2007 program, in the current community edition of Delphi builder 10.3 (Rio) from Embarcadero. That contains a newer Indy version, that has support for TLS v1.2 and forced TLS v1.1+ in the sendmail code.

To save anybody else the hassle to recompile the fake sendmail from the source code, I made it available on this github site, including the source code, just as the original version is.

# INSTALL
- Download sendmail.zip from this github and unzip it's contents to a temp folder on your system

- copy sendmail.exe, sendmail.ini and both .dll files to \usr\lib on the drive where the unix application is installed. eg. if your application is installed on c:\, sendmail.exe and sendmail.ini need to be copied to c:\usr\lib\sendmail.exe and c:\usr\lib\sendmail.ini or an other directory if the path isn't hardcoded in the application that's using it.

- configure smtp server and default domain in sendmail.ini.

# USING FAKE SENDMAIL
generally all you need to do is install sendmail.exe in \usr\lib, and existing code that calls /usr/lib/sendmail will work.

if you're coding new applications, all you need to do is construct your email message with complete headers, then pipe it to 'sendmail.exe -t'

# USING FAKE SENDMAIL WITH PHP ON WINDOWS
With PHP the sendmail path isn't hardcoded, it can be configured in the php.ini file, so the sendmail.exe and it's files can be placed together anywhere on the system, the config states "Unix only" for the sendmail_path option, but it works on windows to, it overrides the 3 Win32 only options above it, see the PHP manual (https://www.php.net/manual/en/mail.configuration.php#ini.sendmail-path)

Note: If your SMTP server doesn't require authentication or encryption, you can just use the SMTP an SMPT_PORT config parameters to specify a smtp server, you don't need sendmail.exe then.

PHP.ini:
```
[mail function]
; For Win32 only.
; http://php.net/smtp
;SMTP = localhost
; http://php.net/smtp-port
;smtp_port = 25

; For Win32 only.
; http://php.net/sendmail-from
;sendmail_from = me@example.com

; For Unix only.  You may supply arguments as well (default: "sendmail -t -i").
; http://php.net/sendmail-path
sendmail_path = "C:\sendmail\sendmail.exe -t"

; Force the addition of the specified parameters to be passed as extra parameters
; to the sendmail binary. These parameters will always replace the value of
; the 5th parameter to mail().
;mail.force_extra_parameters =

; Add X-PHP-Originating-Script: that will include uid of the script followed by the filename
mail.add_x_header = On
```
In the sendmail.ini you specify the smtp server address and the username/password combo

# ERRORLEVEL
Sendmail sets the ERRORLEVEL to 0 when successful.

Version 28 and higher set the ERRORLEVEL to -1 if the email was unable to be delivered.
The value was changed to provide better compatibility with PHP, which expects the ERRORLEVEL to be -1 on failure.

# DEBUG LOGGING
uncomment the debug_logfile entry in sendmail.ini and try to resend a failed message. this should create debug.log in the same directory as sendmail.exe showing the complete SMTP transcript.

# MORE INFORMATION
Please see the orginial versions site: https://www.glob.com.au/sendmail/

# LICENSE AND SOURCE
This program is released under the bsd license: https://www.glob.com.au/sendmail/license.html

The license details and full source code (Delphi 10.3 Rio) are included in the source folder in the zipfile and this repository.
