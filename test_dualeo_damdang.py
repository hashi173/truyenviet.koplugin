import urllib.request
import re

url = "https://dualeotruyenbs.com/truyen-tranh/cuoc-xam-luoc-dam-dang/chapter-0-1"
req = urllib.request.Request(url, headers={
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept-Language': 'vi-VN,vi;q=0.9,en;q=0.7',
})
try:
    with urllib.request.urlopen(req) as r:
        html = r.read().decode('utf-8', errors='ignore')
    
    print("HTML length:", len(html))
    
    start_at = html.find('class="content_view_chap"')
    if start_at == -1:
        print("content_view_chap not found")
        exit()
        
    content = html[start_at:]
    images = []
    for img_tag in re.findall(r'<img[^>]*>', content):
        src_m = re.search(r'data-img="([^"]+)"', img_tag) or re.search(r'data-src="([^"]+)"', img_tag) or re.search(r'src="([^"]+)"', img_tag)
        if src_m:
            src = src_m.group(1)
            if not src.startswith("data:"):
                if not src.startswith("http"):
                    src = "https://dualeotruyenbs.com" + src
                images.append(src)
                
    seen = set()
    images = [x for x in images if not (x in seen or seen.add(x))]
    
    print("Total images:", len(images))
    for i in range(min(12, len(images))):
        print(f"  Image {i+1}: {images[i]}")
        
except Exception as e:
    print("Error:", e)
