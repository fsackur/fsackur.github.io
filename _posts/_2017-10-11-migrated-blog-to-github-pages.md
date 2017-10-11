# I LIKE TO MOVE IT, MOVE IT

I started blogging on wordpress.com. It was not a carefully considered decision, because I didn't have the required experience.

I didn't like the interface much, or working directly in HTML. Posting code blocks was utter hell because the app would munch whitespace sequences, like a greedy housemate who eats all the cake except for one tiny slice.

Github pages is great, because it fits in the workflow of a git user, and because you write posts in markdown instead of html. I trust you like this theme, too?

Any pushes to your blog repo on github.com result in Jekyll being invoked to render your .md into .html. So it's very simple once you're up and running, but as a Windows person without prior experience of Ruby, I had some figuring out to do.

## Existing guides

Exisiting guides mostly fall short for my scenario. You can follow steps to install Ruby, follow steps to great a github.io repo, follow steps to structure your folders... but this is the wrong approach. Here's what worked for me:

# 1

Choose a theme.

Your blog posts are highly portable, your theme is maybe not so much. Find a Jekyll theme that you like on github, and fork it. Rename your fork to <username>.github.io, like [this](https://github.com/fsackur/fsackur.github.io). Clone it locally.

# 2

Write a blogpost in .md, save it in the _posts folder, commit to master, and push. A fully-featured theme will automatically 



Build errors
https://help.github.com/articles/viewing-jekyll-build-error-messages/
Under Settings for your github.io repo, scroll down to the Github Pages segment and look at Build Errors



```
choco install ruby -y
y
refreshenv
ruby -v
sl .\fsackur.github.io\
gem install jekyll
jekyll -v
bundle install
```
