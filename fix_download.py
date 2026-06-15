import re

with open("truyenviet.koplugin/truyenviet/cover_cache.lua", "r", encoding="utf-8") as f:
    text = f.read()

text = re.sub(r"local content, err, response_headers = Http:get\(", "local content, err, response_headers = Http:requestAsync(", text)

with open("truyenviet.koplugin/truyenviet/cover_cache.lua", "w", encoding="utf-8") as f:
    f.write(text)
