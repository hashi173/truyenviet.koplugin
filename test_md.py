import urllib.request
import urllib.error
import ssl

context = ssl._create_unverified_context()
url = 'https://api.mangadex.org/manga?status%5B%5D=completed&availableTranslatedLanguages%5B%5D=vi&availableTranslatedLanguages%5B%5D=en&limit=20&offset=0&includes%5B%5D=cover_art&includes%5B%5D=author&order%5BfollowedCount%5D=desc'
req = urllib.request.Request(
    url, 
    headers={'User-Agent': 'Mozilla/5.0'}
)

try:
    with urllib.request.urlopen(req, context=context) as response:
        html = response.read()
        print("SUCCESS:", response.status)
        print(html[:500])
except urllib.error.HTTPError as e:
    print("HTTP ERROR:", e.code)
    print("Headers:", e.headers)
    print("Body:", e.read().decode('utf-8', errors='ignore'))
except Exception as e:
    print("ERROR:", e)
