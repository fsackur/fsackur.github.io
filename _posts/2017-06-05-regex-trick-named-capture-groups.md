---
layout: post
title: Regex trick - named capture groups
date: 2017-06-05 12:16
author: freddiesackur
comments: true
tags: [Powershell, Regex]
---
I just wanted to share something that I find really cool. _(https://kevinmarquette.github.io/" target="_blank" rel="noopener noreferrer">Kevin Marquette replied to my comment on a forum _with this trick! </starstruck>


# Named captures in PS
```powershell
$Text =
'ERROR: Exception occurred in application FruitComparison.
12 Apples
16 Oranges
Resulted in Divide By Citrus at line 666'

$Text -match '(?<Severity>\w*).*'
$Matches
True

Name                           Value
----                           -----
Severity                       ERROR
0                              ERROR: Exception occurred in application FruitComparison....</span>
```
Reminder, this is what the $Matches automatic variable looks like when you use a subgroup that isn’t named:
```powershell
$Text -match '(\w*).*'
$Matches
True

Name                           Value
----                           -----
1                              ERROR
0                              ERROR: Exception occurred in application FruitComparison....</span>
```
'\w' captures all 'word' characters, of course.

The problem sometimes with unnamed captures is that you might want to pick out captures 3, 7 and 9, but you have a nagging concern that one day someone will feed it input that has an extra capture between 5 and 6. That will jank up the rest of your code.

Here’s the full pattern:
```powershell
$Text =
'ERROR: Exception occurred in application FruitComparison.
12 Apples
16 Oranges
Resulted in Divide By Citrus at line 666'

$Pattern = '(?<Severity>\w*): Exception .*? application (?<Application>\w*)\.\r\n(?<Input1>.*)\r\n(?<Input2>.*)\r\nResulted in (?<ExceptionType>.*?) at line (?<Line>\d*)$'

if ($Text -match $Pattern) {
    $Matches
}

Name                           Value
----                           -----
Input1                         12 Apples
ExceptionType                  Divide By Citrus
Severity                       ERROR
Line                           666
Input2                         16 Oranges
Application                    FruitComparison
0                              ERROR: Exception occurred in application FruitComparison....</span>
```
$Matches is a kind of custom dictionary / hashtable, which isn’t always that useful. (quick note: don't forget that if a match fails but you then look in $Matches, you'll get the results from the previous successful match, which is the reason for the if statement.)
But guess what? You can get from input text to psobject in very little code:
```powershell
if ($Text -match $Pattern) {
    $Matches.Remove(0)
    New-Object psobject -Property $Matches

} else {
    throw (New-Object System.Management.Automation.ParseException ("Error parsing input"))
}

Input1        : 12 Apples
ExceptionType : Divide By Citrus
Severity      : ERROR
Line          : 666
Input2        : 16 Oranges
Application   : FruitComparison</span>
```
I found that ParseException class by googling “msdn parse exception” and picking the second hit. I could have gone with InvalidArgument or similar.

[MSDN reference for .net implementations of regex](https://msdn.microsoft.com/en-us/library/az24scfc(v=vs.110).aspx)

Hope you enjoyed.
