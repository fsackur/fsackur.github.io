---
layout: post
title: Ersatz classes in Powershell v2 part 2
date: 2018-03-02 09:10
author: freddiesackur
comments: true
tags: [Uncategorized]
---

In part 1, I outlined how you can use `Import-Module`'s -AsCustomObject to create an hacky class definition in versions of Powershell that don't support native classes (i.e., before v5).

Should you do this? Proooobably not - it is a bit odd to read to anyone who is familiar with OOP, and also to anyone who is familiar with Powershell. But it does give you an ability that you may not have otherwise, and it does sidestep the serious problems with native classes in Powershell (issues reloading, issues epxorting defined types, issues with testability).

Here's a hacky way to achieve a kind of inheritance:

```powershell
$ParentDef = {
    # A type definition for a blogger

    # Constructor args
    param
    (
        [string]$Name,
        [string]$Topic
    )

    # Method definition
    function GetBlogpost([uint16] $Length)
    {
        return (@($Topic) * $Length) -join ' '
    }
}

$ChildDef = {
    # A type definition for a blogger named "Freddie" who posts about Powershell
    param ()

    #region
    # Code in the body is run at initialisation-time; in other words,
    # the body IS the constructor
    $Name = "Freddie"
    $Topic = "Powershell"

    # Constructor chaining
    New-Module $ParentDef -ArgumentList ($Name, $Topic)
    #endregion
}

$Child = New-Module $ChildDef -AsCustomObject
$Child.GetBlogpost(7)
```

```none
Powershell Powershell Powershell Powershell Powershell Powershell Powershell
```

Similarly, we can override methods from the parent:

```powershell
$ParentDef = {
    # A type definition for a blogger

    # Constructor args
    param
    (
        [string]$Name,
        [string]$Topic
    )

    # Method definition
    function GetBlogpost([uint16] $Length)
    {
        return (@($Topic) * $Length) -join ' '
    }
}

$ChildDef = {
    # A type definition for a blogger named "Freddie" who posts about Powershell
    param ()

    $Name = "Freddie"
    $Topic = "Powershell"

    New-Module $ParentDef -ArgumentList ($Name, $Topic)

    # Method override
    function GetBlogpost([uint16] $Length)
    {
        return (& $Base.ExportedCommands.GetBlogpost ($Length)).ToLower()
    }
}

$Child = New-Module $ChildDef -AsCustomObject
$Child.GetBlogpost(7)
```

```none
powershell powershell powershell powershell powershell powershell powershell
```

As you see, the child now lower-cases the method return from the parent "class".

This is such a messy way to write code that it's probably better to upgrade target systems to powershell 5 and use native classes.
