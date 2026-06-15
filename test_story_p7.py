import urllib.request
import re

url7 = 'https://truyendich.ai/doc-truyen/ngao-the-dan-than/trang-7'
url8 = 'https://truyendich.ai/doc-truyen/ngao-the-dan-than/trang-8'

req7 = urllib.request.Request(url7, headers={'User-Agent': 'Mozilla/5.0'})
req8 = urllib.request.Request(url8, headers={'User-Agent': 'Mozilla/5.0'})

try:
    h7 = urllib.request.urlopen(req7).read().decode('utf-8')
    h8 = urllib.request.urlopen(req8).read().decode('utf-8')
    
    def get_chapters(html):
        return set(re.findall(r'href=\"(/doc-truyen/[^\"]+/chuong-\d+)\"', html))
    
    s7 = get_chapters(h7)
    s8 = get_chapters(h8)
    
    print('p7 count:', len(s7))
    print('p8 count:', len(s8))
    print('Intersection:', len(s7.intersection(s8)))
except Exception as e:
    print('Error:', e)
