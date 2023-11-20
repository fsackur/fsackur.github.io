---
layout: post
title: Unit-testing PS help
date: 2017-04-07 23:29
author: freddiesackur
comments: true
tags: [help, Pester, Powershell, 'unit test']
---
It's really useful to have someone to keep you honest if you don't write help for your PS functions as you go. I find it hard to update help continually, so a red test makes sure I don't check in code with no help.


## Pester tests for PS function-based help
```powershell
#Help.Tests.ps1

Describe 'Function help' {

    $ExportedCommands = (
                            Get-Module $ModuleName |
                            select -ExpandProperty ExportedCommands
                        ).Keys

    Context 'Correctly-formatted help' {
        It 'Provides examples for every exported function' {
            foreach ($Command in $ExportedCommands)
            {
                (Get-Help $Command -Examples |
                Out-String) |
                Should Match '-------------------------- EXAMPLE 1 --------------------------'
            }
        }
    }
}
```
It literally does text matching on the output of Get-Help piped to Out-String. Not very powershelly! Perhaps it should use grep.

It would be tough to write a unit test to ensure the help is actually useful. But this will validate that all the examples are syntactically correct:
```powershell
#Help.Tests.ps1

$ModuleName = 'FunkyModule'
Import-Module "$PSScriptRoot\$ModuleName.psm1" -Force


Describe 'Function help' {
    Context 'Correctly-formatted help' {

        foreach (
            $Command in (
                Get-Module $ModuleName |
                select -ExpandProperty ExportedCommands
                ).Keys
            )
            {
                $Help = Get-Help $Command

                It "$Command has one or more help examples" {
                    $Help.examples.example | Should Not Be $null
                }

                #Test only the parameters? Mock it and see if it throws
                Mock $Command -MockWith {}

                It "$Command examples are syntactically correct" {
                    foreach ($Example in $Help.examples.example) {
                        [Scriptblock]::Create($Example.code) |
                            Should Not Throw
                    }
                }
            } #end foreach
    }
}
```
Get-Help returns an object that parses the code example out of the rest of the example text. Unfortunately, it only recognises a single line of code. The following will not properly test the code, because the .code property will be only the $MyVar line:
```powershell
<#
    .Example
    PS C:\> $MyVar = 'Djibouti', 'Fiji'

    PS C:\> Get-CapitalCity -Country $MyVar

    Gets the capital city
#>
```

## Testing the syntax
Pester mocking transparently recreates the param block of the command you are mocking, so, to save handling the running of the command, we just run an empty mock of it:
```powershell
    #Test only the parameters? Mock it and see if it throws
    Mock $Command -MockWith {}
```
If we run the tests on a module like this:
```powershell
**#FunkyModule.psm1**

function Funk {
    <#
        .Example
        PS C:\> Funk -Disco

        .Example
        PS C:\> Funk -On 1, 2, 3, 4

        some helpful text
     #>
     [CmdletBinding()]
     param(
         [switch]$Disco,
         [int[]]$On
     )

     Write-Host "Lorem ipsum"
}
```
The object form the Get-Help pulls out the example commands from the function help:
```powershell
PS C:\> foreach ($Example in $Help.examples.example) {
           [Scriptblock]::Create($Example.code)
}
Funk -Disco
Funk -On 1, 2, 3, 4
```
This matches the param block:
```powershell
     param(
         [switch]$Disco,
         [int[]]$On
     )

```
Therefore this test passes. But if we change or delete one of the parameter declarations so the examples are no longer correct, the test fails:
```powershell
PS C:\> .\dev\FunkyModule\Help.Tests.ps1
Describing Function help
   Context Correctly-formatted help
    [+] Funk has one or more help examples 45ms
    [-] Funk examples are syntactically correct 46ms
      Expected: the expression not to throw an exception. Message was {A parameter cannot be found that matches parameter name 'Disco'.}
          from line:1 char:6
          + Funk -Disco
          +      ~~~~~~
      32:                         [Scriptblock]::Create($Invocation) | Should Not Throw
      at , C:\dev\FunkyModule\Help.Tests.ps1: line 32

```
The message it gives you tells you how you borked it:
```powershell
Message was {A parameter cannot be found that matches parameter name 'Disco'.}
```
So there you have it - unit testing for Powershell function help.
