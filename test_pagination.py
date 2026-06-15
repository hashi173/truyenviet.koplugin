import urllib.request
import re

url1 = 'https://truyendich.ai/danh-sach/truyen-full?page=1'
url2 = 'https://truyendich.ai/danh-sach/truyen-full?page=2'

req1 = urllib.request.Request(url1, headers={'User-Agent': 'Mozilla/5.0'})
req2 = urllib.request.Request(url2, headers={'User-Agent': 'Mozilla/5.0'})

try:
    with urllib.request.urlopen(req1) as r1, urllib.request.urlopen(req2) as r2:
        h1 = r1.read().decode('utf-8')
        h2 = r2.read().decode('utf-8')
        print(len(h1), len(h2))
        
        # Check if they have the same stories
        def get_stories(html):
            return re.findall(r'href=\"(/doc-truyen/[^\"]+)\"', html)
        s1 = get_stories(h1)
        s2 = get_stories(h2)
        print('Stories p1:', len(s1))
        print('Stories p2:', len(s2))
        print('Same first story?', s1[0] == s2[0] if s1 and s2 else 'No')
except Exception as e:
    print(e)
