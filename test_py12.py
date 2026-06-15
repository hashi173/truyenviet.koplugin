import re
html = open('test_anchor.txt', encoding='utf-8').read()
matches = re.findall(r'<a([^>]*)href="(/doc-truyen/[^"]+)"([^>]*)>([\s\S]*?)</a>', html)
print(f"Matches: {len(matches)}")
for match in matches:
    print(f"Href: {match[1]}")
    content = match[3]
    img = re.search(r'(<img[^>]*>)', content)
    print(f"Img: {img is not None}")
