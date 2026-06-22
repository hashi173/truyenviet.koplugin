import re

with open('haccbl_story.html', 'r', encoding='utf-8') as f:
    html = f.read()

print("HACCBL HTML analysis")
# Find cover
cover_m = re.search(r'<meta property="og:image" content="([^"]+)"', html)
if cover_m:
    print(f"Cover URL: {cover_m.group(1)}")
else:
    print("Cover URL not found in meta tag")

# Find chapter list structure
for keyword in ['chapter-list', 'list-chapter', 'chapter-item']:
    print(f"Found {keyword}: {html.lower().count(keyword)}")

# Dump first few chapters links
links = re.findall(r'<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>', html, re.IGNORECASE | re.DOTALL)
chap_links = [(h, re.sub(r'<[^>]+>', '', t).strip()) for h, t in links if 'chapter' in h.lower() or 'chuong' in h.lower()]
print(f"Total chapter links found globally: {len(chap_links)}")
for i, (h, t) in enumerate(chap_links[:5]):
    print(f"  {i}: {h} -> {t[:50]}")

# Look for works-chapter-list or similar containers
print("Look for ID chapter-list:")
list_start = html.find('id="chapter-list"')
if list_start > -1:
    print(html[list_start-20:list_start+500])
