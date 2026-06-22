import re

html = open('haccbl_home.html', encoding='utf-8').read()
links = re.findall(r'href="(https://haccbl\.xyz/[^"]+)"[^>]*>([^<]+)</a>', html)
seen = set()
for h, t in links:
    if h not in seen and '/manga/' not in h and '/truyen-tranh/' not in h:
        print(f"{h} -> {t.strip()}")
        seen.add(h)
