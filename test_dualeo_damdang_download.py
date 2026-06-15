import urllib.request
import re
import time

url = "https://dualeotruyenbs.com/truyen-tranh/cuoc-xam-luoc-dam-dang/chapter-0-1"
req = urllib.request.Request(url, headers={
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept-Language': 'vi-VN,vi;q=0.9,en;q=0.7',
})
try:
    with urllib.request.urlopen(req) as r:
        html = r.read().decode('utf-8', errors='ignore')
    
    start_at = html.find('class="content_view_chap"')
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
    
    headers = {
        'Referer': 'https://dualeotruyenbs.com/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    }
    
    success = 0
    failed = 0
    for i, img in enumerate(images):
        img_req = urllib.request.Request(img, headers=headers)
        try:
            start_time = time.time()
            with urllib.request.urlopen(img_req, timeout=5) as resp:
                data = resp.read()
                success += 1
        except Exception as e:
            failed += 1
            print(f"Image {i+1} failed: {e}")
            
    print(f"Download results: Success={success}, Failed={failed}")
    
except Exception as e:
    print("Error:", e)
