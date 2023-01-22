www.sacredheadheartsc.com
=========================

This repository contains the source for [www.sacredheartsc.com](https://www.sacredheartsc.com),
which consists of markdown documents and a Makefile-driven static site generator.

# Requirements

- coreutils
- python3
- pandoc
- make

# Instructions

First, install the `pip` requirements:

    make install

You'll want to edit the [Makefile](/www/tree/Makefile) to set your site URL,
RSS feed title, etc.

Then, start writing markdown documents in the `src` directory. You can use
whatever naming convention and directory structure you like. Files ending in
`.md` will be converted to `.html` with the same path.

The `src/blog` directory is special. Markdown files in this directory are
used to populate the front-page blog listing in [index.md](/www/tree/src/index.md).
Before pandoc converts this file to HTML, the special string `__BLOG_LIST__`
is replaced with the output of [bloglist.py](/www/tree/scripts/bloglist.py).
This Python script produces a date-sorted markdown list of all your blog posts.

Each markdown file can have YAML frontmatter with the following metadata:

    ---
    title: A boring blog post
    date: YYYY-MM-DD
    subtitle: an optional subtitle
    heading: optional, if you want the first <h1> to be different from <title>
    description: optional, short description for <head> and the blog listing
    draft: if set, hides the post from the blog listing
    ---

You can change the resulting HTML by modifying the [template](/www/tree/templates/default.html).
Changing the format of the blog listing requires modifying the Python script.

Build the website by using the default target:

    make

This will create a directory called `public` containing all your markdown files
rendered to HTML.

You also can run a local webserver, which listens on port 8000, using:

    make serve
