import re

with open('haccbl_story.html', 'r', encoding='utf-8') as f:
    html = f.read()

chapters = []

# Logic from haccbl.lua
list_html_m = re.search(r'<div[^>]*id="chapter-list"[^>]*>([\s\S]*?)</div>\s*<div', html)
if list_html_m:
    list_html = list_html_m.group(1)
    print(f"Found list_html length: {len(list_html)}")
    
    # 1. init-manga style
    items = re.findall(r'<div[^>]*class="[^"]*chapter-item[^"]*"[^>]*>([\s\S]*?)</div>', list_html)
    print(f"Found init-manga items: {len(items)}")
    for item in items:
        href_m = re.search(r'href="([^"]+)"', item)
        title_m = re.search(r'<span[^>]*class="[^"]*chapter-name[^"]*"[^>]*>([\s\S]*?)</span>', item)
        title_m2 = re.search(r'<h3[^>]*>([\s\S]*?)</h3>', item)
        
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

print(f"Total chapters: {len(chapters)}")
print(chapters[-5:])
