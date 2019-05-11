---
layout: post
title: Lazy loading for API attributes
date: 2019-05-11 12:49
author: freddiesackur
comments: true
tags: ['Powershell']
---

Typically, when you implement an API client module, you'll query the API and output the objects you get back - possibly with some changes, possibly just as they come from the API.

However, some APIs have large surface areas and a lot of attributes that an object might have. You may never need all of them, and you may well only need a couple.

What you want in this scenario is the ability to create the object without having to populate all the attributes at creation time, but where they can be fetched on first access. But you still want them to look and feel like properties, because that's what your callers expect.

The demo code is in https://github.com/fsackur/LazyLoading. In this demo I'll use a class called `Server`, but these techniques will also work for `PSCustomObject`s. Here's the start:

```powershell
class Server
{
    Server ()
    {
        foreach ($Prop in [Server]::_properties)
        {
            $this | Add-Member ScriptProperty -Name $Prop -Value {
                2 + 2
            }
        }
    }


    hidden static [string[]] $_properties = @(
        'Foo',
        'Bar',
        'Baz'
    )

}


$s = [Server]::new()
$s


# Output:

# Foo Bar Baz
# --- --- ---
#   4   4   4
```

Clearly, we've created an object with `Foo`, `Bar` and `Baz` properties. But we cannot add these to the class in the normal way, because we need to have properties that are implemented in code - we need some code to happen when we access a property. So we need to use members of type `ScriptProperty`, which are accessed like properties but the value is a scriptblock. Powershell classes don't have a keyword to define these, so we have to add the scriptproperties dynamically in the constructor. When we look at any of the scriptproperties, the `2 + 2` scriptblock runs, giving us the `4`s we see in the output.

This gives us a base for code-defined properties. We're looping over the list of properties and defining a generic code block for each. But when we're accessing the `IpAddress` property of a server object and we want it to run code to query for the IP address, we need that generic code to know that it's running on the `IpAddress` property and not the `SerialNumber` property. And a scriptproperty doesn't have a handy `$PSCmdlet` or `$MyInvocation`. So we're going to use closures (see [here](https://blog.dustyfox.uk/2019/05/10/Closures-scriptblocks-with-baggage/) for a quick intro to closures):

```powershell
class Server
{
    Server ()
    {
        foreach ($Prop in [Server]::_properties)
        {
            $this | Add-Member ScriptProperty -Name $Prop -Value {
                $Prop
            }.GetNewClosure()
        }
    }


    hidden static [string[]] $_properties = @(
        'Foo',
        'Bar',
        'Baz'
    )

}


$s = [Server]::new()
$s


# Output:

# Foo Bar Baz
# --- --- ---
# Foo Bar Baz
```

We've added the `GetNewClosure()` call when creating the scriptblock, and that seals in the value of `$Prop` as it was at the time we called that method. Now `$Prop` contains the property name, and we can see that each property now outputs its own name.

Now let's complete the sketch with an internal dictionary that holds the properties that have been fetched:

```powershell
class Server
{
    Server ()
    {
        foreach ($Prop in [Server]::_properties)
        {
            $this | Add-Member ScriptProperty -Name $Prop -Value {

                if (-not $this._dict.ContainsKey($Prop))
                {
                    $this._dict[$Prop] = Get-ServerProperty $Prop -Server $this
                }

                return $this._dict[$Prop]

            }.GetNewClosure()
        }
    }


    hidden static [string[]] $_properties = @(
        'Foo',
        'Bar',
        'Baz'
    )


    hidden [hashtable] $_dict = @{}

}


$s = [Server]::new()
$s


# Output
# (for impl of Get-ServerProperty in the repo)

#       Foo       Bar       Baz
#       ---       ---       ---
# 230636006 145716468 285402623
```

We've implemented an inner dictionary to keep track of the properties we've already queried. If any property is accessed and already exists in the dictionary, it's returned from the dictionary. If it doesn't exist, it's queried using the `Get-ServerProperty` function. (The function would implement your API code.)

> If we declare `_dict` as `System.Collections.Generic.Dictionary` instead of `hashtable`, we can use `TryGetValue()`, which checks for the existence of a key and retrieves the value in one call.

## Pre-fetching

You would very likely have a base set of attributes which you always fetch. It would be rare for all attributes to be lazy-loaded. Anything like an ID or an index property would have to be guaranteed to be present because it's probably going to be required for subsequent API calls. You might fetch these eagerly in the constructor, or you could check on each property access that results in an API call whether the important properties have been fetched yet and include them in the call if not.

If you use, say, 3 attributes, this technique will result in 3 separate API calls, which is inefficient. You would likely need to provide a way for a caller to declare a list of attributes which it knows it will be using and fetch all of those attributes in one call. This might be done with a constructor parameter or by providing a method for the purpose.

Finally, note that the properties were populated merely by outputting the object to the pipeline. When `$s` is output, the default formatter (and this would be the same if you had explicitly piped to `Format-List` or what-have-you) looks at the properties in order to display them. This would result in 3 API calls for each object - your Format-List would get very slow!

As a mitigation strategy for this, you would likely define a default view with a named set of properties, and ensure that those attributes are pre-fetched on object creation (or first access). I'd recommend a `Format.ps1xml` for that task, but you can also dynamically create a `DisplayPropertySet` in the constructor.
