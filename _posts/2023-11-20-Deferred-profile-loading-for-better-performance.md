---
layout: post
title: Deferred profile loading for better performance
date: 2023-11-20 13:54
author: freddiesackur
comments: true
tags: [Powershell, Async, Profile]
---
_Updated 2023-11-25: the initial code sample broke argument completers. The sample at the bottom is amended. It needed reflection code... \<sigh>_

I have pared down my Powershell profile to improve performance, but it does still take the best part of a second to load on my desktop machine.

As a powershell-everywhere person, my profile can be unacceptably slow on less-powerful machines. But I don't want to lose any functionality.

When I open a shell, I typically want to start running simple commands soonest or sooner.

For a long time, my profile did nothing but dot-source scripts from my `chezmoi` repo and set the path to my git project root. My plan is to load most of these asynchronously, to reduce the time-to-interactive-prompt while still keeping all the functionality (if I just wait a second).

## First approach ❌

Powershell compiles all scriptblocks and caches them, and caches all imported modules. That's why the second import of a module is much faster.

So my first approach was:

- open a runspace and dot-source all the script to warm up the compiled scriptblock and module cache
- wait for the event of that runspace completing
- re-run the script synchronously, with the benefit of the cache

This approach failed, because the action you can attach to an event handler will not run in the default runspace. It's very challenging to take over the default runspace - I won't say _impossible_, but it's certainly _designed_ to be impossible. And I'm not willing to churn out a huge pile of janky reflection code. So the only way would be to `Wait-Event` for the runspace, which blocks the current runspace... which defeats the point.

## Second approach 🚀

Like so many times before, I found a pointer from [SeeminglyScience](https://github.com/SeeminglyScience/) - specifically, a way to [pass global session state around as a variable](https://seeminglyscience.github.io/powershell/2017/09/30/invocation-operators-states-and-scopes#vessels-for-state).

Briefly: when you are at an interactive prompt and you import a module or function, you are adding it to the global `SessionState`. That is what I need to do to load my profile, but can't normally do in an event handler or runspace.

So, I capture the global state:

```powershell
$GlobalState = [psmoduleinfo]::new($false)
$GlobalState.SessionState = $ExecutionContext.SessionState
```

Then I start a runspace and pass in the global state:

> `Start-ThreadJob` pulls in the `ThreadJob` module, but it is very fast to import

```powershell
$Job = Start-ThreadJob -Name TestJob -ArgumentList $GlobalState -ScriptBlock {
    $GlobalState = $args[0]
}
```

In the runspace, I dot-source my profile in the context of the global state:

```powershell
$Job = Start-ThreadJob -Name TestJob -ArgumentList $GlobalState -ScriptBlock {
    $GlobalState = $args[0]
    . $GlobalState {
        . "$HOME/.local/share/chezmoi/Console.ps1"
        . "$HOME/.local/share/chezmoi/git_helpers.ps1"
    }
}
```

...and bingo, when the job completes, the functions, aliases, variables and modules from my dot-sourced scripts are all available!

Even better: the functionality is incrementally available, so I can put rarely-used stuff towards the tail and still have my git helpers imported in milliseconds.

There is a bug, though. As written, the job always errors with, typically, "Unable to find command `Import-Module`" or similar. You see this error when you call `Receive-Job`. This only happens when starting a new shell, not when testing in a warm shell, so I suspect it's related to Powershell's initialisation sequence. A wait fixes the issue:

```powershell
do {Start-Sleep -Milliseconds 200} until (Get-Command Import-Module -ErrorAction Ignore)
```

That wait needs to go inside the scriptblock that's running in the global session state, and it needs to be a do-while - I could not get it to work without an initial wait.

To complete the implementation, I promote console configuration to the body of the profile script, start the job, and add an event handler to read any errors and clean up.

My profile has gone from ~990ms down to ~210ms, and 100ms of that is my starship init (which I could optimise further), so I call this a win. The asynchronous stuff is available within a second, maybe two. To test:

```powershell
pwsh -NoProfile
Measure-Command {. $PROFILE.CurrentUserAllHosts}
exit
```

## Full sample of a minimal solution

> This breaks with VS Code shell integration. To disable it, set "terminal.integrated.shellIntegration.enabled" to "false" in your settings.

The full profile script:

```powershell
<#
    ...cd to my preferred PWD
    ...set up my prompt
    ...run code that doesn't work in the deferred scriptblock
          (i.e. setting [console]::OutputEncoding)
#>


$Deferred = {
    . "/home/freddie/.local/share/chezmoi/PSHelpers/Console.ps1"
    . "/home/freddie/.local/share/chezmoi/PSHelpers/git_helpers.ps1"
    # ...other slow code...
}


# https://seeminglyscience.github.io/powershell/2017/09/30/invocation-operators-states-and-scopes
$GlobalState = [psmoduleinfo]::new($false)
$GlobalState.SessionState = $ExecutionContext.SessionState

# to run our code asynchronously
$Runspace = [runspacefactory]::CreateRunspace($Host)
$Powershell = [powershell]::Create($Runspace)
$Runspace.Open()
$Runspace.SessionStateProxy.PSVariable.Set('GlobalState', $GlobalState)

# ArgumentCompleters are set on the ExecutionContext, not the SessionState
# Note that $ExecutionContext is not an ExecutionContext, it's an EngineIntrinsics 😡
$Private = [Reflection.BindingFlags]'Instance, NonPublic'
$ContextField = [Management.Automation.EngineIntrinsics].GetField('_context', $Private)
$Context = $ContextField.GetValue($ExecutionContext)

# Get the ArgumentCompleters. If null, initialise them.
$ContextCACProperty = $Context.GetType().GetProperty('CustomArgumentCompleters', $Private)
$ContextNACProperty = $Context.GetType().GetProperty('NativeArgumentCompleters', $Private)
$CAC = $ContextCACProperty.GetValue($Context)
$NAC = $ContextNACProperty.GetValue($Context)
if ($null -eq $CAC)
{
    $CAC = [Collections.Generic.Dictionary[string, scriptblock]]::new()
    $ContextCACProperty.SetValue($Context, $CAC)
}
if ($null -eq $NAC)
{
    $NAC = [Collections.Generic.Dictionary[string, scriptblock]]::new()
    $ContextNACProperty.SetValue($Context, $NAC)
}

# Get the AutomationEngine and ExecutionContext of the runspace
$RSEngineField = $Runspace.GetType().GetField('_engine', $Private)
$RSEngine = $RSEngineField.GetValue($Runspace)
$EngineContextField = $RSEngine.GetType().GetFields($Private) | Where-Object {$_.FieldType.Name -eq 'ExecutionContext'}
$RSContext = $EngineContextField.GetValue($RSEngine)

# Set the runspace to use the global ArgumentCompleters
$ContextCACProperty.SetValue($RSContext, $CAC)
$ContextNACProperty.SetValue($RSContext, $NAC)

$Wrapper = {
    # Without a sleep, you get issues:
    #   - occasional crashes
    #   - prompt not rendered
    #   - no highlighting
    # Assumption: this is related to PSReadLine.
    # 20ms seems to be enough on my machine, but let's be generous - this is non-blocking
    Start-Sleep -Milliseconds 200

    . $GlobalState {. $Deferred; Remove-Variable Deferred}
}

$null = $Powershell.AddScript($Wrapper.ToString()).BeginInvoke()
```

## Timings

Note that it takes a few millisconds to parse and start executing the profile. I need more than 74ms to get to a blinking cursor.

| Time (s) | Waypoint |
| -------- | -------- |
| 00.000 | Just before invoking the asynchronous code |
| 00.074 | At the bottom of the profile; shell is interactive |
| 00.275 | Starting the deferred code, after the 200ms sleep (is it a PSReadline issue?) |
| 00.802 | Completed the deferred code; all functions and modules available |
