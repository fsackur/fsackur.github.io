---
layout: post
title: Using reflection to get round PSv2 lack of PSSerializer class
date: 2019-03-11 16:39
author: freddiesackur
comments: true
tags: ['Powershell', 'Reflection']
---

I had some code that used `PSSerializer` to serialize objects into XML. This blew up when run on PSv2, because PSv2 doesn't expose the `System.Management.Automation.PSSerializer` class - leaving me looking at an annoying refactor to use `Export-Clixml` everywhere, which only ever writes to the filesystem.

I thought I'd have a look at what `PSSerializer` does under the hood, so I opened the source code for Powershell - which you can clone from [Github](https://github.com/PowerShell/PowerShell) - and searched for it.

I found it in `serialization.cs`. I'm really only interested in the `Serialize` and `Deserialize` methods and, fortunately, they turn out to be quite simple. Here's the method declaration for `Serialize`:

``` csharp
public static string Serialize(Object source, int depth)
{
    // Create an xml writer
    StringBuilder sb = new StringBuilder();
    XmlWriterSettings xmlSettings = new XmlWriterSettings();
    xmlSettings.CloseOutput = true;
    xmlSettings.Encoding = System.Text.Encoding.Unicode;
    xmlSettings.Indent = true;
    xmlSettings.OmitXmlDeclaration = true;
    XmlWriter xw = XmlWriter.Create(sb, xmlSettings);

    // Serialize the objects
    Serializer serializer = new Serializer(xw, depth, true);
    serializer.Serialize(source);
    serializer.Done();
    serializer = null;

    // Return the output
    return sb.ToString();
}
```

Pretty simple, right... if I can also use those other classes. Well, `StringBuilder` and `XmlWriterSettings` are public, and I can find them even in PSv2, but `Serializer` is declared as an internal class, so I just get an error:

``` powershell
[System.Management.Automation.Serializer]
Unable to find type [System.Management.Automation.Serializer].
At line:1 char:1
+ [System.Management.Automation.Serializer]
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Management.Automation.Serializer:TypeName) [], RuntimeException
    + FullyQualifiedErrorId : TypeNotFound
```

If I can access this class, then I can brew up an sort-of monkeypatch of `PSSerializer`'s `Serialize()` method. This is where reflection comes in.

First, we use the assembly containing the class to get the type:

``` powershell
# System.Management.Automation
# Quickest way to get the right assembly
# is from a type in the same assembly
$SmaAssembly = [powershell].Assembly
$Type = $SmaAssembly.GetType('System.Management.Automation.Serializer')

$Type

IsPublic IsSerial Name           BaseType
-------- -------- ----           --------
False    False    Serializer     System.Object
```

This is a `RuntimeType`, just like the output form calling `GetType()` with no arguments on any object, except that it would be otherwise inaccessible (because it was declared `internal` rather than `public`).

Next we get a constructor (note that '.ctor' is a common abbreviation for 'constructor'):

``` powershell
$Ctor = $Type.GetConstructors('Instance, NonPublic') |
    Where-Object {$_.GetParameters().Count -eq 3}
```

I have `Where-Object {$_.GetParameters().Count -eq 3}` because `Serializer` has three constructors, and I want the one that matches the signature of the one used in the PSv3+ declaration of the `PSSerializer` class, which is `new Serializer(xw, depth, true)` in the C# source code.

> The `GetConstructors` method takes an argument of type `System.Reflection.BindingFlags`. That is an enum. These are the values of the enum:
>
> ``` powershell
> [Enum]::GetValues([System.Reflection.BindingFlags])
> Default
> IgnoreCase
> DeclaredOnly
> Instance
> Static
> Public
> NonPublic
>   ... etc ...
> ```
> As the name suggests, this is a _flag-type_ enum, which means that you can combine the values. THis is usually the case wherever you see options that have power-of-two values, like `0x400`, `0x800` etc etc. You bitwise-combine these to send the combination of options that you want - so `0x400` and `0x800` would be `0xC00`. We want the `Instance` and the `NonPublic` options. In Powershell, the long way to write this out would be:
>
> ``` powershell
> [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
> ```
>
> Fortunately, a single string containing comma-separated enum names will be combined, so we can just pass in `'Instance, NonPublic'` to get the same effect.

To get back from our digression, we now have the constructor that we want and can invoke it:

``` powershell
$Ctor.Invoke(@($Xw, $Depth, $true))
    $Methods = $Type.GetMethods('Instance, NonPublic')
$serializer = $Ctor.Invoke(@($Xw, $Depth, $true))
$serializer | gm
$Methods = $Type.GetMethods('Instance, NonPublic')
$SerializeMethod = $Methods | Where-Object {$_.Name -eq 'Serialize'}
$SerializeMethod
$SerializeMethod.Count
$SerializeMethod
$SerializeMethod = $Methods | Where-Object {$_.Name -eq 'Serialize' -and $_.GetParameters().Count -eq 1}
$SerializeMethod
$SerializeMethod.Invoke($serializer, @("Foo"))
$DoneMethod = $Type.GetMethod('Done', 'Instance, NonPublic')
$Type.GetMethod #('Done', 'Instance, NonPublic')
$DoneMethod = $Type.GetMethod('Done', [System.Reflection.BindingFlags]'Instance, NonPublic')
$DoneMethod
$DoneMethod.Invoke($serializer)
$DoneMethod.Invoke($serializer, 'Instance, NonPublic')
$DoneMethod.Invoke($serializer, 'Instance, NonPublic')
(history).CommandLine
$sb
$sb.ToString()
$DoneMethod.Invoke($serializer, 'Instance, NonPublic')
$DoneMethod
$DoneMethod.Invoke($serializer, [System.Reflection.BindingFlags]'Instance, NonPublic', $null, @(), (Get-Culture))

public static string Serialize(Object source, int depth)
        {
            # Create an xml writer
            $sb = New-Object System.Text.StringBuilder
            $xmlSettings = New-Object System.Xml.XmlWriterSettings
            $xmlSettings.CloseOutput = $true
            $xmlSettings.Encoding = [System.Text.Encoding]::Unicode
            $xmlSettings.Indent = $true
            $xmlSettings.OmitXmlDeclaration = $true
            $xw = [System.Xml.XmlWriter]::Create($sb, $xmlSettings)

            # Serialize the objects
            $SmaAssembly = [powershell].Assembly
            $Type = $SmaAssembly.GetType("System.Management.Automation.Serializer")
            #$Ctor = $Type.GetConstructors('Instance, NonPublic') | Where-Object {$_.GetParameters().Count -eq 3}
            $serializer = [System.Activator]::CreateInstance($Type, @($Xw, $Depth, $true))
            $Methods = $Type.GetMethods('Instance, NonPublic')

            serializer.Serialize(source);
            serializer.Done();
            serializer = null;

            // Return the output
            return sb.ToString();
        }
```