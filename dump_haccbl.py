import sys

html = open('haccbl_story.html', encoding='utf-8').read()
idx = html.find('id="chapter-list"')
if idx != -1:
    print(html[idx:idx+1500])
else:
    print("Not found")
