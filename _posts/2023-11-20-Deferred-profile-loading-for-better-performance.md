---
layout: post
title: Deferred profile loading for better performance
date: 2023-11-20 13:54
author: freddiesackur
comments: true
tags: [Powershell, Async, Profile]
---
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

The full profile script:

```powershell
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [Text.Encoding]::UTF8

<#
    code to cd to my preferred PWD
#>

# Set up my prompt
if (Get-Command starship -ErrorAction SilentlyContinue)
{
    $env:STARSHIP_CONFIG = $PSScriptRoot | Split-Path | Join-Path -ChildPath starship.toml
    starship init powershell --print-full-init | Out-String | Invoke-Expression
}


# https://seeminglyscience.github.io/powershell/2017/09/30/invocation-operators-states-and-scopes
$GlobalState = [psmoduleinfo]::new($false)
$GlobalState.SessionState = $ExecutionContext.SessionState

$Job = Start-ThreadJob -Name TestJob -ArgumentList $GlobalState -ScriptBlock {
    $GlobalState = $args[0]
    . $GlobalState {
        # We always need to wait so that Get-Command itself is available
        do {Start-Sleep -Milliseconds 200} until (Get-Command Import-Module -ErrorAction Ignore)

        . "$HOME/.local/share/chezmoi/Console.ps1"
        . "$HOME/.local/share/chezmoi/git_helpers.ps1"
        # other dot-sourced scripts...
    }
}

$null = Register-ObjectEvent -InputObject $Job -EventName StateChanged -SourceIdentifier Job.Monitor -Action {
    # JobState: NotStarted = 0, Running = 1, Completed = 2, etc.
    if ($Event.SourceEventArgs.JobStateInfo.State -eq "Completed")
    {
        $Result = $Event.Sender | Receive-Job
        if ($Result)
        {
            $Result | Out-String | Write-Host
        }

        $Event.Sender | Remove-Job
        Unregister-Event Job.Monitor
        Get-Job Job.Monitor | Remove-Job
    }
    elseif ($Event.SourceEventArgs.JobStateInfo.State -gt 2)
    {
        $Event.Sender | Receive-Job | Out-String | Write-Host
    }
}

Remove-Variable GlobalState
Remove-Variable Job
```
