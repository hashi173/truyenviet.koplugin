import re
import urllib.request

url = 'https://truyendich.ai/danh-sach/truyen-full'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        html = response.read().decode('utf-8')
        
        match = re.search(r'"totalPages":(\d+)', html)
        if match:
            print("Total Pages:", match.group(1))
            
        match = re.search(r'"total":(\d+)', html)
        if match:
            print("Total Items:", match.group(1))
            
        match = re.search(r'totalPages', html)
        if match:
            print("Found totalPages somewhere")
        
        # look for any hrefs with /trang-
        pages = re.findall(r'href="([^"]+trang-[^"]+)"', html)
        if pages:
            print(pages[:5])
        
        # look for any hrefs with ?page=
        pages2 = re.findall(r'href="([^"]+\?page=[^"]+)"', html)
        if pages2:
            print(pages2[:5])
            
except Exception as e:
    print(e)
