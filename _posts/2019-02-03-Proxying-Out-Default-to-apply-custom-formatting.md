---
layout: post
title: Proxying Out-Default to apply custom formatting
date: 2019-02-03 13:03
author: freddiesackur
comments: true
tags: [Powershell, Proxy]
---

I had the task of updating a CLI module for an API with the following goals:

- items should be grouped by type
- items representing errors should be displayed inline, yet with Powershell error formatting

The API runs one or more commands on remote systems and returns the command output, which may be a single object or multiple ones.

The CLI, as it stands, adds a PSTypeName to each item that names the command that generated that output. It also saves output into a global variable, so the user can easily retrieve output without having to rerun a command through the API.

Let's shelve the error presentation for now and concentrate on the output grouping. This is the problem we're trying to solve:

- User runs `Get-BootTime` and `Get-InstalledUpdates` on devices `70061c9bb840` and `6a27a4067dc1`
- `$LastOutput` now contains four objects:

```none
PS C:\dev> $LastOutput[0,1]

Device       BootTime
------       --------
70061c9bb840 22/02/2019 20:39:55
6a27a4067dc1 12/02/2019 07:29:52


PS C:\dev> $LastOutput[2,3]

Device       Updates
------       -------
70061c9bb840 {KB3001261, KB3120289}
6a27a4067dc1 {KB3120289, KB2600183, KB3100460}
```

- But if we just pass $LastOutput down the pipeline, we lose information:

```none
PS C:\dev> $LastOutput

Device       BootTime
------       --------
70061c9bb840 22/02/2019 20:39:55
6a27a4067dc1 12/02/2019 07:29:52
70061c9bb840
6a27a4067dc1
```

This is normal Powershell behaviour. When you don't specify a formatting or output command at the end of a pipeline:

- the engine calls the default formatter
- the default formatter inspects the first object coming down the pipeline and sends all output to `Format-Table` if the first object has four visible properties or fewer, or to `Format-List` if it has five or more properties
- `Format-Table` derives table headers for all the output coming down the pipeline from the first object

"Aha!" you cry. "So just use Group-Object." This doesn't achieve our goals, because the output is still going to go down a single pipeline:

```none
PS C:\dev> $LastOutput | Group-Object {$_.PSTypeNames[0]} | Select-Object -ExpandProperty Group

Device       BootTime
------       --------
70061c9bb840 22/02/2019 20:39:55
6a27a4067dc1 12/02/2019 07:29:52
70061c9bb840
6a27a4067dc1
```

We are going to have to be a bit cleverer. This is where `Out-Default` comes in. Here's what Get-Help has to say about `Out-Default`:

> The Out-Default cmdlet sends output to the default formatter and the default output cmdlet. This cmdlet has no effect on the formatting or output of Windows PowerShell commands. It is a placeholder that lets you write your own Out-Default function or cmdlet.

In other words, it exists as a hook that you can access by clobbering the cmdlet with your own function.

> WARNING: Any function that you write will almost certainly perform slower than the equivalent cmdlet in compiled code, and this will affect everything that outputs to the console where the user did not specify a format or output command. In tests, my version slows down commands that output to the console by 5-10%.

We need to generate a high-fidelity proxy for `Out-Default`. That means that we have to faithfully implement the parameters of the command that we are clobbering. For `Out-Default`, this is easy because it only has two parameters, but I'll show you the technique anyway:

``` powershell
$Command = Get-Command Out-Default
$MetaData = [System.Management.Automation.CommandMetaData]::new($Command)
$ProxyDef = [System.Management.Automation.ProxyCommand]::Create($MetaData)
```

If you have PSScriptAnalyzer installed, you can format the output further - my team uses `Allman` bracket style, and I find the `OTBS` format that `ProxyCommand.Create` generates to be less legible.

``` powershell
$ProxyDef = Invoke-Formatter -ScriptDefinition $ProxyDef -Settings 'CodeFormattingAllman'
```

Let's see what we have in `$ProxyDef` now:

``` powershell
[CmdletBinding(HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=113362', RemotingCapability = 'None')]
param(
    [switch]
    ${Transcript},

    [Parameter(ValueFromPipeline = $true)]
    [psobject]
    ${InputObject})

begin
{
    try
    {
        $outBuffer = $null
        if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
        {
            $PSBoundParameters['OutBuffer'] = 1
        }
        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Core\Out-Default', [System.Management.Automation.CommandTypes]::Cmdlet)
        $scriptCmd = {& $wrappedCmd @PSBoundParameters }
        $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
        $steppablePipeline.Begin($PSCmdlet)
    }
    catch
    {
        throw
    }
}

process
{
    try
    {
        $steppablePipeline.Process($_)
    }
    catch
    {
        throw
    }
}

end
{
    try
    {
        $steppablePipeline.End()
    }
    catch
    {
        throw
    }
}
<#

.ForwardHelpTargetName Microsoft.PowerShell.Core\Out-Default
.ForwardHelpCategory Cmdlet

#>
```

Let's break down the components of this auto-generated command definition:

## Help

The `HelpUri` parameter of `CmdletBinding` and the `ForwardHelpTargetName` and `ForwardHelpCategory` components of the function help simply redirect help to the built-in command. We can edit the help functionality if we want. Note that it is perfectly valid to place the comment-based help block at the bottom, but it's unusual. We'll move it to the top as we edit the proxy command.

## OutBuffer

This is a topic worthy of a separate post, so I won't go into it here. Suffice to say, we don't need it for this command, so I'll delete it.

## WrappedCommand

`$wrappedCmd` is populated by a call to `$ExecutionContext.InvokeCommand.GetCommand()` that specifies the original command with its module name, namely, `Microsoft.PowerShell.Core\Out-Default`. If you fail to specify the module, you'll get a handle to yourself, resulting in infinite recursion. The result is exactly the same as calling `Get-Command`. The method call is slightly faster, but I prefer using the cmdlet for readability.

## Scriptblock

`$scriptCmd` is a scriptblock that calls the original command with the parmaeters that were passed into our proxy function. When writing proxies that add functionality, you will need to remove any parameters that you've introduced from `$PSBoundParameters` before this line. However, we aren't adding any parameters.

## SteppablePipeline

We get the steppable pipeline from the scriptblock. This is an object that exposes the Begin, Process and End blocks of the wrapped command, so that we can call the wrapped command in a very granular way.

## try/catches

I suspect that the `ProxyCommand.Create` method is adding these to provide a place to edit the exception handling, because a bare `throw` statement in a `catch` block simply passes on the exception unchanged in Powershell. We will delete these.

After tidying up, we are left with:

``` powershell
function Out-Default
{
    <#
        .SYNOPSIS
        A proxy for Out-Default that aggregates API output and processes it into groups, leaving all other input untouched.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true)]
        [psobject]$InputObject,

        [switch]$Transcript
    )

    begin
    {
        $OutDefaultCommand = Get-Command 'Microsoft.PowerShell.Core\Out-Default' -CommandType Cmdlet
        $OutDefaultSB      = {& $OutDefaultCommand @PSBoundParameters}
        $SteppablePipeline = $OutDefaultSB.GetSteppablePipeline($MyInvocation.CommandOrigin)

        $SteppablePipeline.Begin($PSCmdlet)
    }

    process
    {
        $SteppablePipeline.Process($_)
    }

    end
    {
        $SteppablePipeline.End()
    }
}
```

Hopefully this should be fairly easy to read. Sadly, it adds no value whatever! We need to add the functionality that lead us to creating this proxy:

``` powershell
begin
{
    $OutDefaultCommand = Get-Command 'Microsoft.PowerShell.Core\Out-Default' -CommandType Cmdlet
    $OutDefaultSB      = {& $OutDefaultCommand @PSBoundParameters}
    $SteppablePipeline = $OutDefaultSB.GetSteppablePipeline($MyInvocation.CommandOrigin)

    $SteppablePipeline.Begin($true)

    $GroupedOutput = [System.Collections.Generic.Dictionary[string, System.Collections.ArrayList]]::new()
}

process
{
    if ($_.PSTypeNames -contains 'ApiOutput')
    {
        $TypeName = $_.PSTypeNames[0]
        if (-not $GroupedOutput.ContainsKey($TypeName))
        {
            $GroupedOutput.Add($TypeName, [System.Collections.ArrayList]::new())
        }
        $null = $GroupedOutput[$TypeName].Add($_)
    }
    else
    {
        $SteppablePipeline.Process($_)
    }
}

end
{
    $GroupedOutput.Values |
        Format-Table |
        ForEach-Object {$SteppablePipeline.Process($_)}

    $SteppablePipeline.End()
    $SteppablePipeline.Dispose()
}
```

In short, we accumulate output into a dictionary of arraylists, then we pass each arraylist through Format-Table in the end block - which lets us do our grouping.

There's a lot more to the production code; for example, I identify "error" objects and intersperse them in the output, and I detect whether we should be formatting as a table or list. But this is enough to demonstrate the principles.
