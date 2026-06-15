import re

with open('list_page.html', 'r', encoding='utf-8') as f:
    html = f.read()

# find all integers after totalPages or similar strings
for m in re.finditer(r'\"(total(?:Pages|Items|Count|))\":(\d+)', html, re.IGNORECASE):
    print("Found:", m.group(1), m.group(2))
    
# look for page parameters in the Next.js initial data tree
for m in re.finditer(r'\"page\"[\:\,]\s*\"?(\d+)\"?', html, re.IGNORECASE):
    print("Found page:", m.group(1))
