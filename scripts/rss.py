#!/usr/bin/env python3

import argparse
import email.utils
from datetime import datetime
from common import get_blog_posts

parser = argparse.ArgumentParser('rss')
parser.add_argument('BLOG_DIR', type=str, help='Directory containing markdown blog posts')
parser.add_argument('--limit', default=15, type=int, help='Maximum number of posts to show')
parser.add_argument('--title', help='Feed title', required=True)
parser.add_argument('--description', help='Feed description', required=True)
parser.add_argument('--url', help='Root URL', required=True)
parser.add_argument('--blog-path', help='Blog path', required=True)
parser.add_argument('--feed-path', help='RSS feed path', required=True)
args = parser.parse_args()

posts = get_blog_posts(args.BLOG_DIR)
posts = posts[0:args.limit]

build_date = email.utils.format_datetime(datetime.now().astimezone())

print(f'''<?xml version="1.0"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
  <title>{args.title}</title>
  <link>{args.url}{args.blog_path}</link>
  <language>en-US</language>
  <description>{args.description}</description>
  <lastBuildDate>{build_date}</lastBuildDate>
  <atom:link href="{args.url}{args.feed_path}" rel="self" type="application/rss+xml"/>''')

for post in posts:
    pub_date = email.utils.format_datetime(post['date'].astimezone())

    print(f'''  <item>
    <title>{post["title"]}</title>
    <link>{args.url}{post["href"]}</link>
    <guid>{args.url}{post["href"]}</guid>
    <pubDate>{pub_date}</pubDate>''')

    if 'description' in post:
        print(f'    <description>{post["description"]}</description>')

    print('  </item>')

print('</channel>')
print('</rss>')
