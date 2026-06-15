import urllib.request
import re

url7 = 'https://truyendich.ai/danh-sach/truyen-full?page=7'
url8 = 'https://truyendich.ai/danh-sach/truyen-full?page=8'

req7 = urllib.request.Request(url7, headers={'User-Agent': 'Mozilla/5.0'})
req8 = urllib.request.Request(url8, headers={'User-Agent': 'Mozilla/5.0'})

try:
    h7 = urllib.request.urlopen(req7).read().decode('utf-8')
    h8 = urllib.request.urlopen(req8).read().decode('utf-8')
    
    def get_stories(html):
        return set(re.findall(r'href=\"(/doc-truyen/[^\"]+)\"', html))
    s7 = get_stories(h7)
    s8 = get_stories(h8)
    
    print('p7 count:', len(s7))
    print('p8 count:', len(s8))
    print('Intersection:', len(s7.intersection(s8)))
except Exception as e:
    print('Error:', e)
