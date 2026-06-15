import urllib.request, re

def fetch(url):
    try:
        return urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})).read().decode('utf-8')
    except Exception as e:
        return str(e)

p2 = fetch('https://truyendich.ai/doc-truyen/hong-mong-ba-the-quyet/trang-2')
print(p2[:200])
chaps2 = re.findall(r'href="/doc-truyen/hong-mong-ba-the-quyet/(chuong-[^"]+)"', p2)

print(f"Page 2 chapters: {len(chaps2)}")
if chaps2: print(f"  First: {chaps2[0]}, Last: {chaps2[-1]}")
