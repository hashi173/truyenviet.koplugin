import urllib.request, re
html = urllib.request.urlopen(urllib.request.Request('https://truyendich.ai/tim-kiem?keyword=pham', headers={'User-Agent': 'Mozilla/5.0'})).read().decode('utf-8')
match = re.search(r'(.{0,300}doc-truyen/[^\"]+\".{0,300})', html)
if match:
    with open('test_search.html', 'w', encoding='utf-8') as f:
        f.write(match.group(1))
