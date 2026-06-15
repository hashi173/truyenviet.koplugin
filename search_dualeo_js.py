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
    
    # Let's find all script contents
    scripts = re.findall(r'<script[^>]*>(.*?)</script>', html, re.S)
    print("Found script tags:", len(scripts))
    for i, scr in enumerate(scripts):
        if len(scr.strip()) > 50:
            print(f"\n--- Script {i+1} (len={len(scr)}) ---")
            # Print first 1000 characters of large scripts
            print(scr[:1000])
            if len(scr) > 1000:
                print("...")
                
except Exception as e:
    print("Error:", e)
