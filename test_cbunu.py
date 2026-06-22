import requests
s = requests.Session()
s.headers.update({'User-Agent': 'Mozilla/5.0'})
# First GET to establish PHPSESSID
r1 = s.get('https://cbunu.com/truyen-tranh/end-scoop-199-chap-78.html')
print('GET1 cookies:', s.cookies.get_dict())
# POST password
r2 = s.post('https://cbunu.com/truyen-tranh/end-scoop-199-chap-78.html', data={'access_pass': '12345'}, allow_redirects=False)
print('POST cookies:', s.cookies.get_dict())
# GET page again
r3 = s.get('https://cbunu.com/truyen-tranh/end-scoop-199-chap-78.html')
print('GET2 cookies:', s.cookies.get_dict())
print('GET2:', r3.status_code, '<title>Đăng nhập</title>' in r3.text)
