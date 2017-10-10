---
layout: post
title: C#4PS – compiled powershell modules, part 3
date: 2017-02-19 21:50
author: freddiesackur
comments: true
tags: [Uncategorized]
---
This is the part 3 of a multi-part blog.

[Part 1](../2017-02-16-c4ps-compiled-powershell-modules-part-1) – [Part 2](../2017-02-16-c4ps-compiled-powershell-modules-part-2) – [Part 3](../2017-02-16-c4ps-compiled-powershell-modules-part-3)


# Previously on C#4PS:
We wrote and compiled a really useless class, and showed that we could access it in PowerShell.

<img class="alignnone size-full wp-image-1014" src="https://freddiesackur.files.wordpress.com/2017/02/capture22.png" alt="capture" width="654" height="100" />

And to think they voted us "least likely to succeed".

 
# RunspacePool
In this chapter, we're going to use the RunspacePool class to parallelise PowerShell code. And we're going to compile it as a PowerShell module.


### Background on the RunspacePool class
You may be familiar with Runspaces, which are an important part of the PowerShell remoting, multithreading and asynchronous landscapes. They are to be contrasted with PSJobs in that a PSJob is a separate process, whereas a runspace is merely a separate thread. That makes them faster, because threads don't need to have a new process spun up by the OS, but it makes them non-thread-safe. Code is thread-dangerous if there is the possibility of multiple threads accessing the same variables and objects, because you can have this:

<img src="https://i.makeagif.com/media/2-19-2017/DzekWM.gif">

 

 

 

 
