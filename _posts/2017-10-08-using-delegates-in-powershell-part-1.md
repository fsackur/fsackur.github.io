---
layout: post
title: Using delegates in Powershell, part 1
date: 2017-10-08 20:12
author: freddiesackur
comments: true
tags: [Uncategorized]
---
# Using delegates in Powershell, part 1

Part 2 is [here]({% post_url 2017-10-11-using-delegates-in-powershell-part-2 %})

I debug code and think that software engineering principles would be nice. I don't understand them but I think they are nice.

Really, there are a lot of concepts from software engineering that should be applied once your powershell applications, for that is what they are, start getting larger.

I'm currently working on a project that has multiple layers of wrapping. Our API has a client module already built. I'm writing a module to transform that output so it's easier to consume in the logic part of that code, and also so I can slot in another API later. This leads to the problem of how to handle error conditions.

Say you have:
```powershell
process {
	foreach ($Item in $InputStream) {

		# ...27 lines of logic about processing the input...

		Write-Output $Item.RelevantProperty
	}
}
```
Well, if I already have a lot of branching, the last thing I want to do is clutter it even further with exception and null handling.

A concept that's been around since donkey's years in .NET is delegates, which is a way to make a type out of the concept of a callback function. (It doesn't have to be a callback, but that's how I'm going to use it here.)

> Side note: I am not a C# developer. I don't want to give the idea that this article covers much of the topic of delegates. I'm always open to having any misconceptions cleared up.

In Powershell terms, think of a delegate as passing a scriptblock that has a strongly-typed param block and return type. So, conceptually:
```powershell
#In the function that gets called:
param(
	[string]$MainParam,
	[string]$OtherParams,
	[System.Delegate]$ErrorCallback
)

#Could also use try/catch
trap [System.Web.HttpException] {$ErrorCallback.Invoke($_.Exception)}

#  ...main processing...


#In the calling function:
$Scriptblock = {
	param([Exception]$Exception)
	if ($Exception.Message -match '401') {Get-Credential}
}

Invoke-LowerLayer -MainParam $blah -OtherParams $blahblah -ErrorCallback $Scriptblock
```
In this code, any exceptions that happen get passed upwards through a side channel. Your main output stream contains only the objects you care about, and you don't have to clog up your logic with error-handling. Your error-handling code is separate to your main logic. And if that doesn't make you smile, you haven't inspected much code ;-)

Now, you don't actually pass a System.Delegate. You'll pass a System.Action. We can use that as a generic type, so we'll specify some other type or types at the same time, which map to the types of the parameters that your scriptblock accepts. Because we've got param([Exception]) above, we'll have param(Action[Exception]) below. Thus:
```powershell
#On the function you call:
param(
	[string]$MainParam,
	[string]$OtherParams,
	[Action[Exception]]$ErrorCallback
)

#In the calling function:
$Scriptblock = {
	param(
		[Exception]$Exception
	)
	switch -Regex ($Exception.Message) {
		'401|Token' {
			Update-StoredCredential
		}
		'403' {
			Write-PopupMessage "ACCESS DENIED"
		}
		default {
			Write-PopupMessage $_
		}
	}
}

Invoke-LowerLayer -MainParam $blah -OtherParams $blahblah -ErrorCallback $Scriptblock
```

Which we can refine further:
```powershell
#On the function you call:
param(
	[string]$MainParam,
	[string]$OtherParams,
	[Action[Exception, System.Management.Automation.CommandInfo, hashtable, bool]]$ErrorCallback
)

#In our try/catch or trap:
 $IsRetryable = $(some logic)
 $ErrorCallback.Invoke($_, $MyInvocation.MyCommand, [hashtable]$PSBoundParameters, $IsRetryable)


#In the calling function:
$Scriptblock = {
	[CmdletBinding()]
	[OutputType([void])]
	param(
		[Exception]$Exception,
		[System.Management.Automation.CommandInfo]$Caller,
		[hashtable]$CallerParameters,
		[bool]$Retryable
	)
	switch -Regex ($Exception.Message) {
		'401|Token' {
			Update-StoredCredential
		}
		'403' {
			Write-PopupMessage "ACCESS DENIED"
		}
		default {
			if ($Retryable) {
				Start-Sleep 5;
				& $Caller @CallerParameters
			}
		}
	}
}
```
By passing the extra parameters, we can retry the original call.

Note that I'm casting $PSBoundParameters to hashtable because that object doesn't contain Clone() and I don't want to pass a reference to an object that may still be being used. ('Be being'?)

Finally, can we send in a function definition? _Is cheese tasty..?_
```powershell
function Handle-Error {
	[CmdletBinding()]
	[OutputType([void])]
	param(
		[Exception]$Exception,
		[System.Management.Automation.CommandInfo]$Caller,
		[hashtable]$CallerParameters,
		[bool]$Retryable
	)
	switch -Regex ($Exception.Message) {
		'401|Token' {
			Update-StoredCredential
		}
		'403' {
			Write-PopupMessage "ACCESS DENIED"
		}
		default {
			if ($Retryable) {
				Start-Sleep 5;
				& $Caller @CallerParameters
			}
		}
	}
}

Invoke-LowerLayer -MainParam $blah -OtherParams $blahblah -ErrorCallback (Get-Item Function:\Handle-Error).ScriptBlock
```
**Note that this code doesn't function as intended - the solution is in part 2**

The benefits of this approach are:

* The type system will help your colleagues to use it correctly
* It's easy to wrap layer upon layer upon layer
* Error handling is kept separate from business-as-usual processing
* Other benefits that I'll think of after I click 'Publish'

Now, about that code snippet not working. I wanted to show, conceptually, that you can pass CommandInfo through and invoke it (CommandInfo is the type you get from Get-Command). Two things:
* You wouldn't pass an Exception and a CommandInfo in Powershell, you'd just pass the ErrorRecord. ErrorRecord already contains the Exception and the invocation details of whence it was thrown. It's a nice little wrapper class.
* Whatever scriptblock you cast to Action will never return any output. Action returns void.

There's more in [Part 2]({% post_url 2017-10-11-using-delegates-in-powershell-part-2 %}), but I won't blame you if that's enough for now.

Happy callbacking!
