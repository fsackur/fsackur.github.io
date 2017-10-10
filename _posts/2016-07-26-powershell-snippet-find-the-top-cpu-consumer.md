---
layout: post
title: PowerShell snippet - find the top CPU consumer
date: 2016-07-26 09:19
author: freddiesackur
comments: true
tags: [Uncategorized]
---
A snippet to provide text output on the process using the highest CPU.

This will tell you the service name if it is running in an instance of svchost, or the app pool name if it is an IIS worker process.

Get-Process does not provide a snapshot reading like Task Manager does, only a "CPU Time" counter that increments. This takes a view of CPU used over 5 seconds to determine the process consuming the most CPU. It then iterates over all processes, creating an array with a calculated CPU usage value. This code selects the top one offender, but it could be modified to show the top five and the CPU time used.


### Example usage and output:
```powershell
PS H:\PowerShell> Get-CpuTopOffender
Top CPU hog in last 5 seconds: chrome with PID 12684
```
```powershell
PS H:\PowerShell> Get-CpuTopOffender
Top CPU hog in last 5 seconds: w3wp with PID 3480
Application pool: ASP.NET v4.0
```

### Code:
```powershell
#High CPU - find PID and process name of top offender, and application pool if the process is w3wp
function Get-CpuTopOffender {
    #we require this select statement to break the link to the live data, so that the processlist contains point-in-time data
    $ProcessList1 = Get-Process | select ProcessName, Id, @{name='ms'; expr={$_.TotalProcessorTime.TotalMilliSeconds}} |            Group-Object -Property ID -AsString -AsHashTable
    $Seconds = 5
    Start-Sleep -Seconds $Seconds
    $ProcessList2 = Get-Process | select ProcessName, Id, @{name='ms'; expr={$_.TotalProcessorTime.TotalMilliSeconds}} | 
        Group-Object -Property ID -AsString -AsHashTable
 
    $CalculatedProcessList = @()
 
    foreach ($ProcessId in $ProcessList1.Keys) {
        $Name = ($ProcessList1.$ProcessID)[0].ProcessName
 
        $CpuTotalMs1 = ($ProcessList1.$ProcessID)[0].ms
        if (-not ($ProcessList2.$ProcessID)) {continue}
        $CpuTotalMs2 = ($ProcessList2.$ProcessID)[0].ms
 
        $Calc = New-Object psobject -Property @{
            Name = $Name;
            PID = $ProcessID;
            CPU = $($CpuTotalMs2 - $CpuTotalMs1)
        }
 
        $CalculatedProcessList += $Calc
    }
 
    $TopOffender = $CalculatedProcessList | sort CPU -Descending | select -First 1
 
    $Output = "Top CPU hog in last $Seconds seconds: $($TopOffender.Name) with PID $($TopOffender.PID)"
 
    #Add extra info
    if ($TopOffender.Name -like "svchost") {
        $ServiceNames = (Get-WmiObject -Query "SELECT Name FROM Win32_Service WHERE ProcessId = $($TopOffender.PID)" | %{$_.Name})
        $Output += "`nServices hosted: $($ServiceNames -join ', ')"
    }

    if ($TopOffender.Name -like "w3wp") {
        $ProcessWmi = (Get-WmiObject -Query "SELECT CommandLine FROM Win32_Process WHERE ProcessId = $($TopOffender.PID)")
        $Cli = $ProcessWmi.CommandLine
        $AppPool = ($Cli -split '"')[1]
        $Output += "`nApplication pool: $AppPool"
    }

    $Output
}
```
