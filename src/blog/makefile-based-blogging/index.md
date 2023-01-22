---
title: Makefile-Based Blogging
date: December 12, 2022
subtitle: Yet another static site generator using `pandoc(1)` and `make(1)`.
description: Building a markdown-based static site generator using pandoc and make.
---

A few days ago, I got the gumption to start blogging again. The last time I wrote
with any frequency, I lovingly hand-crafted each HTML file before `rsync`ing it to
my web server. This time, I wanted a more efficient workflow.

I surveyed the [vast number](https://github.com/myles/awesome-static-generators)
of static site generators available on GitHub, but most of them seemed like
overkill for my humble website. I figured that by the time I wrapped by head
around one of them, I could have just written a Makefile.

Finally, I came across [pandoc-blog](https://github.com/lukasschwab/pandoc-blog),
which gave me inspiration and showed me the ideal pandoc incantations for
generating HTML from markdown files. And thus, my
[Makefile-based static site generator](https://git.sacredheartsc.com/www/about/)
was born. You're reading the inaugural post!

## Generating the HTML

The workhorse of this thing is [pandoc](https://pandoc.org), which is a ubiquitous
open-source document converter. Transforming markdown into HTML is as simple as:

```bash
pandoc document.md -o document.html
```

Simple! But to generate an entire website, we'll need some of pandoc's additional
features: custom templates and document metadata.

### Custom Templates

The layout of pandoc's output document is determined by the
[template](https://pandoc.org/MANUAL.html#templates) in use. Pandoc includes
default templates for a variety of document formats, but you can also specify
your own.

A very simple HTML template might look something like this:

```html
<html lang="en">
  <head>
    <meta name="author" content="$author-meta$">
    <meta name="description" content="$description$">
  </head>
  <body>
    <h1 class="title">$title$</h1>
$body$
  </body>
</html>
```

[My pandoc template](https://git.sacredheartsc.com/www/tree/templates/default.html)
is what generates the navigation bar at the top of this page.

The variable `$body$` is replaced by the content of your markdown document when
pandoc renders the template. The other variables are replaced by their
corresponding values from the document's metadata.

### Document Metadata

Each pandoc source document can have associated metadata values. There are three
ways of specifying metadata: the `--medatata` [flag](https://pandoc.org/MANUAL.html#option--metadata),
a dedicated [metadata file](https://pandoc.org/MANUAL.html#option--metadata-file), or
a [YAML metadata block](https://pandoc.org/MANUAL.html#extension-yaml_metadata_block)
embedded within the document itself. We'll be using the embedded metadata blocks.

Each markdown document for my website starts with a YAML metadata block. The
metadata for the post you're
[currently reading](https://git.sacredheartsc.com/www/tree/src/blog/makefile-based-blogging/index.md)
looks like this:


```yaml
---
title: Makefile-Based Blogging
date: December 12, 2022
subtitle: Yet another static site generator using `pandoc(1)` and `make(1)`.
description: Building a markdown-based static site generator using pandoc and make.
---
```

You can put whatever YAML you like in your markdown files, as long as the metadata
starts and ends with three hyphens.

## Automating pandoc with make

Using a Makefile, we can automatically invoke pandoc to convert each markdown
file in our blog to HTML. In addition, `make` will keep track of which source
files have changed since the last run and rebuild them accordingly.

First, lets describe the project layout:

- **src/**: the source files of our blog, including markdown files and static
  assets (CSS, images, etc).  The subdirectory structure is entirely up to you.

- **public/**: the output directory. After running `make`, the contents of this
  directory can be `rsync`'d straight to your web server.

- **scripts/**: helper scripts for generating the blog artifacts. Currently there
  are only two:

   - [bloglist.py](https://git.sacredheartsc.com/www/tree/scripts/bloglist.py)
     generates a markdown-formatted list of all your blog posts, sorted by the
     `date` field in the YAML metadata block.

   - [rss.py](https://git.sacredheartsc.com/www/tree/scripts/rss.py) generates
     an RSS feed for your blog.

- **templates/**: pandoc templates which generate HTML from markdown files
  (currently, there is only one).

The Makefile used to build this website is located [here](https://git.sacredheartsc.com/www/tree/Makefile).
I've reproduced a simplified version below, to make it easier to step through.

```makefile
######################
# Variable definitions
######################

# These variables are used to generate the RSS feed
URL              = https://www.sacredheartsc.com
FEED_TITLE       = sacredheartsc blog
FEED_DESCRIPTION = Carolina-grown articles about self-hosting, privacy, unix, and more.

# The number of blog posts to show on the homepage
BLOG_LIST_LIMIT = 5

# File extensions (other than .md) that should be included in public/ directory
STATIC_REGEX = .*\.(html|css|jpg|jpeg|png|xml|txt)

# Pandoc template used to generate HTML
TEMPLATE = templates/default.html

# List of subdirectories to create
SOURCE_DIRS := $(shell find src -mindepth 1 -type d)

# List of source markdown files
SOURCE_MARKDOWN := $(shell find src -type f -name '*.md' -and ! -name .bloglist.md)

# List of static assets
SOURCE_STATIC := $(shell find src               \
                     -type f                    \
                     -regextype posix-extended  \
                     -iregex '$(STATIC_REGEX)')

# List of all blog posts (excluding the main blog page)
BLOG_POSTS := $(shell find src/blog               \
                  -type f                         \
                  -name '*.md'                    \
                  -and ! -name .bloglist.md       \
                  -and ! -path src/blog/index.md)

# Subdirectories to create under public/
OUTPUT_DIRS := $(patsubst src/%, public/%, $(SOURCE_DIRS))

# .html files under public/, corresponding to each .md file under src/
OUTPUT_MARKDOWN := $(patsubst src/%, public/%, $(patsubst %.md, %.html, $(SOURCE_MARKDOWN)))

# Static file targets under public/
OUTPUT_STATIC := $(patsubst src/%, public/%, $(SOURCE_STATIC))

# Script to generate RSS feed
RSSGEN = scripts/rss.py               \
  src/blog                            \
  --title="$(FEED_TITLE)"             \
  --description="$(FEED_DESCRIPTION)" \
  --url=$(URL)                        \
  --blog-path=/blog                   \
  --feed-path=/blog/rss/feed.xml


######################
# File Targets
######################

# Default target: convert .md to .html, copy static assets, and generate RSS
public:                \
  $(OUTPUT_DIRS)       \
  $(OUTPUT_MARKDOWN)   \
  $(OUTPUT_STATIC)     \
  public/blog/feed.xml

# Homepage (/)
public/index.html: src/index.md src/.bloglist.md $(TEMPLATE)
	sed $$'/__BLOG_LIST__/{r src/.bloglist.md\nd}' $< \
	  | pandoc --template=$(TEMPLATE) --output=$@

# Markdown list of 5 most recent blog posts
src/.bloglist.md: $(BLOG_POSTS) scripts/bloglist.py
	scripts/bloglist.py src/blog $(BLOG_LIST_LIMIT) > $@

# The main blog listing (/blog/)
public/blog/index.html: src/blog/index.md src/blog/.bloglist.md $(TEMPLATE)
	sed $$'/__BLOG_LIST__/{r src/blog/.bloglist.md\nd}' $< \
	  | pandoc --template=$(TEMPLATE) --output=$@

# Markdown list of _all_ blog posts
src/blog/.bloglist.md: $(BLOG_POSTS) scripts/bloglist.py
	scripts/bloglist.py src/blog > $@

# Convert all other .md files to .html
public/%.html: src/%.md $(TEMPLATE)
	pandoc --template=$(TEMPLATE) --output=$@ $<

# Catch-all: copy static assets in src/ to public/
public/%: src/%
	cp --preserve=timestamps $< $@

# RSS feed
public/blog/feed.xml: $(BLOG_POSTS) scripts/rss.py
	$(RSSGEN) > $@


######################
# Phony Targets
######################

.PHONY: serve rsync clean

# Run a local HTTP server in the output directory
serve: public
	cd public && python3 -m http.server

# Deploy the site to your webserver
rsync: public
	rsync -rlphv --delete public/ webserver.example.com:/var/www/html

clean:
	rm -rf public
	rm -f src/.bloglist.md
	rm -f src/blog/.bloglist.md
```

## Closing Thoughts

I admit, there is a small amount of hackery involved. You obviously can't generate
a time-sorted list of blog posts using pure markdown, so I'm generating the
markdown list using a Python script in an intermediate step. I then (ab)use `sed`
to shove that list into the markdown source on the fly. This means that changing
the look of the [blog list](/blog/) requires hacking up the Python code.

But overall, I've been quite happy with this little project. There's just something
about writing paragraphs in `vi` and typing `:!make` that warms my soul with
memories of simpler times.
