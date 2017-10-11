---
layout: post
title: Using delegates in Powershell
date: 2017-10-08 20:12
author: freddiesackur
comments: true
tags: [Uncategorized]
---
I debug code and think that software engineering principles would be nice. I don't understand them but I think they are nice.

Really, there are a lot of concepts form software engineering that should be applied once your powershell applications, for that is what they are, start getting larger.

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

In Powershell terms, think of a delegate as passing a scriptblock that has a strongly-typed param block and return type. So, conceptually:
```powershell
#In the function that gets called:
param(
	[string]$MainReq,
	[string]$OtherParams,
	[System.Delegate]$ErrorCallback
)

#Could also use try/catch. Note that $_ is going to be an exception.
trap [System.Web.HttpException] {$ErrorCallback.Invoke($_)}

#  ...main processing...


#In the calling function:
$Scriptblock = {
	param($Exception)
	if ($Exception.Message -match '401') {Update-StoredCredential}
}
Invoke-LowerLayer -MainReq $_.ID -OtherParams $_.SideProperty -ErrorCallback $Scriptblock
```
In this code, any exceptions that happen get passed upwards through a side channel. Your main output stream contains only the objects you care about, and you don't have to clog up your logic with error-handling. Your error-handling code is separate to your main logic. And if that doesn't make you smile, you haven't inspected much code ;-)

Now, you don't actually pass a System.Delegate. You'll pass a System.Action. That's a generic type, so you specify some other types at the same time, which map to the types of the parameters that your scriptblock accepts. Thus:
```powershell
#On the function you call:
param(
	[string]$MainReq,
	[string]$OtherParams,
	[Action[System.Exception]]$ErrorCallback
)

#In the calling function:
$Scriptblock = {
	[CmdletBinding()]
	[OutputType([void])]
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
Invoke-LowerLayer -MainReq $_.ID -OtherParams $_.SideProperty -ErrorCallback $Scriptblock
```
Which we can refine further:
```powershell
#On the function you call:
param(
	[string]$MainReq,
	[string]$OtherParams,
	[Action[System.Exception, CommandInfo, hashtable, bool]]$ErrorCallback
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
Invoke-LowerLayer -MainReq $_.ID -OtherParams $_.SideProperty -ErrorCallback (Get-Item Function:\Handle-Error).ScriptBlock
```
The benefits of this approach are:

* The type system will help your colleagues to use it correctly
* It's easy to wrap layer upon layer upon layer
* Error handling is kept separate from business-as-usual processing
* Other benefits that I'll think of after I click 'Publish'

Happy callbacking!