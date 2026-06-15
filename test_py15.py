import urllib.request, re

def fetch_rsc(url):
    req = urllib.request.Request(url, headers={
        'User-Agent': 'Mozilla/5.0',
        'RSC': '1',
        'Next-Router-State-Tree': '%5B%22%22%2C%7B%22children%22%3A%5B%22doc-truyen%22%2C%7B%22children%22%3A%5B%5B%22slug%22%2C%5B%22hong-mong-ba-the-quyet%22%5D%2C%22d%22%5D%2C%7B%22children%22%3A%5B%22__PAGE__%22%2C%7B%7D%5D%7D%5D%7D%5D%7D%5D'
    })
    try:
        return urllib.request.urlopen(req).read().decode('utf-8')
    except Exception as e:
        return str(e)

res = fetch_rsc('https://truyendich.ai/doc-truyen/hong-mong-ba-the-quyet?page=2')
print(res[:500])
with open('rsc.txt', 'w', encoding='utf-8') as f:
    f.write(res)
