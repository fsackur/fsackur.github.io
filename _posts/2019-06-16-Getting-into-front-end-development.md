---
layout: post
title: Getting into front end development
date: 2019-06-16 14:32
author: freddiesackur
comments: true
tags: [Uncategorized]
---


One of React's killer features is that the documentation includes some very clear tutorials. This will not replicate them.

React is javascript and is stored in files with .js extension. But actually it's not Javascript, it's Ecmascript. But you import it as type "text/babel".

Create index.html. Stick a meta and head in it. Copy the script tags from another project. All the body needs is a div with id root.

create a .js file. source it in the index.html

\\it requires very little javascript. You can hack away
The first confusing thing is that most of the blogs and SO posts deal with NodeJS. They all have import statements at the top. Ignore these.
React is quite easy to debug in the browser. You'll need the React Developer Tools.



Reading time: 5 minutes
Linked video: 30 minutes
Linked tutorial: 1 hour


First there was the DOM.
HTML is a dialect of XML. The DOM is the living, breathing, nested object structure that reflects the XML file. The browser creates it on page load. Tags in the underlying HTML become elements in the DOM. Elements have properties and events. The DOM provides a mechanism to hook event handlers to events, so that stuff happens 'onclick'. The DOM also provides mechanisms to get events dynamically using "selectors" - c.f. CSS.

Then there was Javascript. This allowed developers to make the XML dynamic. Bits of javascript could alter the DOM by performing text manipulation on tags. Obviously this is messy and painful if you want to do anything more than show loading screens or capture keypresses. The big win is that a javascript function can be supplied to element events, so that "onclick" your javascript function is called.

Then there was CSS. CSS attaches styling directives to elements based on selectors. An element might have any combination of tag type (well, it always has that), an id, and any number of class names. These can be combined into selectors. CSS is heirarchical, so you can slap elements in a div and apply stylig to the div which propagates down to all child elements. The properties you can apply with CSS correlate to styling properties you can add to elements. CSS separates your site theme from your markup and content, so that your theme is in one file. Instead of hard-coding styling in HTML, you hard-code class names and ids and let the CSS handle the styling.

Then there was jQuery. jQuery wraps elements in the DOM in jQuery objects, to make it easier to query the DOM and manipulate it. For example, on clicking "submit", you can have a javascript function invoked by the event mechanism to grey out form inputs, and jQuery gives you more flexibility in targeting what to grey out. This made it much easier to create dynamic apps. However - partly because javascript variables are all global, and partly because jQuery syntax looks like someone remapped your keyboard as a prank - it looks like puke in your code editor, and it's very difficult to structure coherently.

jQuery is written in javascript. Javascript is incredibly extensible, due to its functional nature. jQuery is almost a new language on top of plain javascript.

Then there was ajax. Ajax was initially a library, but has now become shorthand for any functionality that involves performing web queries from within a web page. The classic use case is to load data lazily as the result of a user action, so that you do not need to pull evrything out of the database on initial page load.

To make it possible to write front-end apps like real software, Google developed Angular. This really was a new language on top of javascript. However, it's looking a little obsolete now with the advent of React. The core premises of Angular are: you can inject text in your HTML, and you can add properties to HTML elements containing snippets of Angular syntax. Unfortunately this syntax is quite a lot to learn.

Angular's days were numbered when Facebook opened up React. React is now the de facto standard for front-end frameworks. In the React paradigm, markup and dynamic code are unified. A React app looks a lot like an HTML document, except that you are not limited to HTML tags - you can create or import "components", which are like elements that have been souped up with Javascript. Your entire app is written in Javascript (N.B. this is a useful lie to cover up even more history; let's just not open that box right now) but the syntax looks very much like HTML. A DateTimePicker knows how to pop up a dialogue. An ImageCarousel knows how to fetch images with ajax and animate transitions. A SortableList knows how to let the user drag-and-drop items in a container. All you need to do is feed them parameters, whcih you can manipualte with Javascript - but it is not typically heavy on Javascript.

Apps by this stage were now possible to write in a coherent way, but the CSS was becoming increasingly complex. That's why Twitter created Bootstrap. Bootstrap is a library of CSS that applies to well-known class names. So, if you have an HTML list containing list items, you can apply the "navbar" class to the list and the "nav-items" class to the list items, and you'll hook the Bootstrap CSS code to render this as a nav bar. Out of the box, your page will look professional (albeit exactly like millions of other bootstrap pages). Bootstrap supports themes, which vary the styling applied to the well-known classes.

To use React and Bootstrap together, base your components on those from the React-Bootstrap library and think no more about it.


Watch [this](https://www.youtube.com/watch?v=x7cQ3mrcKaY) for more context around the engineering decision to unify markup and functionality in React. Viewing time: 30 minutes.

Work through [this](https://reactjs.org/tutorial/tutorial.html) React tutorial. (No Javascript experience is assumed.) Estimated time: 1 hour.







 It also has bang-on error messages. The error messages teach you the syntax, almost.