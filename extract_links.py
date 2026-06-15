import re

with open('list_page.html', 'r', encoding='utf-8') as f:
    html = f.read()

links = re.findall(r'href=[\"\']([^\"\']+)[\"\']', html)
unique_links = list(set(links))
unique_links.sort()

with open('links.txt', 'w', encoding='utf-8') as f:
    for link in unique_links:
        f.write(link + '\n')
