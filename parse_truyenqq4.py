import re

with open('truyenqq_multi.html', 'r', encoding='utf-8') as f:
    html = f.read()

story_url = "https://truyenqqko.com/truyen-tranh/one-piece-128"
slug = story_url.split("/")[-1]
m = re.match(r'^(.*?)-\d+\.html$', slug) or re.match(r'^(.*?)-\d+$', slug) or re.match(r'^(.*?)\.html$', slug)
base_slug = m.group(1) if m else slug

print(f"base_slug: {base_slug}")

# Simulate the NEW Lua logic: match works-chapter-item divs
# Pattern: <div class="works-chapter-item">...</div>\s*</div>
# This matches each item which has 2 inner divs (name-chap and time-chap), each closed with </div>
# The pattern captures content between the opening <div> and the second </div>

items = re.findall(
    r'<div[^>]*class="[^"]*works-chapter-item[^"]*"[^>]*>([\s\S]*?)</div>\s*</div>',
    html
)
print(f"works-chapter-item matches: {len(items)}")

chapters = []
for item_html in items:
    links = re.findall(r'<a([^>]*)>([\s\S]*?)</a>', item_html)
    for attrs, text in links:
        href_m = re.search(r'href="([^"]+)"', attrs)
        if href_m:
            href = href_m.group(1)
            if base_slug in href:
                lower_url = href.lower()
                if '-chap-' in lower_url or 'chapter' in lower_url or 'chuong' in lower_url:
                    clean_text = re.sub(r'<[^>]+>', '', text).strip()
                    chapters.append((href, clean_text))

print(f"Chapters found: {len(chapters)}")
if chapters:
    print(f"First 3: {chapters[:3]}")
    print(f"Last 3: {chapters[-3:]}")
