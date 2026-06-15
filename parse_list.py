import re
import json

with open('list_page.html', 'r', encoding='utf-8') as f:
    html = f.read()

# Instead of relying on Next.js json which might be obfuscated,
# let's look for standard pagination patterns like:
# /danh-sach/truyen-full?page=2
# or any /danh-sach/[something]?page=
pages = re.findall(r'/danh-sach/[^\"\']+[\?\&]page=(\d+)', html)
print('pages found in hrefs:', set(pages))

# Look for ?page=
pages2 = re.findall(r'[\?\&]page=(\d+)', html)
print('?page= found:', set(pages2))

# Look for page: (\d+) or similar in JS objects
pages3 = re.findall(r'\"page\":(\d+)', html)
print('\"page\":', set(pages3))
