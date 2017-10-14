---
layout: post
title: Principles for exception-handling design
date: 2017-10-14 02:51
author: mikera
comments: true
tags: [Uncategorized]
---
Postcard from the bowels of the regex beast!

I want to derive some exception classes and pass in a message that comes from the relevant value of ErrorCategory.

ErrorCategory is an enum with 32 values that are no-whitespace strings in sentence case:
```powershell
[Enum]::GetValues(
    [System.Management.Automation.ErrorCategory])
```
```plaintext
NotSpecified
OpenError
CloseError
DeviceError
DeadlockDetected
# ...etc
```

> That [System.Enum]::GetValues() method works on any enum.

I don't want to text-edit them all myself, we have computers for that.

Step 1, split them:
```powershell
[System.Enum]::GetValues(
    [System.Management.Automation.ErrorCategory]

) | select -First 1 | foreach {

    [regex]::Matches(
        $_, 
        '[A-Z][a-z]*'
    ).Value
}
```
```plaintext
Not
Specified
```

Does anyone else select only the first item while work is in progress? Saves some scrolling. On which note, sorry about the awkward spacing, this blog theme makes horizontal space very precious. 

Complete snippet:
```powershell
[System.Enum]::GetValues(
    [System.Management.Automation.ErrorCategory]

) | %{
    $Words = [regex]::Matches(
        $_, 
        '[A-Z][a-z]*'
    ).Value

    $Words = @($Words[0]) + ($Words | select -Skip 1 | %{$_.ToLower()})
    $Words -join ' '
}
```
```plaintext
Not specified
Open error
Close error
Device error
Deadlock detected
# ...etc
```

My love/hate relationship with regex continues.
