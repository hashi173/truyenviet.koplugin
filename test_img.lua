local html = io.open("cbunu_hoan_thanh.html", "r"):read("*a")
for src in html:gmatch('src="([^"]+)"') do
    if not src:find("190x247") then
        print(src)
    end
end
for data in html:gmatch('data%-original="([^"]+)"') do
    if not data:find("190x247") then
        print(data)
    end
end
