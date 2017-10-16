---
layout: post
title: Migrating the blog to Github Pages
date: 2017-10-11 01:04
author: freddiesackur
comments: true
tags: [Jekyll, Ruby, 'Github Pages', meta]
---

I started blogging on wordpress.com. It was not a carefully considered decision.

I didn't like the interface much, or working directly in HTML. Posting code blocks was utter hell because the app would munch whitespace sequences, like a greedy housemate who eats all the cake except for one tiny slice.

I wanted to get away from it almost as soon as I started.

# I LIKE TO MOVE IT, MOVE IT

Github Pages is great, because it fits in the workflow of a git user, and because you write posts in markdown instead of html. And this is a cool theme, no?

Any pushes to your blog repo on github.com result in Jekyll being invoked, in Github, to render your .md into .html. So it's very simple once you're up and running - but as a Windows person without prior experience of Ruby, I had some figuring out to do.

## Existing guides

Exisiting guides mostly fall short for my scenario. You can follow steps to install Ruby, follow steps to create a github.io repo, follow steps to structure your folders... but this is the wrong approach. Here's what worked for me:

# 1

Choose a theme. Just google for 'jekyll theme site:github.com' - they will all be hosted in Github.

Your blog posts are highly portable, your theme is maybe not so much. Find a Jekyll theme that you like on github, and fork it. Rename your fork to `<username`>.github.io, like [this](https://github.com/fsackur/fsackur.github.io). Clone it locally.

# 2

Edit the stock text - for example, you'll want to change any names or twitter handles, customise your "about" page, etc. This will vary according to the theme you pick, but it's safe to say that there will be some existing .html and/or .md files when you clone your theme. Go through those and edit them.

# 3

Write a blogpost in .md, save it in the _posts folder, commit to master, and push. A fully-featured and themed blogpost will automatically appear at your new url! Unless... you fail to meet the...

## Requirements

Your .md blogpost file must meet some syntax requirements for Jekyll to process it into html.

1. File name: this must exactly match the format laid out in your theme. I'm not sure if this is customisable, but my site requires my filenames to be in the _posts directory and look like yyyy-mm-dd-all-lowercase-title-with-dashes.md

2. Post header: header text must match the sample posts that your theme probably included. Mine looks like this:

```
---
layout: post
title: Migrating the blog to Github Pages
date: 2017-10-11 01:04
author: freddiesackur
comments: true
tags: [Jekyll, Ruby, meta]
---
```

### Build errors?

If you don't see your page appear after 5 minutes, then:
- log into your github.io repo on Github
- under Settings, scroll down to the Github Pages section and look at Build Errors

# Migrating posts from wordpress

I exported my site from Wordpress and then used [wpxml2jekyll](https://github.com/theaob/wpXml2Jekyll) to convert it. I copied all the resulting .md files into the _posts folder and... still had a lot to do. The pages are still full of static html, possibly because of the amount I had done to try to make my code look nice on WP.

> There are many native importers from other blog sites on the [Jekyll site](http://import.jekyllrb.com/), but they all assume that you have a functional Ruby installation. I got very headbangy trying to make that happen in a hurry, so please see my steps below and use chocolatey to install Ruby, _not_ the Ruby downloads page.

A combination of the following was enough to convert any remaining html tags into their equivalent markdown:
- VS Code's Find-and-replace in all files
- Regex matching for HTML tags, e.g. ```</?em>``` replace with ```**```
- Disregard for my own leisure time

Fortunately, it was a one-time task. Hopefully this won't be so bad for you.

# Building your site locally

One thing that isn't great is that you have to publish your posts to see them. That doesn't have to be the case if you run jekyll on a local ruby installation. Please, Windows users, do yourself a favour, and use chocolatey to install.


### Install chocolatey, if you don't already have it:
```
PS C:\dev\fsackur.github.io> Set-ExecutionPolicy Bypass; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
#Refresh your path variable
PS C:\dev\fsackur.github.io> $Env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine')
```

### Install ruby:
```
PS C:\dev\fsackur.github.io> choco install ruby -y

Chocolatey v0.10.5
Installing the following packages:
ruby
By installing you accept licenses for the packages.
Progress: Downloading ruby 2.4.2.2... 100%

ruby v2.4.2.2 [Approved]
ruby package files install completed. Performing other installation steps.
Ruby is going to be installed in 'C:\tools\ruby24'
Installing 64-bit ruby...
ruby has been installed.
Environment Vars (like PATH) have changed. Close/reopen your shell to
 see the changes (or in powershell/cmd.exe just type `refreshenv`).
 The install of ruby was successful.
  Software installed to 'C:\tools\ruby24\'

Chocolatey installed 1/1 packages. 0 packages failed.
 See the log for details (C:\ProgramData\chocolatey\logs\chocolatey.log).

#Refresh your path (refreshenv may work; YMMV)
PS C:\dev\fsackur.github.io> $Env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine')
```

### You should have Ruby now:
```
PS C:\dev\fsackur.github.io> ruby -v
ruby 2.4.2p198 (2017-09-14 revision 59899) [x64-mingw32]
```

### Install jekyll:
```
PS C:\dev\fsackur.github.io> gem install jekyll
Fetching: public_suffix-3.0.0.gem (100%)
Successfully installed public_suffix-3.0.0
Fetching: addressable-2.5.2.gem (100%)
Successfully installed addressable-2.5.2
Fetching: colorator-1.1.0.gem (100%)
Successfully instal...

        ...umentation for rouge-2.2.1
Installing ri documentation for rouge-2.2.1
Parsing documentation for jekyll-3.6.0
Installing ri documentation for jekyll-3.6.0
Done installing documentation for public_suffix, addressable, colorator, rb-fsevent, ffi, rb-inotify, sass-listen, sass, jekyll-sass-converter, listen, jekyll-watch, kramdown, liquid, mercenary, forwardable-extended, pathutil, rouge, safe_yaml, jekyll after 19 seconds
19 gems installed
```

### Install bundle
```
PS C:\dev\fsackur.github.io> gem install bundle
Fetching: bundler-1.15.4.gem (100%)
Successfully installed bundler-1.15.4
Fetching: bundle-0.0.1.gem (100%)
Successfully installed bundle-0.0.1
Parsing documentation for bundler-1.15.4
Installing ri documentation for bundler-1.15.4
Parsing documentation for bundle-0.0.1
Installing ri documentation for bundle-0.0.1
Done installing documentation for bundler, bundle after 6 seconds
2 gems installed
```

### ...wait for it! Add a gitiginore for the rendered site (this goes into _site and should not be published to Github. This file needs to go in the root of your repo):
```
"`n_site`n" | Out-File '.gitignore' -Append -Encoding ascii
```

### Install any gems from the theme's Gemfile:
```
PS C:\dev\fsackur.github.io> bundle install
Fetching gem metadata from https://rubygems.org/..........
Fetching version metadata from https://rubygems.org/..
Fetching dependency metadata from https://rubygems.org/.
Using public_suffix 3.0.0
Using bundler 1.15.4
Using ffi 1.9.18 (x64-mingw32)
Fetching jekyll-paginate 1.1.0
Installing jekyll-paginate 1.1.0
Using rb-fsevent 0.10.2
Using kramdown 1.15.0
Using rouge 2.2.1
Using addressable 2.5.2
Using rb-inotify 0.9.10
Using listen 3.0.8
Using jekyll-watch 1.5.0
Bundle complete! 5 Gemfile dependencies, 11 gems now installed.
Use `bundle info [gemname]` to see where a bundled gem is installed.
```

### _Now_ you can build your site:
```
PS C:\dev\fsackur.github.io> jekyll build
Configuration file: C:/dev/fsackur.github.io/_config.yml
       Deprecation: The 'gems' configuration option has been renamed to 'plugins'. Please update your config file accordingly.
            Source: C:/dev/fsackur.github.io
       Destination: C:/dev/fsackur.github.io/_site
 Incremental build: disabled. Enable with --incremental
      Generating...
                    done in 0.779 seconds.
 Auto-regeneration: disabled. Use --watch to enable.
 ```

 You should now see a folder called _site containing all your html in folders. You can drill down into it and open the posts! ...just kidding, you will actually get some build failures first:
 ```
 C:/Ruby24-x64/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:55:in `require': cannot load such file -- kramdown (Load Error)
        from C:/Ruby24-x64/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:55:in `require'
        from C:/Ruby24-x64/lib/ruby/gems/2.4.0/gems/jekyll-3.6.0/lib/jekyll/plugin_manager.rb:48:in `require_from_bundler'
        from C:/Ruby24-x64/lib/ruby/gems/2.4.0/gems/jekyll-3.6.0/exe/jekyll:11:in `<top (required)>'
        from C:/Ruby24-x64/bin/jekyll:23:in `load'
        from C:/Ruby24-x64/bin/jekyll:23:in `<main>'
```

The missing gem is named in the first line - in example above, it is kramdown. Add the following line to your Gemfile:
```
gem 'kramdown'
```

> Gemfile and Gemfile.lock should not be in your .gitignore

Install with bundle:
```
PS C:\dev\fsackur.github.io> bundle install
```

Try to build the site again:
```
PS C:\dev\fsackur.github.io> jekyll build
```

Keep going until it succeeds.

Now start the jekyll server and set it to watch and rebuild on filesystem changes:
```
PS C:\dev\fsackur.github.io> jekyll serve --watch
Configuration file: C:/dev/fsackur.github.io/_config.yml
       Deprecation: The 'gems' configuration option has been renamed to 'plugins'. Please update your config file accord
ingly.
            Source: C:/dev/fsackur.github.io
       Destination: C:/dev/fsackur.github.io/_site
 Incremental build: disabled. Enable with --incremental
      Generating...
                    done in 0.616 seconds.
  Please add the following to your Gemfile to avoid polling for changes:
    gem 'wdm', '>= 0.1.0' if Gem.win_platform?
 Auto-regeneration: enabled for 'C:/dev/fsackur.github.io'
    Server address: http://127.0.0.1:4000
  Server running... press ctrl-c to stop.

```

You can see from the above that your site is available on http://127.0.0.1:4000. Get it right then push to Github.

> I haven't been able to get jekyll to consistently render all the styles correctly when running locally. If you have that issue, try pushing and see if your live site renders correctly.
