---
layout: post
title: Dynamic modules in Powershell
date: 2017-10-07 09:01
author: freddiesackur
comments: true
tags: [Powershell, Modules, Metaprogramming]
---
¡Hola chicos!

I've been futzing recently with a script library. In this library, we have a bunch of .ps1 files, each of which contain exactly on function of the same name as the file. (Some of the functions contain child functions, but that doesn't bear upon today's post.)

I'm thinking about better ways to serve the library to our users. One aspect that I quite like is to put all of the functions in one PS module, such that you could set $PSDefaultParameterValues += @{'Get-Command:Module'='Library'}. Then there's an easy way for users to get a clean look at what functions are available to them.

I found out about New-Module a while back. It's a way of taking invokable code, namely, a scriptblock, and promoting it into a PS module. You don't have to create a .psm1 file and run it through Import-Module. Obviously there are lots of ways to abuse that <grins>
```powershell
$DefinitionString = @"
function Write-SternLetter {
	Write-Output $(
		Read-Host "Give them a piece of your mind"
	)
}
"@

$SB = [scriptblock]::Create($DefinitionString)

New-Module -Name Correspondence -ScriptBlock $SB

Get-Command 'Write-SternLetter'
```
Now, there are a lot of reasons not to dynamically generate code from strings - you lose all the language checking, and you open a door to injection attacks. This is just for demo purposes. But the function does get exported into your scope, and you can see that it's defined in our dynamic module called 'Correspondence':
```powershell
Get-Command 'Write-SternLetter'
(Get-Command 'Write-SternLetter').Module
```
However, this alone doesn't make it easy to work with the module, as Get-Module doesn't find it. For that, you have to pipe New-Module to Import-Module:
```powershell
New-Module -Name Correspondence -ScriptBlock $SB | Import-Module
Get-Module
```
It's still dynamic, but now you can find it and remove it with Remove-Module, just as if it were defined in a .psm1.

> Side note: I use this in scripts in the library to import modules, as $Employer doesn't have the facility to copy .psm1 dependencies when we execute script from the library. I embed the text from the .psm1 file in a here-string instead, and can use the module as normal. This isn't perfect, but it does make the code work the same way as it did in dev (think: module scopes.)

So if we have a dynamic module, can we dynamically update a single function in it without having to regenerate and reload the whole module?

Let's first go on a tangent. If everything in Powershell is an object, what kind of object is a module?
```powershell
PS C:\dev> (Get-Module Correspondence).GetType()

IsPublic    IsSerial    Name            BaseType
--------    --------    ----            --------
True        False       PSModuleInfo    System.Object
```
This is conceptually related to (although not in the same inheritance tree as) CommandInfo, which is the base class of FunctionInfo, ScriptInfo, CmdletInfo, et al. All those latter types are what you get from Get-Command; the former is what you get from Get-Module. If you explore these objects, you find interesting properties such as ScriptBlock and Definition. But next we're going to work with PSModuleInfo's Invoke() method.

Can anyone tell me what the call operator, &, does?

It calls the Invoke() method on whatever object is passed as the first argument. Subsequent arguments are passed to the Invoke() method.

In pseudocode:
```powershell
& ($Module) {scriptblock}
```
causes the scriptblock to be invoked in the scope of the module. So, for example, it can access all the module members that you specifically didn't export in Export-ModuleMember.

Say your module defines $PrivateVariable but doesn't export it:
```powershell
$PrivateVariable

& (Get-Module MyModule) {$PrivateVariable}
foo
```
...you see where this is leading?

_Side note: don't do this. You can get into debugging hell when you start getting tricky with scopes. What I'm explaining in this post is a very limited use of manipulating the scope of code execution._

So, the answer should be simple: call Invoke() on the module and pass it a scriptblock that redefines the function. Let's try:



Next, let's mention the Function drive. An alternative to Get-Command, if you want to find commands that are available (output truncated):
```powershell
PS C:\dev> Get-ChildItem Function:\ | ft -AutoSize

CommandType Name Version Source
----------- ---- ------- ------
...
Function Get-FileHash 3.1.0.0 Microsoft.PowerShell.Utility
Function Get-IseSnippet 1.0.0.0 ISE
Function Import-IseSnippet 1.0.0.0 ISE
Function Import-PowerShellDataFile 3.1.0.0 Microsoft.PowerShell.Utility
...
```
However, you'll see that I enumerated these functions with Get-ChildItem. Because Function:\ is a PSDrive, it allows you to use the same cmdlets that you use to manipulate files on disk, such as Get-ChildItem, Get-Item, Get-Content and... Set-Content!

To dynamically update a function in a module, then, here are all the pieces:

	* Import the module
	* Get the module into a variable
	* Define the updated version of the function
	* Get the updated version into a variable
	* Executing in the scope of the module, redefine the function

```powershell
$ModuleSB = {
	function Get-AWitness {
		"YEAH!"
	}
	Export-ModuleMember Get-AWitness
}

$Module = New-Module -Name 'FeelIt' -ScriptBlock $ModuleSB | Import-Module -PassThru

Get-AWitness


YEAH!

& $Module {Set-Content Function:\Get-AWitness {"Hell naw."}}

$Module | Import-Module

Get-AWitness


Hell naw.
```

UNFORTUNATELY I can't get this to work for disk-based modules. It would be lovely to be able to shim code without having to fork it, but it looks to be impossible. Please let me know if you have found a way.
