import re

with open("truyenviet.koplugin/truyenviet/browser.lua", "r", encoding="utf-8") as f:
    text = f.read()

# 1. Modify browseSource signature
text = re.sub(r"function Browser:browseSource\(source, genre, local_page, on_return_callback\)",
              r"function Browser:browseSource(source, genre, local_page, on_return_callback, parent_view)", text)

# 2. Modify browseSource success path to close parent_view before showStories
# It calls:
# self:showStories(
#     source.name .. " · " .. result.title,
#     chunked_stories,
#     on_return_callback,
#     ...
# We find `self:showStories(` inside `showCurrentListing` in `browseSource`.
# Wait, it's inside `showCurrentListing`!
# Let's replace the definition of `showCurrentListing`:
show_listing_pattern = r"local function showCurrentListing\(\)\n\s+UIManager:show\(Notification:new\{\n\s+text = string\.format\(\"Đã chuyển tới trang %d\", local_page\)\n\s+\}\)"
show_listing_repl = """local function showCurrentListing()
            if parent_view and type(parent_view.onClose) == "function" then
                UIManager:close(parent_view)
                parent_view = nil -- only close once
            end
            UIManager:show(Notification:new{
                text = string.format("Đã chuyển tới trang %d", local_page)
            })"""
text = re.sub(show_listing_pattern, show_listing_repl, text)

# 3. Modify showRoot to pass view and return true for source click
# The pattern is:
# callback = function()
#     if not SourceRegistry:isEnabled(current_source.id) then
#         ...
#         closeAndRun(view, function()
#             self:showRoot()
#         end)
#         return
#     end
#     closeAndRun(view, function()
#         self:browseSource(current_source, nil, 1, function()
#             self:showRoot()
#         end)
#     end)
# end,
source_cb_pattern = r"closeAndRun\(view, function\(\)\s*self:browseSource\(current_source, nil, 1, function\(\)\s*self:showRoot\(\)\s*end\)\s*end\)"
source_cb_repl = """self:browseSource(current_source, nil, 1, function()
                        self:showRoot()
                    end, view)
                    return true"""
text = re.sub(source_cb_pattern, source_cb_repl, text)

# 4. Modify browseSource prev/next page calls to pass view
# on_prev_page = local_page > 1 and function()
#     self:browseSource(
#         source,
#         genre,
#         local_page - 1,
#         on_return_callback
#     )
# end or nil,
prev_page_pattern = r"self:browseSource\(\s*source,\s*genre,\s*local_page - 1,\s*on_return_callback\s*\)"
prev_page_repl = r"self:browseSource(source, genre, local_page - 1, on_return_callback, view)"
text = re.sub(prev_page_pattern, prev_page_repl, text)

next_page_pattern = r"self:browseSource\(\s*source,\s*genre,\s*local_page \+ 1,\s*on_return_callback\s*\)"
next_page_repl = r"self:browseSource(source, genre, local_page + 1, on_return_callback, view)"
text = re.sub(next_page_pattern, next_page_repl, text)

# 5. Modify on_genres in browseSource
# on_genres = function(return_to_listing)
#     self:showGenreMenu(
#         source,
#         result.genres,
#         return_to_listing
#     )
# end,
genres_pattern = r"on_genres = function\(return_to_listing\)\s*self:showGenreMenu\(\s*source,\s*result\.genres,\s*return_to_listing\s*\)\s*end,"
genres_repl = """on_genres = function(return_to_listing, p_view)
                        self:showGenreMenu(
                            source,
                            result.genres,
                            return_to_listing,
                            p_view
                        )
                    end,"""
text = re.sub(genres_pattern, genres_repl, text)

with open("truyenviet.koplugin/truyenviet/browser.lua", "w", encoding="utf-8") as f:
    f.write(text)
