param(
    [Parameter(Mandatory=$true)]
    [string]$Title
)

$DateString = (Get-Date).ToString('yyyy-MM-dd HH:mm')
$Filename = "$($DateString -replace ' .*')-$($Title -replace ' ', '-').md"
$Path = Join-Path (Resolve-Path $PSScriptRoot\..\_posts) $Filename

$Header = @"
---
layout: post
title: $Title
date: $DateString
author: freddiesackur
comments: true
tags: [Uncategorized]
---
"@

$Header | Out-File $Path -NoClobber -Encoding utf8
