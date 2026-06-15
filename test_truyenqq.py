import urllib.request
import re

url = "https://truyenqqko.com/truyen-tranh/dai-quan-gia-la-ma-hoang-6650"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    html = urllib.request.urlopen(req).read().decode('utf-8')
    chapters = re.findall(r'<div class="works-chapter-item">.*?<a[^>]*>(.*?)</a>', html, re.S)
    print("Total chapters found:", len(chapters))
    for i in range(5):
        if i < len(chapters):
            print("Top", i, ":", chapters[i].strip())
    print("...")
    for i in range(len(chapters)-5, len(chapters)):
        if i >= 0:
            print("Bottom", i, ":", chapters[i].strip())
except Exception as e:
    print(e)
