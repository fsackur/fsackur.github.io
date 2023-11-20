---
layout: post
title: C#4PS – compiled powershell modules, part 2
date: 2017-02-16 18:49
author: freddiesackur
comments: true
tags: [Powershell, C#]
---
This is part 2 of a multi-part blog.

[Part 1]({% post_url 2017-02-16-c4ps-compiled-powershell-modules-part-1 %}) – Part 2 – [Part 3]({% post_url 2017-02-19-c4ps-compiled-powershell-modules-part-3 %})


# Previously on C#4PS:
We installed Visual Studio and a couple of extensions, we set up a new project in a new solution, and we changed the theme to Dark because we are dark and moody.


### Code window ready:
<img class="alignnone size-full wp-image-994" src="https://freddiesackur.files.wordpress.com/2017/02/capture13.png?w=775&h=315" alt="capture" width="775" height="315" />

That's all we did in Part 1, which is why you feel so restless.


### Write code and import it into PowerShell
We add a static property, Two, and a static method, GetCritique():

<img class="alignnone size-full wp-image-1009" src="https://freddiesackur.files.wordpress.com/2017/02/capture17.png" alt="capture" width="569" height="163" />

Note that I've added "public" in front of the class definition. Otherwise, the class will load in PowerShell but it will be invisible and you won't be able to call it, like God during a bout of existential angst.

We build it and run it in the usual way, by hitting Start in the tool bar, or pressing F5.

<img class="alignnone size-full wp-image-1007" src="https://freddiesackur.files.wordpress.com/2017/02/capture15.png" alt="capture" width="514" height="227" />

Oh, we can't. We're building a class library, and that won't run itself.

<img class="alignnone size-full wp-image-1008" src="https://freddiesackur.files.wordpress.com/2017/02/capture16.png" alt="capture" width="482" height="223" />

So we instead use Ctrl-Shift-B, or Build > Build Solution. This puts the binary in StupidClass\bin\Debug, since I have the Debug build configuration selected, along with a .pdb file which helps a debugger provide readable output. We open PowerShell and run:
```powershell
Import-Module ".\PSUGUK-Compiled-PSModule\StupidClass\bin\Debug\StupidClass.dll"
```
We can now use this class like any other .NET class:

<img class="alignnone size-full wp-image-1010" src="https://freddiesackur.files.wordpress.com/2017/02/capture18.png" alt="capture" width="868" height="311" />

Tab completion works, we can access the static members with the double-colon syntax, we even get our nice typo - neough said.

If that didn't work, did you remember to add "public" before "class StupidClass"?

Let's add an instance method, GetInstanceCritique:

<img class="alignnone size-full wp-image-1011" src="https://freddiesackur.files.wordpress.com/2017/02/capture19.png" alt="capture" width="557" height="246" />

This time, when we build again, it balks, because we have a file lock open on the output file. That's because we're trying to overwrite the .dll file that we just loaded in PowerShell.

<img class="alignnone size-full wp-image-1012" src="https://freddiesackur.files.wordpress.com/2017/02/capture20.png" alt="capture" width="787" height="243" />

I know what you're thinking. "Aha," you nod, "we need to run Remove-Module in our PowerShell window."

Won't work. When you import that module, you load the StupidClass type into the AppDomain. You can never unload a class from an AppDomain in .NET, not even with -Force. Not even with sudo --force. You have to close the PowerShell host.

So go ahead and do that.

Now it builds when you press Ctrl-Shift-B, and if you open a new PowerShell host and import it again, you can instantiate the object with New-Object and call that instance method:

<img class="alignnone size-full wp-image-1013" src="https://freddiesackur.files.wordpress.com/2017/02/capture21.png" alt="capture" width="654" height="100" />

I'm sure you are using tab completion here. This stuff practically writes itself, it's so low-effort. What can we do about that annoying close-and-reopen malarkey? Well, you _could_ write a script that uses System.IO.FileSystemWatcher and Register-ObjectEvent to pick up on file changes, but we are actually going to use Visual Studio's Build Events.


### Build Events
You access these from the Project Properties window:

<img class="alignnone size-full wp-image-1015" src="https://freddiesackur.files.wordpress.com/2017/02/capture23.png" alt="capture" width="772" height="428" />

As a reminder, you can get to that either through Project > StupidClass Properties, or by right-clicking on the StupidClass project in Solution Explorer:

<img class="alignnone size-full wp-image-956" src="https://freddiesackur.files.wordpress.com/2017/02/capture9.png" alt="capture" width="412" height="575" />

We need a pre-build event to close the PowerShell window from the last run, and a post-build event to open PowerShell and import the module. You can paste the events straight in here or, if you don't like this nice script I've cooked for you and want to do something different, you can click on the Edit buttons and access the Macros. Macros will embed variables related to the project or solution you are building, such as output paths.

Pre-build:
```powershell
start powershell -NoProfile -Command "Get-Process powershell | where {$_.MainWindowTitle -eq '$(TargetName)'} | Stop-Process"
```
Post-Build (see note about cmdow):
```powershell
C:\dev\cmdow\bin\Release\cmdow.exe /run powershell -NoExit -Command "sl $(ProjectDir); $host.UI.RawUI.WindowTitle ='$(TargetName)'; Import-Module $(TargetPath)"
```
Build Events are janky batch script and you'll need to escape anything that looks like a macro.

What will annoy you quickly is how stubborn Visual Studio is about waiting for you to close the just-opened PowerShell host before it returns. StackOverflow pointed me to a little app called cmdow, which you will need to download from [here](https://github.com/ritchielawrence/cmdow/zipball/master">. Update the build event script above to reflect where you save it. This allows you to code while you still have the class loaded in PowerShell.


Next up: write code that isn't stupid!

[Part 1]({% post_url 2017-02-16-c4ps-compiled-powershell-modules-part-1 %}) – Part 2 – [Part 3]({% post_url 2017-02-19-c4ps-compiled-powershell-modules-part-3 %})
