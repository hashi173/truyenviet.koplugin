import re
with open('list_page.html', 'r', encoding='utf-8') as f:
    html = f.read()
    print('Length:', len(html))
    
    # Try finding typical pagination buttons from truyendich.ai
    matches = re.findall(r'<button[^>]*>(\d+)</button>', html)
    print('Buttons:', matches)
    
    # Any data-page or similar?
    pages = re.findall(r'data-page=[\"\'](\d+)[\"\']', html)
    print('data-page:', pages)
    
    # Let's see if total pages is inside a json string
    match = re.search(r'totalPages\\":(\d+)', html)
    if match: print("totalPages escaped:", match.group(1))
    
    match = re.search(r'\"totalPages\":(\d+)', html)
    if match: print("totalPages unescaped:", match.group(1))

    match = re.search(r'totalPage\\":(\d+)', html)
    if match: print("totalPage escaped:", match.group(1))

    match = re.search(r'\"totalPage\":(\d+)', html)
    if match: print("totalPage unescaped:", match.group(1))
