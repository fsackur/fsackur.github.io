---
layout: post
title: Wrapping external utilities, using EMC's inq.exe as an example
date: 2017-10-08 23:41
author: freddiesackur
comments: true
tags: [Uncategorized]
---
To fetch WWNs for an iSCSI LUN, you might find yourself using inq.exe, which is provided by EMC.

This is an old-skool utility that runs in cmd. We do like our powershell and it is a frequent problem to pull data from a CLI utility, so I thought I'd post my process for doing so.

First, an intermediate (but functional) stage:
```powershell
$Output = @()

$Lines = & .\inq.exe -winvol
$Lines = $Lines | 
    select -Skip 6 | 
    where {$_ -notmatch '^-*$'}

$HeaderRow = $Lines[0]; $Rows = $Lines[1..($Lines.Count)]
$ColumnHeaders = $HeaderRow -split ':'

foreach ($Row in $Rows) {
    $HT = @{}
    $Values = $Row -split ':'
    for ($i=0; $i -lt $ColumnHeaders.Count; $i++) {
        $HT += @{
            $ColumnHeaders[$i].Trim() = $Values[$i].Trim()
        }
    }
    $Output += (New-Object psobject -Property $HT)
}
$Output | ft
```
If we only get to the code above, we've accomplished the required result. (Full code is on my github; link at the bottom.)

To approach this task, I start in stages. So I might begin something like this:
```powershell
$Text = & .\inq.exe -winvol
    $Text
    $Text.Count
Inquiry utility, Version V7.3-1305 (Rev 1.0) (SIL Version V7.3.1.0 (Edit Level 1305)
Copyright (C) by EMC Corporation, all rights reserved.
For help type inq -h.



-------------------------------------------------------------------------------------
DEVICE             :VEND   :PROD         :REV  :SER NUM    :CAP(kb)  :WIN vol
-------------------------------------------------------------------------------------
\\.\PHYSICALDRIVE0 :VMware :Virtual disk :1.0  :           :83884032 : C:
\\.\PHYSICALDRIVE1 :EMC    :SYMMETRIX    :5876 :8802182000 :0        : S:
\\.\PHYSICALDRIVE3 :EMC    :SYMMETRIX    :5876 :8804965000 :0        : T:
12
```
From the output, I can see that the preamble ("Inquiry utility, Version V7.3" etc) is 6 lines, and I have received an array of 12 lines. So I'll rename my first variable to TextArray (to keep things clear) and try this:
```powershell
$TextArray = & .\inq.exe -winvol
$Text = $TextArray | select -Skip 6 | Out-String
$Text = $Text -replace '-------------------------------------------------------------------------------------'
$Text


DEVICE             :VEND   :PROD         :REV  :SER NUM    :CAP(kb)  :WIN vol

\\.\PHYSICALDRIVE0 :VMware :Virtual disk :1.0  :           :83884032 : C:
\\.\PHYSICALDRIVE1 :EMC    :SYMMETRIX    :5876 :8802182000 :0        : S:
\\.\PHYSICALDRIVE3 :EMC    :SYMMETRIX    :5876 :8804965000 :0        : T:
```
Now I have blank lines in my input. So, at this stage, I spend a while mucking about with regex to try to match the multilines and get upset, because there are a number of regex tools in powershell and none of them work the same way. So I'll be cheap and do this:
```powershell
$Text = & .\inq.exe -winvol
$Text = $TextArray | select -Skip 6 | Out-String
$Text = $Text -replace '-------------------------------------------------------------------------------------'
$Lines = $Text -split '\r\n' | where {-not [string]::IsNullOrWhiteSpace($_)}
$Lines

DEVICE             :VEND   :PROD         :REV  :SER NUM    :CAP(kb)  :WIN vol
\\.\PHYSICALDRIVE0 :VMware :Virtual disk :1.0  :           :83884032 : C:
\\.\PHYSICALDRIVE1 :EMC    :SYMMETRIX    :5876 :8802182000 :0        : S:
\\.\PHYSICALDRIVE3 :EMC    :SYMMETRIX    :5876 :8804965000 :0        : T:
```
OK, that's the crucial first stage. From here on we're golden, especially since the output is very helpfully separated consistently with a colon. THANKS, EMC! Brocade, take note.

In a problem like this, the next stage is always always going to be nested loops. You have tabular data, so you have to iterate over the rows and then iterate over each field.

The inner loop is going to be a for loop, because we are going to index into both the array of the row we're working on, and also the header row
```powershell
foreach ($Row in $Rows) {
    $HT = @{}
    for ($i=0; $i -lt $ColumnHeaders.Count; $i++) {

    }
    $Output.Add($HT)
}
```
I've skipped a few steps there. To explain: we have to split each row into substrings, commonly called 'tokens'. The header row tokens will be our column names, the row tokens will be our values. We also know that we're going to be adding values to something in the inner loop and then adding the result to some kind of array, so I've defined a hashtable, $HT, and added it to an $Output array.

If I add the definitions for those variables:
```powershell
#    ...code we've already seen, above...

$Output = @()
$HeaderRow = $Lines[0]
$Rows = $Lines[1..($Lines.Count)]
$ColumnHeaders = $HeaderRow -split ':'

foreach ($Row in $Rows) {
    $HT = @{}
    $Values = $Row -split ':'
    for ($i=0; $i -lt $ColumnHeaders.Count; $i++) {
        $HT += @{
            $ColumnHeaders[$i] = $Values[$i]
        }
    }
    $Output += $HT
}
```
As I'm going along, I keep looking at $Output to see if I'm getting closer to the desired result. Trial and error all the way! This is basically complete now. One thing that's important is to call Trim() on the tokens (because it will really throw later tasks out of whack if you have spaces that aren't easy to see):
```powershell
$ColumnHeaders[$i].Trim() = $Values[$i].Trim()
```
If you don't do the above, you'll try something like this:
```powershell
$Obj.REV
```
and wonder why you don't get any output when you can _see_ the output in Format-Table. You will be forced to do this:
```powershell
$Obj.'REV         '
```
Not helpful to your colleagues!

The only difference between this code we've got to so far and the first codeblock I pasted is a smidgen of refactoring. "Refactoring" is the process of changing the internals of code without changing the end result. It's very important to keep doing this as you go along. Examples: rename variables and functions so that they continue to make sense once the code has evolved a bit; tidy up code constructs when you find better ways of doing things. If you never refactor, your code is going to be janky ;-)

Before refactor:
```powershell
$Text = & .\inq.exe -winvol
$Text = $TextArray | select -Skip 6 | Out-String
$Text = $Text -replace '-------------------------------------------------------------------------------------'

$Lines = $Text -split '\r\n' | where {-not [string]::IsNullOrWhiteSpace($_)}
$Output = @()
$HeaderRow = $Lines[0]; $Rows = $Lines[1..($Lines.Count)]
$ColumnHeaders = $HeaderRow -split ':'

foreach ($Row in $Rows) {
    $HT = @{}
    $Values = $Row -split ':'
    for ($i=0; $i -lt $ColumnHeaders.Count; $i++) {
        $HT += @{
            $ColumnHeaders[$i].Trim() = $Values[$i].Trim()
        }
    }
    $Output += (New-Object psobject -Property $HT)
}
$Output | ft
```
After refactor:
```powershell
$Output = @()

$Lines = & .\inq.exe -winvol
$Lines = $Lines | 
    select -Skip 6 | 
    where {$_ -notmatch '^-*$'}
$HeaderRow = $Lines[0]; $Rows = $Lines[1..($Lines.Count)]
$ColumnHeaders = $HeaderRow -split ':'

foreach ($Row in $Rows) {
    $HT = @{}
    $Values = $Row -split ':'
    for ($i=0; $i -lt $ColumnHeaders.Count; $i++) {
        $HT += @{
            $ColumnHeaders[$i].Trim() = $Values[$i].Trim()
        }
    }
    $Output += (New-Object psobject -Property $HT)
}
$Output | ft
```
Finished (more or less) code:

https://gist.github.com/fsackur/afb34f3f93310fea2f60393abae8da98

I hope this helps when you have to map a CLI utility into a powershell function.
