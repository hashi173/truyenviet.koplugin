import re

with open("truyenviet.koplugin/truyenviet/browser.lua", "r", encoding="utf-8") as f:
    text = f.read()

# Replace InfoMessage:new{
text = re.sub(r"InfoMessage:new\s*\{", "InfoMessage:new{\n            title = \"Truyện Việt\",", text)

# Replace ConfirmBox:new{
text = re.sub(r"ConfirmBox:new\s*\{", "ConfirmBox:new{\n            title = \"Truyện Việt\",", text)

# Remove duplicates if run multiple times
text = re.sub(r"(title = \"Truyện Việt\",\s*)+", "title = \"Truyện Việt\",\n            ", text)

with open("truyenviet.koplugin/truyenviet/browser.lua", "w", encoding="utf-8") as f:
    f.write(text)
