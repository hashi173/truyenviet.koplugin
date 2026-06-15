import urllib.request
import re

url = "https://truyendich.ai"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'})
try:
    with urllib.request.urlopen(req) as response:
        html = response.read().decode('utf-8')
        print(html[:1000])
        links = re.findall(r'<a[^>]+href="([^"]+)"', html)
        for link in links[:30]:
            print(link)
except Exception as e:
    print(e)
