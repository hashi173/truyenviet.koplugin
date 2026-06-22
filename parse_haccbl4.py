import re

html = open('haccbl_story.html', encoding='utf-8').read()

print(f"Total length of HTML: {len(html)}")

# Find everything inside the chapter-list container, or just find all a tags that contain "chapter-"
all_anchors = re.findall(r'<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>', html)
chap_links = []
for h, t in all_anchors:
    if 'chapter-' in h or 'chuong-' in h:
        chap_links.append((h, re.sub(r'<[^>]+>', '', t).strip()))

print(f"Chapter links globally found: {len(chap_links)}")
for i, (h, t) in enumerate(chap_links):
    print(f"{i}: {h} -> {t[:50]}")
    if i > 10:
        print("...")
        break

# Haccbl loads chapters using AJAX in a script tag?
scripts = re.findall(r'<script[^>]*>([\s\S]*?)</script>', html)
for i, s in enumerate(scripts):
    if 'chapter' in s or 'ajax' in s:
        print(f"\n--- Script {i} containing chapter/ajax ---")
        print(s[:500])
