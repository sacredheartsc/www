### CHANGE ME ######################
DOMAIN           = www.sacredheartsc.com
URL              = https://$(DOMAIN)
RSYNC_TARGET     = $(DOMAIN):/var/www/$(DOMAIN)
FEED_TITLE       = sacredheartsc blog
FEED_DESCRIPTION = Carolina-grown articles about self-hosting, privacy, unix, and more.
STATIC_REGEX     = .*\.(html|css|jpg|jpeg|png|ico|xml|txt|asc)
BLOG_LIST_LIMIT  = 5


### VARIABLES ######################
SHELL = /bin/bash -e -o pipefail

SOURCE_DIR  = src
OUTPUT_DIR  = public
SCRIPT_DIR  = scripts

BLOG_DIR = blog

TEMPLATE = templates/default.html
DEFAULTS = defaults.yaml

BLOG_LIST_SCRIPT  = $(SCRIPT_DIR)/bloglist.py
BLOG_LIST_REPLACE = __BLOG_LIST__
BLOG_LIST_FILE    = .bloglist.md

BLOG_RSS_SCRIPT = $(SCRIPT_DIR)/rss.py
BLOG_RSS_FILE   = $(BLOG_DIR)/feed.xml

SOURCE_DIRS     := $(shell find $(SOURCE_DIR) -mindepth 1 -type d)
SOURCE_MARKDOWN := $(shell find $(SOURCE_DIR) -type f -name '*.md' -and ! -name $(BLOG_LIST_FILE))
SOURCE_STATIC   := $(shell find $(SOURCE_DIR) -type f -regextype posix-extended -iregex '$(STATIC_REGEX)')
BLOG_POSTS      := $(shell find $(SOURCE_DIR)/$(BLOG_DIR) -type f -name '*.md' -and ! -name $(BLOG_LIST_FILE) -and ! -path $(SOURCE_DIR)/$(BLOG_DIR)/index.md)

OUTPUT_DIRS     := $(patsubst $(SOURCE_DIR)/%, $(OUTPUT_DIR)/%, $(SOURCE_DIRS))
OUTPUT_MARKDOWN := $(patsubst $(SOURCE_DIR)/%, $(OUTPUT_DIR)/%, $(patsubst %.md, %.html, $(SOURCE_MARKDOWN)))
OUTPUT_STATIC   := $(patsubst $(SOURCE_DIR)/%, $(OUTPUT_DIR)/%, $(SOURCE_STATIC))

COPY = cp --preserve=timestamps

PANDOC = pandoc                     \
  --highlight-style=kate            \
  --metadata=feed:/$(BLOG_RSS_FILE) \
  --defaults=$(DEFAULTS)

RSSGEN = $(BLOG_RSS_SCRIPT)           \
  $(SOURCE_DIR)/$(BLOG_DIR)           \
  --title="$(FEED_TITLE)"             \
  --description="$(FEED_DESCRIPTION)" \
  --url="$(URL)"                      \
  --blog-path="/$(BLOG_DIR)"          \
  --feed-path="/$(BLOG_RSS_FILE)"


### TARGETS ######################
public:                          \
  $(OUTPUT_DIRS)                 \
  $(OUTPUT_MARKDOWN)             \
  $(OUTPUT_STATIC)               \
  $(OUTPUT_DIR)/$(BLOG_RSS_FILE)

$(OUTPUT_DIRS):
	mkdir -p $@

# Homepage
$(OUTPUT_DIR)/index.html: $(SOURCE_DIR)/index.md $(SOURCE_DIR)/$(BLOG_LIST_FILE) $(TEMPLATE)
	sed $$'/$(BLOG_LIST_REPLACE)/{r $(SOURCE_DIR)/$(BLOG_LIST_FILE)\nd}' $< | $(PANDOC) --template=$(TEMPLATE) --output=$@

# CV
$(OUTPUT_DIR)/cv/index.html: $(SOURCE_DIR)/cv/index.md templates/cv.html
	$(PANDOC) --template=templates/cv.html --output=$@ $<

$(SOURCE_DIR)/$(BLOG_LIST_FILE): $(BLOG_POSTS) $(BLOG_LIST_SCRIPT)
	$(BLOG_LIST_SCRIPT) $(SOURCE_DIR)/$(BLOG_DIR) $(BLOG_LIST_LIMIT) > $@

# Blog listing
$(OUTPUT_DIR)/$(BLOG_DIR)/index.html: $(SOURCE_DIR)/$(BLOG_DIR)/index.md $(SOURCE_DIR)/$(BLOG_DIR)/$(BLOG_LIST_FILE) $(TEMPLATE)
	sed $$'/$(BLOG_LIST_REPLACE)/{r $(SOURCE_DIR)/$(BLOG_DIR)/$(BLOG_LIST_FILE)\nd}' $< | $(PANDOC) --template=$(TEMPLATE) --output=$@

$(SOURCE_DIR)/$(BLOG_DIR)/$(BLOG_LIST_FILE): $(BLOG_POSTS) $(BLOG_LIST_SCRIPT)
	$(BLOG_LIST_SCRIPT) $(SOURCE_DIR)/$(BLOG_DIR) > $@

# RSS feed
$(OUTPUT_DIR)/$(BLOG_RSS_FILE): $(BLOG_POSTS) $(BLOG_RSS_SCRIPT)
	$(RSSGEN) > $@

# Blog posts
$(OUTPUT_DIR)/%.html: $(SOURCE_DIR)/%.md $(TEMPLATE)
	$(PANDOC) --template=$(TEMPLATE) --output=$@ $<

# Catch-all: static assets
$(OUTPUT_DIR)/%: $(SOURCE_DIR)/%
	$(COPY) $< $@

.PHONY: install clean serve rsync
install:
	pip install -r requirements.txt

serve: public
	cd $(OUTPUT_DIR) && python3 -m http.server

clean:
	rm -rf $(OUTPUT_DIR)
	rm -f $(SOURCE_DIR)/$(BLOG_LIST_FILE)
	rm -f $(SOURCE_DIR)/$(BLOG_DIR)/$(BLOG_LIST_FILE)

rsync: public
	rsync -rlphv --delete $(OUTPUT_DIR)/ $(RSYNC_TARGET)
