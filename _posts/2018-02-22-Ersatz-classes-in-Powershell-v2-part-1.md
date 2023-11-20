---
layout: post
title: Ersatz classes in Powershell v2 part 1
date: 2018-02-22 00:55
author: freddiesackur
comments: true
tags: [Powershell, Classes, Modules]
---
Part 2 is [here]({% post_url 2018-03-02-Ersatz-classes-in-Powershell-v2-part-2 %})

There are some types of problem that object-oriented programming is very well suited for. You don't particularly need it if you are running through a linear sequence of tasks, but when you have a problem that's characterised by different types of _thing_ and the relationships between your _things_ are important, then OOP can let you write much more concise code.

Case in point: I have a project that's for use on members of an AD domain, to identify domain controllers and test connectivity to each on AD ports. If the member is itself a domain controller, then the ports to be tested must be a superset of the ports needed by a non-DC member. I also want discovery to be done through DNS.

In my first attempt, I created a lot of hashtables to hold DNS servers and domain controllers. There were lots of loops over the items in hashtables, and variable bloat. I had to choose what to use as my keys, and settled on IP addresses, which brought further questions. The code got pretty unwieldy, and it wasn't much fun to work on past a certain point.

There are a few aspects of the problem that cry out for a class-based solution:

- DNS servers have behaviours such as _query_
- Domain controllers have _ports_, which are accessible or not
- Domain controllers are just a special case of domain members - they have all the behaviours and properties that members have
- It would be nice to have some control over how we determine if two domain controllers are the same server
- Domain members have authenticating domain controllers and domain controllers that are in the same site
- Domain controllers have current replication partners and potential future replication partners

The project needs to be rewritten with classes. But I have further constraints: I want to support Powershell v3 and, ideally, v2. Native powershell classes were introduced in v5.

It's perfectly valid to write classfiles in C# and import them directly into Powershell. To set against this approach, I did not want to limit the supportability of the project to only people familiar with C#, because this project is a tool for sysads.

I don't mind if the simpler elements of the class are written in C# as long as the methods (where debuggers will typically spend their time) are in PS, but I couldn't find any way to write the methods in the class such that they run in the hosting Powershell process's first runspace.

I also considered this approach:

```powershell
Add-Type -TypeDefinition @'
namespace Test
{
    public class Test
    {
        public string Name = "Freddie";
    }
}
'@ -IgnoreWarnings

$T = New-Object Test.Test
$T | Add-Member -MemberType ScriptMethod -Name 'GetName' -Value {
    return $this.Name
}
$T.GetName()
```

```plaintext
Freddie
```

This is b'fugly, and I don't fancy having to answer questions about it.

> The above snippet takes advantage of the fact that, unlike C#, Powershell is _dynamically-typed_. You can add members to an instance that are not present in the type definition. This can't be done in C#.

Where I found some joy was in the ```-AsCustomObject``` switch available to the ```Import-Module``` and ```New-Module``` cmdlets. I've never seen this used, or even used it myself (until now), so I'll take a minute to explore the meaning of this switch.

## Module definition

A module definition is typically living in its own file with a .psm1 extension. As a rule, the primary function is to contain function definitions which are then exported into the calling scope when you import the module. You can control which elements of a module are exported and which remain hidden, which is similar in effect to declaring a member _private_ in C# (we won't dive into thie rabbit-hole now). You can also define variables, which then exist, by default, in the _script_ scope (effectively, private to the module functions) but can optionally be exported as well. There are use cases for defining script variables, but in the majority of cases, a powershell module is purely a way of bundling functions together for code organisation.

However, if we look at what we've described, we have _behaviours_ and _properties_, both of which can be public or private. Is that starting to sound like a type definition to you?

Let's also add in that module definitions can have parameter blocks and accept argumants, and we have a rough implementation of the most important parts of a class system. So our friends in the Microsoft Powershell team reached a little further and furnished us with the...

## AsCustomObject

 ... switch parameter.

When you import a module definition with ```Import-Module -AsCustomObject```, instead of "importing" a "module", Import-Module returns a powershell object.

The functions in the module definition become the methods of the object.

The variables in the module definition become the properties of the object.

The parameter block in the module definition has an equivalence to the constructor of a class, and Import-Module does the instantiation (instead of New-Object).

This language feature has been present in Powershell since at least v2, but hasn't had much attention because it's so completely different to the normal usage of Import-Module, and because it's so completely different to how operations people started out using powershell.

> _It's also pretty ugly._

Let me show you with some examples:

```powershell
#Contents of ModuleDef.psm1
function Get-Month {
    $Date = Get-Date
    return $Date.ToString('MMMM')
}
#End of ModuleDef.psm1

$MyModuleObject = Import-Module .\ModuleDef.psm1 -AsCustomObject
$MyModuleObject.'Get-Month'()
```

```plaintext
February
```

Absolutely crazy. You can see that I am running the Get-Month function using dot-and-bracket syntax. (Because _Get-Month_ has a hyphen, I have to enclose it in quotes. For this reason, when using this technique, you should name your functions in the accepted method style with no hyphen.)

Here is a longer example:

```powershell
#Contents of MyAge.psm1
param (
    [int]$MyAge
)

$MinAgeToVote = 18
$MaxAgeToDance = 32

function AmICool {
    return ($MyAge -ge $MinAgeToVote -and
            $MyAge -lt $MaxAgeToDance)
}

Export-ModuleMember -Function * -Variable *

#End of MyAge.psm1

$MyAgeObject = Import-Module .\MyAge.psm1 -AsCustomObject `
                                            -ArgumentList (37)
$MyAgeObject.MyAge
```

```plaintext
37
```

```powershell
$MyAgeObject.MinAgeToVote
```

```plaintext
18
```

```powershell
$MyAgeObject.AmICool()
```

```plaintext
False
```

'Elegant' would be a stretch for this syntax, but it's not bad if you don't have powershell 5 on your systems. It's worth diving into some more in part 2 of this blogpost.

[Part 2]({% post_url 2018-03-02-Ersatz-classes-in-Powershell-v2-part-2 %})
