param
(
    [Parameter(Mandatory)]
    [string]$Title,

    [ArgumentCompleter({
        $TagLines = Get-ChildItem $PSScriptRoot/../_posts, $PSScriptRoot/../_unpublished_posts |
            Get-Content -TotalCount 10 |
            Select-String ^tags
        $Tags = $TagLines -replace '^tags:\s*' |
            ForEach-Object {ConvertFrom-Yaml $_} |
            Write-Output |
            Sort-Object -Unique
        $Tags = $Tags -replace '(.*\s.*)', "'`$1'"
        $Tags
    })]
    [string[]]$Tag = 'Uncategorized'
)

$DateString = (Get-Date).ToString('yyyy-MM-dd HH:mm')
$Filename = "$($DateString -replace ' .*')-$($Title -replace ' ', '-').md"
$Path = Join-Path (Resolve-Path $PSScriptRoot/../_unpublished_posts) $Filename

$Tags = $Tag -replace '(.*\s.*)', "'`$1'"
$TagString = $Tags -join ', '

$Header = @"
---
layout: post
title: $Title
date: $DateString
author: freddiesackur
comments: true
tags: [$TagString]
---
"@

$Header | Out-File $Path -NoClobber -Encoding utf8
