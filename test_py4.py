import re
html = open('td.html', encoding='utf-8').read()
match = re.search(r'(.{0,200}chuong-1".{0,200})', html)
if match:
    print(match.group(1))
