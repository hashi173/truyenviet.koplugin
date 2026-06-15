import urllib.request, re
html = urllib.request.urlopen(urllib.request.Request('https://truyendich.ai/danh-sach/truyen-full', headers={'User-Agent': 'Mozilla/5.0'})).read().decode('utf-8')
match = re.search(r'(.{0,100}doc-truyen/[^\"]+\".{0,100})', html)
if match:
    with open('tag.txt', 'w', encoding='utf-8') as f:
        f.write(match.group(1))
