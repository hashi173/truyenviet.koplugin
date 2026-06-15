import re
html = open('td.html', encoding='utf-8').read()
links = re.findall(r'href="([^"]+)"', html)
for link in links:
    if 'hong-mong-ba-the-quyet' in link:
        print(link)
