local html = [[
<a class="text-capitalize" href="https://metruyenvn.org/chuong-55-16/">
    <span class="hidden-sm hidden-xs">
        Sao Cậu Vẫn Chưa Thích [...] – Chương 55: PN 5: Toàn văn hoàn
    </span>
</a>
<a class="text-capitalize" href="https://metruyenvn.org/chuong-54-18/">
    <span class="hidden-sm hidden-xs">
        Sao Cậu Vẫn Chưa Thích [...] – Chương 54: PN 4: Kỷ niệm ngày cưới 2
    </span>
</a>
]]

local count = 0
for href, inner_html in html:gmatch('<a[^>]+href="(https?://metruyenvn%.org/chuong%-[^"]+)"[^>]*>([%s%S]-)</a>') do
    count = count + 1
    print(href, inner_html:match('<span class="hidden%-sm hidden%-xs">%s*(.-)%s*</span>'))
end
print("Total:", count)
