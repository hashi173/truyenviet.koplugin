import re
import json

with open('test_story.txt', 'r', encoding='utf-8') as f:
    html = f.read()

# Let's find pagination info and the total chapters
match = re.search(r'"chapterCount":(\d+)', html)
if match:
    print('Total chapters:', match.group(1))

# Find script containing __NEXT_DATA__
match = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', html)
if match:
    data = json.loads(match.group(1))
    print(json.dumps(data)[:500])
