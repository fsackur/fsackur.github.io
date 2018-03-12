---
layout: post
title: Reflecting on types
date: 2018-03-30 19:32
author: freddiesackur
comments: true
tags: [Uncategorized]
---

Sometimes, we need to define classes in inline C#, like so:

```powershell
Add-Type -TypeDefinition @'
using System.Collections;

public class MyClass 
{
    private Int32 myInt;
        //etc
```

Typical reasons are that we might need to support a version of Powershell prior to the introduction of native classes, or we need to use [P/Invoke to access native Win32 libraries](https://blogs.msdn.microsoft.com/powershell/2006/04/25/pinvoke-or-accessing-win32-apis/).

When developing like this, the second time we run our code, we bang our heads on the _type name already exists_ error:

```
Add-Type : Cannot add type. The type name 'MyClass' already exists.
At line:3 char:1
+ Add-Type -TypeDefinition @'
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (MyClass:String) [Add-Type], Exception
    + FullyQualifiedErrorId : TYPE_ALREADY_EXISTS,Microsoft.PowerShell.Commands.AddTypeCommand
```

> This is because of `AppDomain`s. You absolutely, massively and totally cannot unload a class from an AppDomain. In general in .NET, you can create a new AppDomain and unload it when you are done, but this is impossible in Powershell because the engine is still in the first AppDomain _or, more accurately, if it is possible, it's beyond me!_

I often like to sketch code snippets before formally introducing them into the project, so I increment the class name each time with a hack like this:

```powershell
if (-not $i) {$Global:i = 1} else {$i++}
Add-Type -TypeDefinition (@'
using System;
using System.Management.Automation;

public class Foo
{
    //code here
}

'@ -replace 'Foo', "Foo$i")
```

which saves me reloading my session every time I update the inline C#. But of course, then my class becomes Foo1, Foo2, Foo3.. and I have to keep editing my test code to reflect the changing typenames. This change saves me that:

```powershell
$Type = Add-Type -PassThru -TypeDefinition (@'
    // code here
'@)
$TypeName = $Type.FullName
```

so I can have my test object of the latest class:

```powershell
$Obj = New-Object $TypeName
```

or, in Powershell 5 and above:

```powershell
$Obj = $Type::new()
```

(You can get at all public static members with this syntax.)
