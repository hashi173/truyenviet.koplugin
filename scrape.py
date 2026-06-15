import urllib.request
import re
import json

url = 'https://truyendich.ai/doc-truyen/ngao-the-dan-than'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        html = response.read().decode('utf-8')
        
        matches = re.findall(r'href="(/doc-truyen/[^"]+)"', html)
        print('Links found:', len(matches))
        for m in list(set(matches))[:10]:
            print(m)
            
        print("---")
        # find the API endpoint for getting chapters
        # Look for the build ID
        build_id_match = re.search(r'"buildId":"([^"]+)"', html)
        if build_id_match:
            print("Build ID:", build_id_match.group(1))
        
        # Look for chapter list API calls
        print(re.findall(r'https://[^"]*api[^"]*', html))
except Exception as e:
    print(e)
