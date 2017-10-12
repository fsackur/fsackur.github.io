---
layout: post
title: API for running Powershell
date: 2017-06-05 16:42
author: freddiesackur
comments: true
tags: [Uncategorized]
---
This is a rambling post with my initial thoughts on how you'd go about building a web service that runs Powershell from a script library on servers.


# Executive summary
Our current tool costs us 46,500 hours per annum against a replacement. Replacing the tool would cost 24,000 hours. The second half of this memo is the implementation details, ready for initial assessment by our security team.


# Context
We are a large hosting company. We are security conscious. Our service desk accesses our customers' servers by their public IP addresses via security choke points.

At the moment, we access the boxes two ways: RDP using an RDS Gateway solution that performs inspection and logging, or using our automation tool for which we log in to an RDS farm that has direct access to the boxes. That (obviously) is heavily monitored too.

Both of these are... sub-optimal.


# Requirement
Provide a service to allow Powershell scripts to be run on customer servers.

	* low latency
	* restrict what can be run to only our library of peer-reviewed scripts
	* run all connections through a choke point for inspection and logging
	* provide PSObjects back to the user that they can manipulate
	* enable easy development of script
	* authenticated using one of our existing identity providers (OAuth, SAML, or one of two in-house apps)


# Lessons from the past
This ain't our first rodeo. Our current solution is successful enough to generate screams if it breaks. That has almost become a downside, as we are now stuck with it.

	* doesn't return objects to the shell, only as CSV or BBCode

	* hard to present output in useful ways
	* impossible to chain script output


	* clunky CLI or GUI - makes our techs inefficient
	* no access at all from the desktop - we can't offer it on our techs' workflow
	* slow - a 3-second script takes 2 minutes to return

As if that weren't enough, this is what really grinds my gears:

	* _developing scripts for this platform is incredibly time-consuming due to the number of systems that must be manually touched to import new code, test code, submit for peer review, and deploy_

In sum: it's been an enormous effort to build and maintain our script library, and the tool is not enabling our staff nearly as much as it could do. _We should have bought a solution long ago, but we didn't, and we never will._ Readers, you know how it goes!


# Business cost
Let's say a tech invokes the tool 10 times a day, and each run takes two minutes longer to return than the best alternative. Let's say we have 300 techs. Let's say the tech can do something else during those 2 minutes, but that their efficiency is halved.
<p style="text-align:center;">**20 min p.d. at half efficiency x 200 work days x 300 techs = 10,000 hours p.a.**</p>
Let's say that the platform is unreliable, so that every fifth run, a tech needs to spend 20 minutes manually following-up.
<p style="text-align:center;">**20 min p.d. x 200 work days x 300 techs = 20,000 lost hours p.a.**</p>
Let's say your developers save an average of 10 staff hours for every one hour of development. Let's say that there's an overhead of 10% caused by the inefficiencies of the tool as a development platform. Let's say that the total development effort for the script in the library is 1,000 hours p.a.
<p style="text-align:center;">**1,000 dev hours x 10x multiplier x 10% = 1,000 hours lost p.a.**</p>
<p style="text-align:left;">Let's say there's an opportunity cost to having an inefficient platform. You aren't going to get the best possible script library if it's a headache to develop for the platform, and you will accumulate further technical debt. Let's put that at 50%.</p>
<p style="text-align:center;">**Cost of a bad tool:**
**(10,000 + 20,000 + 1,000) * 1.5 = 46,500 hours p.a.**</p>
<p style="text-align:left;">Let's say that a replacement is estimated at 400 hours of dev time. Let's double it for a figure to give to management. Let's double that, because you always do. Then let's throw in another 50% for post-release improvements.</p>
<p style="text-align:center;">**400 x 2 x 2 x 1.5 = 2400 dev hours ~= 24000 staff hours**</p>
<p style="text-align:left;">We should buy a solution if one is available off-the-shelf. In the absence of budget, we should develop a solution.</p>
<p style="text-align:left;"></p>


# Perspective
This isn't a tool, it's a platform.

The platform must be comfortable for end-users and for developers (after all, our time is worth ten times as much!)

The platform must be amenable to debugging, because we will always write bugs.

We aren't just designing code, we are designing business processes around the lifecycle of code (or implementing our existing processes). Processes give us our controls for PCI compliance and cannot be skimped, so we need to fulfill them efficiently.

Based on this, I'm going to draw up further requirements:

	* testing and submitting scripts for peer review must be invoked simply by checking script into our github
	* this must then invoke the script on servers in our test environment and post the output somewhere that is already in the workflow for the peer reviewer
	* If this is a bugfix or new feature, output must be diffed against previous output from each server to ensure we aren't making a breaking change (caveat: there can and will be configuration drift on our test account)
	* If the output looks like it ran without error, send to a peer review queue (we use Jira, so that will be a status change)
	* If peer review passes, code must be automatically deployed within one hour (hopefully seconds!)
	* Authorised dev users must be able to run script, against the test environment only, without invoking this process


# Architecture
It's inescapable that we require an API. That will provide the choke point and enable us to restrict the code exposed to just the script in the library. Because our customer environments are heterogenous, we cannot reliably enforce constraints on powershell directly from desktop to customer box, and that would also not provide the throttling and central inspection that we need. (At our scale, one command can do a lot of damage.)

For security, the API front end is not going to have direct access to customer servers. It will perform authentication and use its own service account to call the back end, which will have access to customer servers.

The back end uses standard powershell remoting to invoke script. The back end will use its own service account to pull customer server info from the configuration source, will set up the PSSessions, manage the runspaces, and package the results with the metadata. We will log resource usage on the customer box, and we will include alternate data streams (such as exceptions) to provide instant high-quality feedback.

To prevent against attacks by injecting unexpected parameters into scripts, we must have a githook that blocks script from being committed without cmdlet binding. That must be server-side, since client-side githooks are not enforced.

Server side githooks call CI tools. This will be internally-hosted, and likely AppVeyor or Jenkins - let's say Jenkins because it's cost-free. Jenkins will use a token with the dev flag so that it can hit the API and test the script. Jenkins will paste output to our issue tracker, sorted by test server hostname, and highlight any differences to previous output on the commit comments in github. Jenkins will send a pull request if the tests pass, and set the issue to the QC status in Jira.

On merge, another githook calls Jenkins to push the new code to the back end and to the client repository (more on that later).
