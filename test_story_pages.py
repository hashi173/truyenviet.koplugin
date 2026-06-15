import urllib.request
import re

url2 = 'https://truyendich.ai/doc-truyen/ngao-the-dan-than/trang-2'
req2 = urllib.request.Request(url2, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req2) as r2:
        h2 = r2.read().decode('utf-8')
        s2 = re.findall(r'href=\"(/doc-truyen/[^\"]+)\"', h2)
        print('Stories p2:', len(s2))
        print(s2[:3])
except Exception as e:
    print('trang-2 error:', e)

url3 = 'https://truyendich.ai/doc-truyen/ngao-the-dan-than?page=2'
req3 = urllib.request.Request(url3, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req3) as r3:
        h3 = r3.read().decode('utf-8')
        s3 = re.findall(r'href=\"(/doc-truyen/[^\"]+)\"', h3)
        print('Stories p3:', len(s3))
        print(s3[:3])
except Exception as e:
    print('?page=2 error:', e)
