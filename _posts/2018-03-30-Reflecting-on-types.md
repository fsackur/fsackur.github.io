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

Typical reasons are that we might need to support a version of Powershell prior to the introduction of native classes, or we need to implement an interface.

When developing like this, we bang our heads on the _type name already exists_ error:
```
Add-Type : Cannot add type. The type name 'MyClass' already exists.
At line:3 char:1
+ Add-Type -TypeDefinition @'
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (MyClass:String) [Add-Type], Exception
    + FullyQualifiedErrorId : TYPE_ALREADY_EXISTS,Microsoft.PowerShell.Commands.AddTypeCommand
```

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
which saves me reloading my session every time I update the inline C#. But of course, then my class becomes Foo1, Foo2, Foo3.. and I have to keep editing my test code to reflect the changing typenames. This line saves me that:
```powershell
$TypeName = "Foo$i"
```
so I can have my test object of the latest class:
```powershell
$Obj = New-Object $TypeName
```
and that is great when I'm working with instances of my class.

But `$TypeName` is a string, and I can't get to the static members of the class directly from the string. `$TypeName::StaticProperty` is never going to work.

This is a quick hack:
```powershell
(New-Object $TypeName).GetType()::StaticProperty
```
This instantiates the class merely to have an object on which to call GetType(). I don't mind my sketch code being this ugly, of course, and it's expected that the project code will be a bit more formal. But I hit a hiccup when trying to define a constructor that relied on a static member, like this:
```powershell
Add-Type -TypeDefinition (@'
using System;
using System.Management.Automation;

public class Foo
{
    public static SessionState SessionState;

    public Foo ()
    {
        if (SessionState == null) {throw new Exception ("SessionState has not been set");}
    }

}

'@ -replace 'Foo', "Foo$i")

$TypeName = "Foo$i"
(New-Object $TypeName).GetType()::SessionState
```
```
New-Object : Exception calling ".ctor" with "0" argument(s): "SessionState has not been set"
At line:20 char:2
+ (New-Object $TypeName).GetType()::SessionState
+  ~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (:) [New-Object], MethodInvocationException
    + FullyQualifiedErrorId : ConstructorInvokedThrowException,Microsoft.PowerShell.Commands.NewObjectCommand
```
Because I throw if the static member is still at its default value, I can't get the type by instantiating the class. So I need to get the type from the classname. This turns out to be surprisingly convoluted!

We need to use the `[Type]::GetType()` static method, which takes the type name as a string. Unfortunately, `[Type]::GetType($TypeName)` returns null. That's because it takes the type name as an Assembly Qualified Name, which looks like this: `dbqnnxfs, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null`

> When you define a type, it gets compiled into an assembly (DLL file). There are well-known assemblies such as mscorlib and System.Management.Automation, but in this case, we are looking for a dynamic assembly. We won't know the name in advance.

This is how you get the full name of an assembly, given the class it contains:
```powershell
[System.AppDomain]::CurrentDomain.GetAssemblies() | 
    ?{$_.ExportedTypes.Name -contains $TypeName} |
    select -ExpandProperty FullName
```
Rounding off this technique:
```powershell
$AssemblyName = [System.AppDomain]::CurrentDomain.GetAssemblies() | 
    ?{$_.ExportedTypes.Name -contains $TypeName} |
    select -ExpandProperty FullName

$Type = [Type]::GetType("Foo$i, $AssemblyName")

$Type::StaticProperty   #Success!
```

The full working code is:
```powershell
$Answer = 42

if (-not $i) {$Global:i = 1} else {$i++}
Add-Type -TypeDefinition (@'
using System;
using System.Management.Automation;

public class Foo
{
    public static SessionState SessionState;

    public readonly Int32 Answer;

    public Foo ()
    {
        if (SessionState == null) {throw new Exception ("SessionState has not been set");}

        this.Answer = (Int32)SessionState.PSVariable.GetValue("Answer");
    }

}

'@ -replace 'Foo', "Foo$i")

$TypeName = "Foo$i"

$AssemblyName = [System.AppDomain]::CurrentDomain.GetAssemblies() | 
    ?{$_.ExportedTypes.Name -contains $TypeName} |
    select -ExpandProperty FullName

$Type = [Type]::GetType("Foo$i, $AssemblyName")

$Type::SessionState = $ExecutionContext.SessionState

$MyFoo = (New-Object "Foo$i")
$MyFoo.Answer
```
```
42
```

The problem I'm trying to solve in this exercise is: how to access variables from your powershell session in C# code? 

This code sample would be considered very poor style in C#, which is statically-typed and emphasises encapsulation. But Powershell is dynamically-typed and provides a global context, so - given a saving in complexity elsewhere, and a few explanatory comments - I think this is be a reasonable technique.
