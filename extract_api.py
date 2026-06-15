import re

with open('test_story.txt', 'r', encoding='utf-8') as f:
    html = f.read()

# Look for chapter API calls
apis = re.findall(r'https://[^"]*api[^"]*', html)
print("APIs:", set(apis))

# Look for build id to construct Next.js data URL
build_match = re.search(r'"buildId":"([^"]+)"', html)
if build_match:
    print("Build ID:", build_match.group(1))
    
# Check for any JSON containing chapter info
match = re.search(r'\"chapterCount\":(\d+)', html)
if match:
    print("Chapter count:", match.group(1))

# look for page= or similar in the json state
match = re.search(r'\"totalPages\":(\d+)', html)
if match:
    print("Total pages:", match.group(1))
    
# look for next.js server components payload
match = re.search(r'\?_rsc=([^"]+)', html)
if match:
    print("RSC token:", match.group(1))
