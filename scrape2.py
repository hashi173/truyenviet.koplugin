import urllib.request
import re

url = 'https://truyendich.ai/danh-sach/truyen-full'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        html = response.read().decode('utf-8')
        
        matches = re.findall(r'page=(\d+)|trang-(\d+)', html)
        nums = []
        for m in matches:
            if m[0]: nums.append(int(m[0]))
            if m[1]: nums.append(int(m[1]))
        if nums:
            print('Max page found via page= or trang-:', max(nums))
        else:
            print('No page/trang links found')
            
        # check buttons or page counts like ">7<"
        print("Buttons:", re.findall(r'<button[^>]*>(\d+)</button>', html))
        print("Last pagination button text:", re.findall(r'<button[^>]*>[^<]*</button>', html)[-5:])
except Exception as e:
    print(e)
