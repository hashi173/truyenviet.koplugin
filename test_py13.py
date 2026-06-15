import urllib.request, re

def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})).read().decode('utf-8')

p1 = fetch('https://truyendich.ai/doc-truyen/hong-mong-ba-the-quyet?page=1')
p2 = fetch('https://truyendich.ai/doc-truyen/hong-mong-ba-the-quyet?page=2')

print(f"p1 == p2: {p1 == p2}")

chaps1 = re.findall(r'href="/doc-truyen/hong-mong-ba-the-quyet/(chuong-[^"]+)"', p1)
chaps2 = re.findall(r'href="/doc-truyen/hong-mong-ba-the-quyet/(chuong-[^"]+)"', p2)

print(f"Page 1 chapters: {len(chaps1)}")
if chaps1: print(f"  First: {chaps1[0]}, Last: {chaps1[-1]}")
print(f"Page 2 chapters: {len(chaps2)}")
if chaps2: print(f"  First: {chaps2[0]}, Last: {chaps2[-1]}")
