---
layout: post
title: How does PowerShell work?
date: 2017-04-03 22:23
author: freddiesackur
comments: true
tags: [Uncategorized]
---
This is a piece about the components of Powershell. There are many blogposts that explain how to achieve a particular result with some of these classes, but not many that give you an...


## Overview of PowerShell
When you open powershell, you are running an executable called (in Windows) powershell.exe. It could be called anything but it is not the PowerShell class. An excerpt from the (https://msdn.microsoft.com/en-us/library/system.management.automation.powershell)MSDN page for the class:
<blockquote>Provides methods that are used to create a pipeline of commands and invoke those commands either synchronously or asynchronously within a runspace.</blockquote>


### powershell.exe VS PowerShell (the .net class)
powershell.exe is a console host, like cmd.exe or ConEmu. In fact, you can run PowerShell (the commands) in cmd or ConEmu. Powershell.exe exists only to accept text input, pass it to a command interpreter, and display the text output. It's just an executable, like the meatbags we inhabit in this forlorn physical world. The animating spirit is within the PowerShell class.

Powershell.exe, when it loads, creates an instance of PowerShell (the class). When you type into powershell.exe, your input is read as a string and passed to the instance of PowerShell using the instance's AddScript() method. Then powershell.exe calls the instance's Invoke() method, reads back the results, and formats them to the window.


### powershell.exe | Stop-Topic


You can spin up your own instance of PowerShell within PowerShell...

<h1 style="text-align:right;">...Powersheption!</h1>

```powershell
PS C:\dev> $PS = [System.Management.Automation.PowerShell]::Create()
PS C:\dev> $PS
Commands            : System.Management.Automation.PSCommand
Streams             : System.Management.Automation.PSDataStreams
InstanceId          : 21cf70ad-878d-47f3-9264-3f201c36ca5f
InvocationStateInfo : System.Management.Automation.PSInvocationStateInfo
IsNested            : False
HadErrors           : False
Runspace            : System.Management.Automation.Runspaces.LocalRunspace
RunspacePool        : 
IsRunspaceOwner     : True
HistoryString       :
```
Note that I'm calling the Create() method to get an instance of PowerShell; New-Object won't work.

So what does this thing give us?
```powershell
PS C:\dev> $PS.Commands
Commands
--------
{}

PS C:\dev> $PS.Runspace
 Id Name      ComputerName Type  State  Availability 
 -- ----      ------------ ----  -----  ------------ 
 2  Runspace2 localhost    Local Opened Available

PS C:\dev> $PS.Streams
Error       : {}
Progress    : {}
Verbose     : {}
Debug       : {}
Warning     : {}
Information : {}

```
It makes sense that Commands is empty - we've only just created it. We have the following methods to safely and correctly add commands to our PowerShell:

	* AddArgument
	* AddCommand
	* AddParameter
	* AddParameters
	* AddScript
	* AddStatement

If you don't want the work of laboriously specifying each detail, use AddScript():
```powershell
PS C:\dev> $PS.AddScript("Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String 'SqlCluster'")
Commands            : System.Management.Automation.PSCommand
Streams             : System.Management.Automation.PSDataStreams
InstanceId          : 21cf70ad-878d-47f3-9264-3f201c36ca5f
InvocationStateInfo : System.Management.Automation.PSInvocationStateInfo
IsNested            : False
HadErrors           : True
Runspace            : System.Management.Automation.Runspaces.LocalRunspace
RunspacePool        : 
IsRunspaceOwner     : True
HistoryString       :

PS C:\dev> $PS.Invoke()

10.120.0.115 SqlCluster.weylandyutani.local
```
Note that the AddScript method returns the modified object. That's great for chaining methods, but I'll edit it out of the code for the rest of the post.


### Streams
```powershell
PS C:\dev> $PS.Commands.Clear()
PS C:\dev> $PS.AddScript('$VerbosePreference = "Continue"')
PS C:\dev> $PS.AddScript("Write-Verbose (Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String 'SqlCluster')")
PS C:\dev> $PS.Invoke()

PS C:\dev> $PS.Streams
Error       : {}
Progress    : {}
Verbose     : {10.120.0.115 SqlCluster.weylandyutani.local}
Debug       : {}
Warning     : {}
Information : {}
```
As expected, Invoke() returns nothing. However, Our Streams object now has info in the Verbose stream. That's awesome because it lets us easily capture and output the alternate streams wherever we want - and if you've ever had to work with the (https://ss64.com/ps/syntax-redirection.html)redirect operators, you'll be happy.

Please note that Invoke() does not clear the commands when it completes - you have to manually call Clear(), as in the top line above. Likewise, you have to clear the streams with ClearStreams().

In the next part of this topic, I'll discuss what the runspace does.
