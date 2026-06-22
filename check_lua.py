import re
import sys

def check_blocks(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        text = f.read()

    text = re.sub(r'\"(?:\\.|[^\"\\])*\"', '', text)
    text = re.sub(r"\'(?:\\.|[^\'\\])*\'", '', text)
    text = re.sub(r'--\[\[.*?\]\]', '', text, flags=re.DOTALL)
    text = re.sub(r'--.*', '', text)
    
    words = re.findall(r'\b(if|function|do|end)\b', text)
    opens = [w for w in words if w in ('if', 'function', 'do')]
    ends = [w for w in words if w == 'end']
    
    print(f"{filename}: opens={len(opens)}, ends={len(ends)}")

check_blocks('truyenviet.koplugin/truyenviet/http_client.lua')
check_blocks('truyenviet.koplugin/truyenviet/sources/cbunu.lua')
check_blocks('truyenviet.koplugin/truyenviet/sources/haccbl.lua')
check_blocks('truyenviet.koplugin/truyenviet/sources/truyendich.lua')
# check_blocks('truyenviet.koplugin/truyenviet/sources/mangadex.lua')

