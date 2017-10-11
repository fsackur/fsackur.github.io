---
layout: post
title: Using delegates in Powershell, part 2
date: 2017-10-11 21:21
author: freddiesackur
comments: true
tags: [Uncategorized]
---
In [part 1]({% post_url 2017-10-08-using-delegates-in-powershell-part-1 %}), I described the problem of tangling up normal logic with error-handling logic and how this leads to complex code. I hinted at a solution involving passing a scriptblock that gets invoked on exceptions. 

Here is some perfectly-functional code that follows on from part 1:
```powershell
#ApiClient.psm1

function Invoke-ApiCall {
    [CmdletBinding()]
    param(
        [Action[System.Management.Automation.ErrorRecord, ref]]$ErrorCallback
    )

    $IsRetryable = $false
    do {

        try {
            #Fake out an authentication error from Invoke-RestMethod
            if ([bool](Get-Random -Minimum 0 -Maximum 2)) {
                return [psobject]@{
                    prop1 = 'data1'
                    prop2 = 'data2'
                }

            } else {
                throw "401"
            }

        } catch {
            if ($PSBoundParameters.ContainsKey('ErrorCallback')) {
                $ErrorCallback.Invoke($_, ([ref]$IsRetryable))
            } else {
                throw
            }
        }

    } while ($IsRetryable)
}
```

```powershell
#CallingCode.psm1

function Get-AuthToken {
    #Dummy, for demonstration purposes
    #This would presumably prompt the user for credentials
    Write-Verbose "Prompting user for creds"
}

function Get-Objects {
    param(
        $AuthToken
    )

    begin {
        $OutputArray = @()
    }

    process {
        $Retry = $false
        $MaxRetries = 3
        do {
            try {
                $Objects = Invoke-ApiCall
                $Retry = $false
            } catch {
                Write-Warning $_.Exception.Message
                if ($_ -match '401') {$Retryable = $true}
                if ($Retryable) {
                    $MaxRetries -= 1
                    if ($MaxRetries -gt 0) {
                        $Retry = $true
                    }
                }
                if ($_ -match '401') {
                    $AuthToken = Get-AuthToken -Renew
                }
            }
        } while ($Retry)
    }

    end {
        return $Objects
    }
}
```

In the code above, our retry logic and our error-handling logic are inextricably tied up with our normal processing. As business requirements change and we need to add more logic, this will get worse. That's the problem we want to solve.

Below, we have added an ErrorCallback parameter to the ApiClient module. We've added a little complexity there, but not too much. Note that the higher-level module can slot in error-handling or not, as it pleases:
```powershell
#ApiClient.psm1

function Invoke-ApiCall {
    [CmdletBinding()]
    param(
        [Action[System.Management.Automation.ErrorRecord, ref]]$ErrorCallback
    )

    $IsRetryable = $false
    do {

        try {
            #Fake out an authentication error from Invoke-RestMethod
            if (Get-Random $true, $false) {
                return [psobject]@{
                    prop1 = 'data1'
                    prop2 = 'data2'
                }

            } else {
                throw "401"
            }

        } catch {
            if ($PSBoundParameters.ContainsKey('ErrorCallback')) {
                $ErrorCallback.Invoke($_, ([ref]$IsRetryable))
            } else {
                throw
            }
        }

    } while ($IsRetryable)
}
```

We create a function inside the higher-level module that holds all the logic for error-handling and retrying. Note that we don't export this function; that keeps our interface surface small.
```powershell
#CallingCode.psm1

[uint16]$Script:RetryCount = 0

function Handle-Error {
    [CmdletBinding()]
	[OutputType([void])]
	param(
		[System.Management.Automation.ErrorRecord]$ErrorRecord,
        [ref]$IsRetryable
	)

	if ($ErrorRecord.Exception.Message -match '401') {
        if ($Script:RetryCount -lt 3) {
            Get-AuthToken
            $Script:RetryCount += 1
            $IsRetryable.Value = $true
        } else {
            $Script:RetryCount = 0
            $IsRetryable.Value = $false
            Write-Verbose "Retry count exceeded"
        }
    }
}


function Get-AuthToken {
    #Dummy, for demonstration purposes
    #This would presumably prompt the user for credentials
    Write-Verbose "Prompting user for creds"
}


function Get-Objects {
    param(
        $AuthToken
    )

    begin {
        $OutputArray = @()
    }

    process {
        $Objects = Invoke-ApiCall -ErrorCallback (Get-Item Function:\Handle-Error).ScriptBlock
    }

    end {
        return $Objects
    }
}

Export-ModuleMember Get-Objects
```

Benefits:
* Although the complexity is comparable now, we can change the code in future without significantly increasing complexity
* Changes in one module don't require changes in the other
* That's because we have a small interface surface

> Side note: C# devs will ask why I didn't use Func, since I'm defining an out parameter? The answer is that, as far as I can see, you can't do that in Powershell. Casting the Handle-Error scriptblock to Func gives [lambda\_method(System.Runtime.CompilerServices.Closure, System.Management.Automation.ErrorRecord)] and the out parameter gets silently discarded ¯\\\_(ツ)_/¯

Let me cover this [Action[System.Management.Automation.ErrorRecord, ref]] type. From a Powershell perspective, this defines a scriptblock with two parameters:
* ErrorRecord (which is what you get anyway from $_ in a catch block)
* Ref. Ref types aren't used that much in PS, but they do get [their own topic](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_ref). Objects are always ref anyway, but declaring a parameter as ref means that we can send value types such as string or bool as a reference, too; the key point being that when we change the value in the callback, it simultaneously gets changed in the ApiClient. That's how we let the higher-level module update IsRetryable without having to export it as a variable and letting any old function update it.

This is the nature of delegates (in this use case, anyway): ApiClient can let external code alter its behaviour, but it gets to choose who and when. This keeps everything under control.

We're gaining code safety, for very little extra complexity. Adding code like this may add an hour or two at dev time while you figure it out, but may save bugs in production when you start hitting edge cases. Bugs in production are more expensive than hours spent in dev, right? If you don't believe me, try pushing some sloppy code ;-)
