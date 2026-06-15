import urllib.request
import re

try:
    h100 = urllib.request.urlopen('https://truyendich.ai/danh-sach/truyen-full?page=100').read().decode('utf-8')
    h101 = urllib.request.urlopen('https://truyendich.ai/danh-sach/truyen-full?page=101').read().decode('utf-8')
    s100 = set(re.findall(r'href=\"(/doc-truyen/[^\"]+)\"', h100))
    s101 = set(re.findall(r'href=\"(/doc-truyen/[^\"]+)\"', h101))
    print(len(s100), len(s101))
    print(len(s100.intersection(s101)))
except Exception as e:
    print(e)
