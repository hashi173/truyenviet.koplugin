import urllib.request
import re

req = urllib.request.Request('https://truyenqqko.com/truyen-tranh/nhan-mon-bat-tri-dao-17303', headers={'User-Agent': 'Mozilla/5.0'})
resp = urllib.request.urlopen(req).read().decode('utf-8')

with open('test_qq_output.txt', 'w', encoding='utf-8') as f:
    for match in re.finditer(r'<a[^>]*>(.*?)</a>', resp):
        if 'chap-' in match.group(0):
            f.write(match.group(0) + '\n')
