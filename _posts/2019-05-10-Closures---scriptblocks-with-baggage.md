---
layout: post
title: Closures - scriptblocks with baggage
date: 2019-05-10 22:16
author: freddiesackur
comments: true
tags: [Powershell, Metaprogramming]
---

You may well expect what is going to happen here:

```powershell
$a = 12

$sb = {$a}

$a = 33

& $sb

# Outputs: 33
```

When we execute the scriptblock `$sb`, it references `$a` but doesn't declare it within its own body. Therefore, it looks at the parent scope and finds `$a`. At the time we execute `$sb`, the value of `$a` is 33. So the scriptblock outputs 33.

But what if we want to put some values into the scriptblock at creation time?

You could do something like this:

```powershell
$a = 12

$sb = [scriptblock]::Create(
@"
    `$a = $a
    `$a
"@
)

$a = 33

& $sb

# Outputs: 33
```

but please don't. It will be a pain to develop scriptblocks of any complexity, and your linter won't parse your code. What you need is a _closure:_

```powershell
$a = 12

$cl = {$a}.GetNewClosure()

$a = 33

& $cl

# Outputs: 12
```

So what is a closure? Well, it's a scriptblock! But it specifically is a scriptblock that executes within the scope where it was created. `GetNewClosure()` takes the scriptblock that it's called on, and associates it with the variables defined within whatever scope is active at the time. When we called `GetNewClosure()`, the value of `$a` is 12. That variable is captured and bound to the scriptblock.

> Closures are found in many languages. They are very common in Javascript.

It works in function scopes too:

```powershell
function Get-Closure
{
    param ($a)

    return {$a}.GetNewClosure()
}

$cl = Get-Closure -a 12

& $cl

# Outputs: 12
```

But watch out, because in Powershell, closure scopes only capture a single level of the enclosing scope, and not all the parent scopes all the way down:

```powershell
$a = 12

function Get-Closure
{
    return {$a}.GetNewClosure()
}

$cl = Get-Closure

$a = 33

& $cl

# Outputs: 33
```

If we were to access `$a` in the function, we'd get 12. But it is not captured in the closure. Only variables _declared in_ in the function body are captured by the `GetNewClosure` method call - it's not sufficient for a variable to be _accessible within_ the function body. (And for function body, read "whatever scope we called `GetNewClosure()` in.)

## So, what can you do with it?

You can have a long and storied career without ever touching closures in Powershell. Closures are only really used in Powershell when doing metaprogramming, and metaprogramming is the solution to a very small subset of problems. ('Metaprogramming' is one term used for doing LISPy Javascripty stuff where you manipulate code with code.)

In my next blogpost (about [lazy loading](https://blog.dustyfox.uk/2019/05/11/Lazy-loading-for-API-attributes/)), I'll show you a use case. But for now, here's a quick one. Let's say you have a filter:

```powershell
$filter = {$_.Id -eq 'a8124ec8-0e5d-461e-a8f9-3c6359d44397'}
```

You'd commonly use something like that in a `Where-Object` statement:

```powershell
$MyCat = $Cats | Where-Object $filter
```

Well, you can parameterise that and get a filter that you can pass around that will always find the same cat:

```powershell
$Id = 'a8124ec8-0e5d-461e-a8f9-3c6359d44397'
$filter = {$_.Id -eq $Id}
```

Save on "lost cat" posters!

Apart from that, a function is just a named scriptblock that's registered in the session function table. And a function that's exported from a module (and can therefore access private functions and variables) is just a closure on the module's scope. So if you wanted to dynamically export a function from a module, you could create the function body as a closure in the module's scope and then register it in the session, like this:

```powershell
# Contents of Module.psm1
function foo
{
    "As usual, foo."
}

Export-ModuleMember @()
```

```powershell
$M = Import-Module .\Module.psm1 -PassThru
$M

# Outputs:

# ModuleType Version Name   ExportedCommands
# ---------- ------- ----   ----------------
# Script     0.0     Module
```

```powershell
$BarBody = & $M {
    $FooCmd = Get-Command foo
    {
        $FooString = & $FooCmd
        $FooString, 'Bar.' -join ' '
    }.GetNewClosure()
}
```

- The `& $M { ... }` formulation executes the outer scriptblock in the scope of the module.
- In the outer scriptblock, we get the private function `foo` into a variable, so that it's available to the closure
- In the inner scriptblock, we call `foo` by referring to that variable
- We convert the inner scriptblock into a closure and output it
- We store the closure in `$BarBody`
- Last, we register the function in the session using the `function:\` PSProvider, as follows:

```powershell
Set-Item function:\Global:bar $BarBody

bar

# Outputs: "As usual, foo. Bar."
```
