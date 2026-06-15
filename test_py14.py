import re
html = open('td.html', encoding='utf-8').read()
match = re.search(r'(.{0,100}Trang sau.{0,100})', html)
if match:
    print(match.group(1))
