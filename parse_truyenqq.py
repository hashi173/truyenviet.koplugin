import re
import sys

with open('truyenqq_info.html', 'r', encoding='utf-8') as f:
    html = f.read()

# Find all links that contain "chap" in href
chap_links = re.findall(r'<a[^>]*href="([^"]*chap[^"]*)"[^>]*>(.*?)</a>', html, re.IGNORECASE | re.DOTALL)
print(f"=== Links with 'chap' in href: {len(chap_links)} ===")
for href, text in chap_links[:20]:
    clean_text = re.sub(r'<[^>]+>', '', text).strip()
    print(f"  href={href}")
    print(f"  text={clean_text[:80]}")
    print()

# Find section with "works-chapter" or "list_chapter" or "list-chapter"
for cls_name in ['works-chapter', 'list_chapter', 'list-chapter', 'list-chapter-d', 'list-chapters']:
    if cls_name in html:
        print(f"=== Found class: {cls_name} ===")

# Find section with chapter listing div/ul patterns
for pattern in [r'class="[^"]*chapter[^"]*"', r'class="[^"]*chap[^"]*"', r'id="[^"]*chapter[^"]*"']:
    matches = re.findall(pattern, html, re.IGNORECASE)
    if matches:
        print(f"=== Pattern '{pattern}' matches: ===")
        for m in set(matches):
            print(f"  {m}")

# Find the slug pattern
print(f"\n=== URL slug analysis ===")
# What does the story URL look like?
story_url = "https://truyenqqko.com/truyen-tranh/cuu-tinh-ba-the-24098"
slug = story_url.split("/")[-1]
print(f"slug: {slug}")
base_slug_m = re.match(r'^(.*?)-\d+$', slug) or re.match(r'^(.*?)-\d+\.html$', slug) or re.match(r'^(.*?)\.html$', slug)
base_slug = base_slug_m.group(1) if base_slug_m else slug
print(f"base_slug: {base_slug}")

# Find ALL links containing the base_slug
slug_links = re.findall(r'<a[^>]*href="([^"]*' + re.escape(base_slug) + r'[^"]*)"[^>]*>(.*?)</a>', html, re.IGNORECASE | re.DOTALL)
print(f"\n=== Links containing base_slug '{base_slug}': {len(slug_links)} ===")
for href, text in slug_links[:30]:
    clean_text = re.sub(r'<[^>]+>', '', text).strip()
    print(f"  href={href}")
    print(f"  text={clean_text[:80]}")
    print()

# Check for "list_chapter" presence
print(f"\n=== Searching for chapter list container ===")
for keyword in ['list_chapter', 'works-chapter-list', 'list-chapters', 'works-chapter', 'listchapter', 'chapter-list']:
    count = html.lower().count(keyword.lower())
    print(f"  '{keyword}': {count} occurrences")
