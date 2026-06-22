local html = io.open('test_hacc_story.html'):read('*a')
for item in html:gmatch('<div[^>]-class="[^"]*chapter%-item[^"]*"[^>]*>([%s%S]-)</a>') do 
    print("ITEM: ", item)
    break
end
