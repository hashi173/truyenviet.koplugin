import re

with open('haccbl_page2.html', 'r', encoding='utf-8') as f:
    html = f.read()

chapters = []

for item_html in re.findall(r'<div[^>]*class="[^"]*chapter-item[^"]*"[^>]*>([\s\S]*?)</div>', html):
    href_m = re.search(r'href="([^"]+)"', item_html)
    title_m = re.search(r'<span[^>]*class="[^"]*chapter-name[^"]*"[^>]*>([\s\S]*?)</span>', item_html)
    title_m2 = re.search(r'<h3[^>]*>([\s\S]*?)</h3>', item_html)
    
    href = href_m.group(1) if href_m else None
    
    title = "Chapter"
    if title_m: title = title_m.group(1)
    elif title_m2: title = title_m2.group(1)
    elif href and 'chapter-' in href:
        chap_m = re.search(r'chapter-([\d.]+)', href)
        if chap_m: title = "Chapter " + chap_m.group(1)
        
    if href and ('chapter' in href or 'chuong' in href):
        clean_title = re.sub(r'<[^>]+>', '', title).strip()
        chapters.append((href, clean_title))

if not chapters:
    for anchor_html, href in re.findall(r'<a([^>]*)>([\s\S]*?)</a>', html):
        href_m = re.search(r'href="([^"]+)"', anchor_html)
        href = href_m.group(1) if href_m else None
        if href and ('/chapter' in href or '/chuong' in href) and '#' not in href:
            title_m = re.search(r'<h3[^>]*>([\s\S]*?)</h3>', href)
            title = title_m.group(1) if title_m else anchor_html
            clean_title = re.sub(r'<[^>]+>', '', title).strip()
            chapters.append((href, clean_title))

print(f"Total chapters: {len(chapters)}")
if chapters:
    print(chapters[:5])
    print(chapters[-5:])
