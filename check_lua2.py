import re
def check(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.read().split('\n')
    depth = 0
    for i, line in enumerate(lines):
        clean = re.sub(r'\"(?:\\.|[^\"\\])*\"', '', line)
        clean = re.sub(r"\'(?:\\.|[^\'\\])*\'", '', clean)
        clean = re.sub(r'--.*', '', clean)
        words = re.findall(r'\b(if|function|do|end)\b', clean)
        for w in words:
            if w in ('if', 'function', 'do'): depth += 1
            elif w == 'end': depth -= 1
    print(filename, 'depth:', depth)

check('truyenviet.koplugin/truyenviet/http_client.lua')
check('truyenviet.koplugin/truyenviet/sources/cbunu.lua')
check('truyenviet.koplugin/truyenviet/sources/mangadex.lua')
check('truyenviet.koplugin/truyenviet/sources/haccbl.lua')
