---
layout: post
title: C#4PS - compiled powershell modules, part 1
date: 2017-02-16 18:44
author: freddiesackur
comments: true
tags: [Uncategorized]
---
This is the part 1 of a multi-part blog.

[Part 1](../2017-02-16-c4ps-compiled-powershell-modules-part-1) – [Part 2](../2017-02-16-c4ps-compiled-powershell-modules-part-2) – [Part 3](../2017-02-16-c4ps-compiled-powershell-modules-part-3)


# Intrrrrooooo!
You muck around with PowerShell for long enough, you probably write a few .psm1 script modules, you use advanced parameters, you understand types. You might start to find yourself a bit limited. This is an introduction to extending your content creation into C# and writing a compiled module in C# - that's right, just like all the [PowerShell that Microsoft ships](https://github.com/powershell).

I'm going to assume **no prior knowledge** of **Visual Studio** or of **C#**, but you should be familiar with PowerShell, using .NET classes, and have a grasp on the basics of object-oriented paradigms. Paradigms. I love that word.

This content was originally presented at a PowerShell User Group UK meetup. If you're in the South East of the UK, [come along and say hi](https://www.meetup.com/Get-PSUGUK-London/)! Or see [other groups worldwide](https://www.meetup.com/topics/powershell/).

[caption id="attachment_818" align="aligncenter" width="300"]<img class=" size-medium wp-image-818 aligncenter" src="https://freddiesackur.files.wordpress.com/2017/02/600_455496529.jpeg?w=300" alt="600_455496529" width="300" height="225" /> Yochay Kiriaty presents to PSUG UK, November 2016[/caption]


# But why?

	* Compiled code will run faster than script
	* Sometimes, fewer lines of code
	* Using C# language features such as event-driven programming
	* Anything with a GUI
	* Anything of any complexity involving multi-threading
	* Object inheritance, polymorphism, interfaces
	* Using design patterns for which Visual Studio templates exist
	* Using Visual Studio - it's very powerful
	* More powerful IntelliSense than ISE
	* Code analysis
	* Organisation of large projects - if it's over 1000 lines, should it be in a script?
	* It might fit in better to your organisation's deployment practices
	* It rocks


# Choose your weapon
You can use ~~any IDE you want~~ Visual Studio 2015. At time of writing, the Visual Studio 2017 RC isn't compatible with PowerShell Tools.

A word on editions:

	* **Visual Studio Express for Desktop** is _cost-free_, but you cannot install tools from the gallery. That rules out PowerShell Tools, but that's not strictly necessary for this guide. You are not limited in who can consume your code.
	* **Visual Studio Community** is also cost-free, but you cannot use code that you produce at your company (unless you open-source it first). I'm using Community in this guide; code is [here](https://github.com/fsackur/PSUGUK-Compiled-PSModule)
	* **Visual Studio Pro**,** Enterprise**,** Ultimate** are all fine if you can pay for them.

Download from (https://www.visualstudio.com/vs/community/). I recommend also installing [PowerShell Tools](https://marketplace.visualstudio.com/items?itemName=AdamRDriscoll.PowerShellToolsforVisualStudio2015) for the bargain price of $free.


# Setting up Visual Studio
Devs may spend days at a new job setting up their dev environment. We won't. Here's my cut-down first steps with VS:

	* Tools > Options:
<img class="aligncenter size-full wp-image-851" src="https://freddiesackur.files.wordpress.com/2017/02/capture.png" alt="capture" width="744" height="434" />I am not a fan of my projects going into my user profile. I set paths in Projects and Solutions; C:\dev is nice as far as I'm concerned.
	* If you installed PowerShell Tools, then you'll want to go into Text Editor > PowerShell and enable line numbers. That will apply if you edit PS script in VS.
<img class=" size-full wp-image-857 aligncenter" src="https://freddiesackur.files.wordpress.com/2017/02/capture1.png" alt="capture" width="744" height="434" />
	* You have to use at least the Dark theme (Environment > General) if you want to be considered a coder:
<img class="alignnone size-full wp-image-868" src="https://freddiesackur.files.wordpress.com/2017/02/capture3.png" alt="capture" width="744" height="434" />
I also like lyphtec's [Solarized](https://github.com/lyphtec/solarized).
	* Even though VS Community is free, you do need to sign in to activate it. At the top-right:
<img class="alignnone size-full wp-image-864" src="https://freddiesackur.files.wordpress.com/2017/02/capture2.png" alt="capture" width="649" height="308" />
	* If you use Github, you can install the extension from Tools > Extensions. Select Online and type in the search bar. You can also install PowerShell Tools here. Unless, of course, you are using VS Express, in which case you can't.
<img class="alignnone size-full wp-image-872" src="https://freddiesackur.files.wordpress.com/2017/02/capture4.png" alt="capture" width="941" height="653" />

That's the VS general setup that you'll need. You can import and export these settings, an exercise which I will leave to you.


# Start a new project
File > New > Project. Hey, this is easy!

<img class="alignnone size-full wp-image-914" src="https://freddiesackur.files.wordpress.com/2017/02/capture5.png" alt="capture" width="941" height="653" />

Everything in Visual Studio exists inside a solution file (.sln). This can contain one or more projects. You will typically want to keep a one-to-one mapping between a solution and a git repo. In this exercise, we're going to start off with a project to write a stupid class, which we will put in a project called StupidClass. In C:\dev\. Got that? Good. We'll do better projects later.

We are choosing .NET Framework 4 at the top because we want to support PowerShell 3.0. If we chose 4.5, our code would require PS 4.5. This can be changed later.

Typically you will write a Console application (CLI-only) or a Windows Forms or WPF Application (GUI). However, we're writing classes to consume in PowerShell, so we choose Class Library. Have you ever noticed a lot of .dll files kicking around? Those are class libraries. We're going to write and compile a .dll file. Click 'OK' if you're cool with that.


### Our brand-new project:
<img class="alignnone size-full wp-image-929" src="https://freddiesackur.files.wordpress.com/2017/02/capture6.png" alt="Capture.PNG" width="1454" height="1050" />

The main window is a code file at the moment. The bottom pane is the build output, which is empty because we haven't compiled anything yet. The top-right is the Solution Explorer, which contains some things that are files and some things that aren't.
### The code:
<img class="alignnone size-full wp-image-935" src="https://freddiesackur.files.wordpress.com/2017/02/capture7.png" alt="capture" width="376" height="265" />

OK, that's all wrong. We don't want to call the class Class1, and we don't want to call a namespace StupidClass. You know when you do something like this in PowerShell:

<img class="alignnone size-full wp-image-940" src="https://freddiesackur.files.wordpress.com/2017/02/capture8.png" alt="capture" width="482" height="144" />

In this case, we are accessing a class called RegexOptions (an Enum actually, but same thing applies) in the System.Text.RegularExpressions namespace. We use namespaces so that we don't get clash for classes with the same names. If you have no better ideas for a namespace, use your organisation's DNS name, backwards, e.g. com.contoso. That ought to avoid name clash with any third-party code, but is also not very helpful. For this guide I'm going to use the namespace Psuguk, for [these guys](https://www.meetup.com/Get-PSUGUK-London/). So:

In Solution Explorer (on the right-hand side), right-click on the Project and go to Properties. The project is going to be one down from the top-level in the tree (which you'll guess correctly is the Solution itself).

<img class="alignnone size-full wp-image-956" src="https://freddiesackur.files.wordpress.com/2017/02/capture9.png" alt="capture" width="412" height="575" />

This gives you the Project Properties window, which we'll use a lot in this guide. You can also get to it from the Project menu in the main menu bar.

<img class="alignnone size-full wp-image-963" src="https://freddiesackur.files.wordpress.com/2017/02/capture10.png" alt="capture" width="1116" height="581" />

Change the Default Namespace to Psuguk. Capitalisation matters everywhere, and convention is that classes and namespaces use caps, but variables use camelCase.

FYI, "Assembly name" here means the output file name.

Oy, that did not update the code file. We actually do need to rename it in code. But don't just type it - right-click on the namespace name and choose "Rename". _Now_ overtype it with "Psuguk".

<img class="alignnone size-full wp-image-972" src="https://freddiesackur.files.wordpress.com/2017/02/capture11.png" alt="Capture.PNG" width="638" height="347" />

Why did we do that? Because when you have 19 source code files, doing it this way lets Visual Studio take care of trawling through and updating everything everywhere. It's considerably smarter than Ctrl-H in ISE. This also lets me show you the right-click context menu; Go To Definition lets you zoom to the definition of whatever method or class you are clicking on, and is insanely useful.

For renaming Class1, please right-click on the source file Class1.cs in the Solution Explorer:

<img class="alignnone size-full wp-image-983" src="https://freddiesackur.files.wordpress.com/2017/02/capture12.png" alt="capture" width="403" height="494" />

If you rename it this way, Visual Studio will offer to rename it in code as well.


### Code window ready:
<img class="alignnone size-full wp-image-994" src="https://freddiesackur.files.wordpress.com/2017/02/capture13.png" alt="capture" width="775" height="315" />

Boring bit over, we are ready to write and compile some code!
