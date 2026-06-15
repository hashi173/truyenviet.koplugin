import re
html = open('td.html', encoding='utf-8').read()
for s in re.findall(r'<script.*?>.*?</script>', html, re.DOTALL):
    print(s[:200])
