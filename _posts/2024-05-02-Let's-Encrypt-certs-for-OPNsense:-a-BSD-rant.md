---
layout: post
title: "Let's Encrypt certs for OPNsense"
subtitle: A BSD rant
date: 2024-05-02 13:28
author: freddiesackur
comments: true
tags: [OPNsense, BSD]
---

## OPNsense

I have OPNsense as my home firewall. I like it - it gives you a lot of business-class features, with a very accessible GUI, and runs on commodity PC hardware.

My home network runs on a domain I own, for which I have certbot generating certs. I write these to an NFS share, which other services mount.

Unfortunately for sysads, OPNsense doesn't just read certs from the filesystem. Oh no. You have to either paste the cert contents into the GUI, or invoke the REST API.

The CLI story for OPNsense is bad. I have found a few online, none of which are complete.

In fact, the OPNsense API reference warns you that it may not be complete, as they parse the source code looking for controllers. I like hacking, but that is poor in this day and age. Perhaps PHP is not a great choice for systems programming 🤔

I reject this solution for my home network, because it implies running scripts on a trigger. That adds a network connection, a shared secret, a failure mode, and a monitoring overhead. I don't have sysads on staff! I intend to make OPNsense use whatever damned cert I give it through the filesystem.

## Boot order

OPNsense is built on FreeBSD. BSD is a common choice for network appliances, because it has (claimed) great network performance, and because it has an extremely customisable init system.

I do not view a customisable init system as a positive. Case in point: OPNsense boots halfway with shell script, then hands over to PHP script to continue boot. I am not convinced of the value of PHP as a boot configuration language 🤔

The filthy part, apart from _all of it_, is [`webgui.inc`](https://github.com/opnsense/core/blob/93e0d14/src/etc/inc/plugins.inc.d/webgui.inc) (as of 24.1.6). Here's what it does:

- if no cert is defined in the XML config, then read the cert from `/var/etc/cert.pem` and `key.pem` and import it into the config
- otherwise, write the cert content from config back to those files
- dynamically generate a lighttpd config and write it to `/var/etc/lighty-webConfigurator.conf` with the cert path hard-coded

In other words, it will overwrite your certs, and it will overwrite your lighttp config, and if you overwrite the bit that does the overwriting, your overwrite will be overwritten when you update.

## Web gui overrides

Fortunately, OPNsense gives you an escape hatch. You can drop lighttpd config overrides into `/usr/local/etc/lighttpd_webgui/conf.d/`. If you do this, you can restart the webgui with `configctl webgui restart`.

The conf you will want is:

```plaintext
ssl.privkey = "/path/to/privkey.pem"
ssl.pemfile = "/path/to/cert.pem"
```

But: if you do this, you'll get an error in the log saying `duplicate config variable`.

Fortunately, from 1.4.46, lighttpd supports `:=` to override variables, and OPNsense 24.1.6 has version `1.4.75`.

But: it still doesn't work! BSD is all fragmentation. Either FreeBSD, or OPNsense, has compiled lighttpd without the one vital feature to make this drop-in conf.d folder useful. Forking hell!

So. Here is the solution.

- Mount your NFS share as read-only, to prevent OPNsense from overwriting your cert files
- symlink your cert files to `/var/etc/`

Presumably, there's a PHP error happening when `webgui.inc` fails to overwrite, but I don't see it and I don't care.

## NFS mounts on BSD

However. This is not all you have to do. The mounts in `/etc/fstab` are mounted before the networking is started, so your fstab entry will cause boot errors and opnsense will drop into single-user mode.

The common suggestion is to use the `late` option in fstab:

```plaintext
10.66.99.33:/certs /certs nfs ro,late,noatime 0 0
```

This assumes you have a default BSD. Trick question! There is no such thing as a default BSD! BSD is ALL ABOUT making your system as custom as possible!

The way the `late` option works is by calling the `mountlate` script in the `late` section of the pile of boot scripts. OPNsense deletes the entire `late` section, and hands over to its PHP boot system instead.

I finally stumbled upon the `bg` mount option for NFS systems. This tries to mount a filesystem once and, if it fails, spawns a background process to keep trying. For our purposes we want `bgnow`, which skips the foreground mount attempt. Here is the working fstab entry:

```plaintext
10.66.99.33:/certs /certs nfs ro,bgnow,soft,noatime 0 0
```

You could probably add `failok` as well; I haven't tried it. That's the BSD equivalent of `nofail`, because _of course_ the option has to be different.

I respect BSD as an early FOSS pioneer, but it belongs in the past.
