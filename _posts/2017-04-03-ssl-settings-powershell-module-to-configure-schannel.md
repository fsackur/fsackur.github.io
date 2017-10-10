---
layout: post
title: SSL settings - powershell module to configure SCHANNEL
date: 2017-04-03 20:37
author: freddiesackur
comments: true
tags: [Uncategorized]
---
It's been a lovely spring day in London. Fortunately, I don't have to go out, because I have a window.

I also have a window of opportunity, as $Beloved is working today. SCRIPT ON!


# SSL ciphers and protocols
If you support businesses on a slower lifecycle, it's likely that servers will need changes to accommodate the changing threat landscape. I get a lot of requests to, for example, disable SSL 3.0 or TLS 1.0, or weaker ciphers such as RC2 or RC4.

I also see Web Application Firewalls, such as Imperva, which require ephemeral key exchange algorithms such as Diffie-Hellman and ECDH to be disabled.

It's a busy life as a sysadmin in 2017, disabling SSL here, Triple-DES there. The way it's often been done is:

	* Edit the registry directly (yawn)
	* Use [IIS Crypto](https://www.nartac.com/Products/IISCrypto) (Unacceptable! Requires use of mouse!)

So I'd like to announce [SslRegConfig](https://github.com/fsackur/SslRegConfig), a powershell module to handle all of this for you.


# SslRegConfig
At the heart of this module is functionality to edit the registry. The relevant keys are all within HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL. Functions in this module accept simple protocol names, and do the heavy lifting on your behalf:

	* Back up the registry
	* Apply correct registry values
	* Document changes made in output

You do need to reboot to be confident that changes are applied.


> ### Warning
> Some changes take effect instantly, others require a reboot. I have not been able to identify consistently which changes need the reboot. You may get non-deterministic results. I suggest applying the change just before the reboot.


### How-to
The main function is Set-SslRegValues, and the main parameters to it are Enable and Disable. These accept protocol names, and can both be used simultaneously:
```powershell
Set-SslRegValues -Enable TLS1.1, TLS1.2 -Disable SSL2.0, SSL3.0, TLS1.0, RC4 -BackupFile C:\backup\schannel.reg
```
Note that if you pass the same protocol or cipher name to both Enable and Disable, the protocol will be enabled.


### Output:
```powershell
Property       ValueBefore    ValueAfter
--------       -----------    -----------
SSL2.0         Enabled        Disabled
SSL3.0         Enabled        Disabled
TLS1.0         Enabled        Disabled
TLS1.1         Not configured Enabled
TLS1.2         Not configured Enabled
RC4 40         Not configured Disabled
RC4 56         Not configured Disabled
RC4 64         Not configured Disabled
RC4 128        Not configured Disabled
Diffie-Hellman Not configured Not configured
ECDH           Not configured Not configured
```

# So what else does it do?
If you use TLS as the security layer in RDP, you need to know about (https://www.microsoft.com/en-us/download/details.aspx?id=49074)KB3080079 before you disable TLS 1.0 on 2008 / 2008R2 / Win7 / Vista. This module will check if that applies.

If you use SQL Server, be aware that SQL 2016 is the first version that supports TLS 1.1 and 1.2 on all builds. Therefore, you can break your SQL Server by disabling TLS 1.0. This module will check if that applies, too.

If you disable TLS on a web or middleware server, you might find that that cannot communicate with the SQL Server any more even though you left the SQL box alone. You may need to update your ODBC drivers or SQL Native Client. I'm adding that check in too, and the intention is that you run the assessment across your server estate to identify problems before making changes to SSL or TLS protocols.

HTH!
