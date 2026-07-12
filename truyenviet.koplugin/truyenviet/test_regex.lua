local html = io.open('scratch_dualeo.html', 'r'):read('*a');
local count = 0;
for h, t in html:gmatch('<a[^>]+href="(https?://dualeotruyenfull%.net/[^"]+chuong[^"]+)"[^>]*>.-<h3[^>]*>(.-)</h3>') do
    count = count + 1
end
print('Count 1: ' .. count);

count = 0
for h, t in html:gmatch('<a[^>]+href="(https?://dualeotruyenfull%.net/[^"]+chuong[^"]+)"[^>]*>.-</h3>') do
    count = count + 1
end
print('Count 2: ' .. count);

count = 0
for h, t in html:gmatch('<a[^>]+href="(https?://dualeotruyenfull%.net/[^"]+chuong[^"]+)"') do
    count = count + 1
end
print('Count 3: ' .. count);
