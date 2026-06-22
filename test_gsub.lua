local url = 'https://haccbl.xyz/wp-content/uploads/2026/04/thiensu-150x150.avif'
local final_url = url:gsub('^https?://', 'https://i0.wp.com/') .. '?strip=info'
print(final_url)
