import re
import sys

with open('truyenqq_info.html', 'r', encoding='utf-8') as f:
    html = f.read()

# Extract works-chapter-list section
match = re.search(r'class="works-chapter-list"', html)
if match:
    start = match.start()
    # Walk back to find the opening tag
    while start > 0 and html[start] != '<':
        start -= 1
    # Find the next closing div/ul after the section
    # Take 5000 chars from start
    chunk = html[start:start+5000]
    # Clean up for display
    print("=== works-chapter-list section (first 5000 chars) ===")
    print(chunk[:5000])

# Also try the list_chapter
match2 = re.search(r'class="list_chapter"', html)
if match2:
    start2 = match2.start()
    while start2 > 0 and html[start2] != '<':
        start2 -= 1
    chunk2 = html[start2:start2+3000]
    print("\n\n=== list_chapter section (first 3000 chars) ===")
    print(chunk2[:3000])

# Find ALL chapter links (works-chapter-item)
items = re.findall(r'class="works-chapter-item"[^>]*>(.*?)</(?:div|li)', html, re.DOTALL)
print(f"\n=== works-chapter-item count: {len(items)} ===")
for i, item in enumerate(items[:10]):
    # find hrefs
    hrefs = re.findall(r'href="([^"]+)"', item)
    texts = re.sub(r'<[^>]+>', ' ', item).strip()
    print(f"  Item {i}: hrefs={hrefs}, text={texts[:100]}")
