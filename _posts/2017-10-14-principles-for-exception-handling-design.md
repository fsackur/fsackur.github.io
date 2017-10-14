---
layout: post
title: Principles for exception-handling design
date: 2017-10-14 02:51
author: mikera
comments: true
tags: [Uncategorized]
---
I came across the answer by [mikera](https://softwareengineering.stackexchange.com/users/6909/mikera) to [this question](https://softwareengineering.stackexchange.com/questions/109297/recommend-a-design-pattern-approach-to-exposing-tolerating-recovering-from-syste) on stackexchange, and thought it worth recycling (the rest of this post is her/his words):

- **Consider exceptions as part of the interface to each function / modules** - i.e. document them and where appropriate / if your language supports it then use checked exceptions.
- **Never fudge a failure** - if it failed, don't try to continue with some attempt to "assume" how to proceed. For example, special handling for null cases is often a code smell to me: if your method needs a non-null value, it should be throwing an exception immediately if it encounters a null (either NullPointerException or ideally a more descriptive IllegalArgumentException).
- **Write unit tests for exceptional cases as well as normal ones** - sometimes such tests can be tricky to set up but it is worth it when you want to be sure that your system is robust to failures
- **Log at the point where the error was caught and handled (assuming the error was of sufficient severity to be logged)** . The reason for this is that it implies you understood the cause and had an approach to handle the error, so you can make the log message meaningful.....
- **Use exceptions only for truly unexpected conditions/failures.** If your function "fails" in a way that is actually expected (e.g. polling to see if more input is available, and finding none) then it should return a normal response ("no input available"), not throw an exception
- **Fail gracefully (credit to Steven Lowe!)** - clean up before terminating if at all possible, typically by unwinding changes, rolling back transaction or freeing resources in a "finally" statement or equivalent. The clean-up should ideally happen at the same level at which the resources were committed for the sake of clarity and logical consistency.
- **If you have to fail, fail loudly** - an exception that no part of your code was able to handle (i.e. percolated to the top level without being caught + handled) should cause an immediate, loud and visible failure that directs your attention to it. I typically halt the program or task and write a full exception report to System.out.
