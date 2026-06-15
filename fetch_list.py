import urllib.request

url = 'https://truyendich.ai/danh-sach/truyen-full'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        html = response.read().decode('utf-8')
        with open('list_page.html', 'w', encoding='utf-8') as f:
            f.write(html)
        print("Written to list_page.html")
except Exception as e:
    print("Error:", e)
