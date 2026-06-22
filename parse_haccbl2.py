import re

with open('haccbl_home.html', 'r', encoding='utf-8') as f:
    html = f.read()

print("HACCBL Homepage Links")
links = set(re.findall(r'href="(https://haccbl\.xyz/[^"]+)"', html))
manga_links = [l for l in links if '/truyen-tranh/' in l or '/manga/' in l or '/truyen/' in l]
print(f"Manga links found: {len(manga_links)}")
for l in list(manga_links)[:10]:
    print(f"  {l}")

if not manga_links:
    print("Top 20 links generally:")
    for l in list(links)[:20]:
        print(f"  {l}")
