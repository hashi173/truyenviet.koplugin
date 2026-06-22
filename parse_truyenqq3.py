import re

with open('truyenqq_multi.html', 'r', encoding='utf-8') as f:
    html = f.read()

story_url = "https://truyenqqko.com/truyen-tranh/one-piece-128"
slug = story_url.split("/")[-1]

# Simulate the Lua base_slug extraction
import re as re2
m = re2.match(r'^(.*?)-\d+\.html$', slug) or re2.match(r'^(.*?)-\d+$', slug) or re2.match(r'^(.*?)\.html$', slug)
base_slug = m.group(1) if m else slug
print(f"slug: {slug}")
print(f"base_slug: {base_slug}")

# Find the chapter list container
list_match = re.search(r'class="works-chapter-list"', html)
if list_match:
    start = list_match.start()
    while start > 0 and html[start] != '<':
        start -= 1
    # Find closing </div> of works-chapter-list
    # Extract chapter items
    items = re.findall(r'class="works-chapter-item"(.*?)</div>\s*</div>', html[start:], re.DOTALL)
    print(f"\nworks-chapter-item count: {len(items)}")
    
# Find ALL links containing base_slug
all_chap_links = re.findall(r'href="([^"]*' + re.escape(base_slug) + r'[^"]*chap[^"]*)"', html, re.IGNORECASE)
print(f"\nLinks containing '{base_slug}' AND 'chap': {len(all_chap_links)}")
for link in all_chap_links[:5]:
    print(f"  {link}")
if len(all_chap_links) > 5:
    print(f"  ... and {len(all_chap_links) - 5} more")
    for link in all_chap_links[-3:]:
        print(f"  {link}")

# Now simulate the CURRENT Lua parseStoryPage logic
print(f"\n=== Simulating Lua parseStoryPage ===")

# Step 1: Find list container
list_start_pos = None
for cls in ['works-chapter-list', 'list_chapter', 'list-chapters']:
    pos = html.find(f'class="{cls}"')
    if pos >= 0:
        list_start_pos = pos
        print(f"Found container: {cls} at pos {pos}")
        break

if list_start_pos:
    # Walk back to opening tag
    open_pos = list_start_pos
    while open_pos > 0 and html[open_pos] != '<':
        open_pos -= 1
    
    # Find first </ul> or </div> after list_start_pos
    ul_close = html.find("</ul>", list_start_pos)
    div_close = html.find("</div>", list_start_pos)
    
    close_pos = None
    if ul_close >= 0 and div_close >= 0:
        close_pos = min(ul_close, div_close)
    else:
        close_pos = ul_close if ul_close >= 0 else div_close
    
    if close_pos:
        list_html = html[open_pos:close_pos+6]
    else:
        list_html = html[open_pos:]
    
    print(f"list_html length: {len(list_html)}")
    
    # Count links in narrowed HTML
    links_in_list = re.findall(r'<a([^>]*)>(.*?)</a>', list_html, re.DOTALL)
    print(f"Links in narrowed list_html: {len(links_in_list)}")
    
    # Count links that match base_slug
    matching = []
    for attrs, text in links_in_list:
        href_match = re.search(r'href="([^"]+)"', attrs)
        if href_match:
            href = href_match.group(1)
            if base_slug in href:
                clean = re.sub(r'<[^>]+>', '', text).strip()
                matching.append((href, clean))
    
    print(f"Links matching base_slug in narrowed HTML: {len(matching)}")
    for href, text in matching[:3]:
        print(f"  {href} -> {text}")
    
    # THE BUG: narrowing to first </div> is too aggressive!
    # Let's check: how much of the HTML is between the container start and first </div>
    print(f"\n=== DIAGNOSIS ===")
    print(f"Container starts at: {open_pos}")
    print(f"First </div> is at: {div_close}")
    print(f"First </ul> is at: {ul_close}")
    print(f"Narrowed region is only {close_pos - open_pos} chars")
    print(f"Total HTML is {len(html)} chars")
    
    # Now count in the FULL section until the end of the works-chapter-list div
    # The real end should be after all works-chapter-items
    all_items = list(re.finditer(r'class="works-chapter-item"', html))
    if all_items:
        last_item_pos = all_items[-1].end()
        print(f"\nLast works-chapter-item at: {last_item_pos}")
        print(f"  That's {last_item_pos - open_pos} chars from container start")
        
        # Get the full section
        full_section = html[open_pos:last_item_pos + 500]
        full_links = re.findall(r'href="([^"]*' + re.escape(base_slug) + r'[^"]*)"', full_section)
        print(f"Links in FULL section: {len(full_links)}")
