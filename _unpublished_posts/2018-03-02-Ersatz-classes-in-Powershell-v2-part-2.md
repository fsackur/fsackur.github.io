---
layout: post
title: Ersatz classes in Powershell v2 part 2
date: 2018-03-02 09:10
author: freddiesackur
comments: true
tags: [Uncategorized]
---



$ParentDef = {
    #A type definition for a blogger
    param(
        [string]$Name,
        [string]$Topic
    )

    
    function GetBlogpost([uint16] $Length) {
        return (@($Topic) * $Length) -join ' '
    }
}

$ChildDef = {
    #A type definition for a blogger named "Freddie" who posts about Powershell
    param(
    )
    
    $Name = "Freddie"
    $Topic = "Powershell"

    New-Module $ParentDef -ArgumentList ($Name, $Topic)

}

$Child = New-Module $ChildDef -AsCustomObject
$Child.GetBlogpost(7)
#Powershell Powershell Powershell Powershell Powershell Powershell Powershell



$ParentDef = {
    #A type definition for a blogger
    param(
        [string]$Name,
        [string]$Topic
    )

    
    function GetBlogpost([uint16] $Length) {
        return (@($Topic) * $Length) -join ' '
    }
}

$ChildDef = {
    #A type definition for a blogger named "Freddie" who posts about Powershell
    param(
    )
    
    $Name = "Freddie"
    $Topic = "Powershell"

    New-Module $ParentDef -ArgumentList ($Name, $Topic)

    function GetBlogpost([uint16] $Length) {
        return ((@($Topic) * $Length) -join ' ').ToLower()
    }
}

$Child = New-Module $ChildDef -AsCustomObject
$Child.GetBlogpost(7)
#powershell powershell powershell powershell powershell powershell powershell


