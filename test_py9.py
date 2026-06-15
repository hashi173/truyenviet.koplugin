import urllib.request, re
html = urllib.request.urlopen(urllib.request.Request('https://truyendich.ai/danh-sach/truyen-full', headers={'User-Agent': 'Mozilla/5.0'})).read().decode('utf-8')
links = re.findall(r'href="([^"]+)"', html)
with open('test_list.txt', 'w', encoding='utf-8') as f:
    for link in links:
        if 'doc-truyen' in link:
            f.write(link + '\n')
