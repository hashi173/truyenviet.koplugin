import urllib.request
import re

url = "https://truyendich.ai/doc-truyen/hong-mong-ba-the-quyet"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        html = response.read().decode('utf-8')
        links = re.findall(r'<a[^>]+href="([^"]+)"', html)
        chaps = [l for l in links if '/chuong-' in l]
        print(f"Found {len(chaps)} chapters.")
        for l in chaps[:10]:
            print(l)
except Exception as e:
    print(e)
