import re

with open('td.html', 'r', encoding='utf-8') as f:
    html = f.read()

links = re.findall(r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>', html)
with open('out.txt', 'w', encoding='utf-8') as out:
    for href, text in links:
        if '/chuong-' in href and 'hong-mong-ba-the-quyet' in href:
            title = re.sub(r'<[^>]+>', '', text).strip()
            out.write(f"{title} | {href}\n")
