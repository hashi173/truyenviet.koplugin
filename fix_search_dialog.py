import re

with open("truyenviet.koplugin/truyenviet/browser.lua", "r", encoding="utf-8") as f:
    text = f.read()

# Modify showSearchDialog definition
def_pattern = r"function Browser:showSearchDialog\(source, on_return_callback\)"
def_repl = r"function Browser:showSearchDialog(source, on_return_callback, parent_view)"
text = re.sub(def_pattern, def_repl, text)

# Modify the Quay lại callback inside showSearchDialog
quay_lai_pattern = r"text = \"Quay lại\",\s*callback = function\(\)\s*closeAndRun\(dialog, on_return_callback\)\s*end,"
quay_lai_repl = """text = "Quay lại",
                    callback = function()
                        closeAndRun(dialog, function()
                            if on_return_callback then on_return_callback() end
                        end)
                    end,"""
text = re.sub(quay_lai_pattern, quay_lai_repl, text)

# Modify the Tìm callback inside showSearchDialog
tim_pattern = r"closeAndRun\(dialog, function\(\)\s*self:search\(source, query, on_return_callback\)\s*end\)"
tim_repl = """closeAndRun(dialog, function()
                            if parent_view and type(parent_view.onClose) == "function" then
                                UIManager:close(parent_view)
                            end
                            self:search(source, query, on_return_callback)
                        end)"""
text = re.sub(tim_pattern, tim_repl, text)

# Modify caller in showRoot()
root_search_pattern = r"callback = function\(\)\s*self:showSearchDialog\(nil, function\(\)\s*self:showRoot\(\)\s*end\)\s*end,"
root_search_repl = """callback = function()
                self:showSearchDialog(nil, function()
                    self:showRoot()
                end, view)
                return true
            end,"""
text = re.sub(root_search_pattern, root_search_repl, text)

# Modify caller in browseSource()
browse_search_pattern = r"callback = function\(\)\s*self:showSearchDialog\(source, function\(\)\s*self:browseSource\(source, page_data, page, on_return_callback\)\s*end\)\s*end,"
browse_search_repl = """callback = function()
                self:showSearchDialog(source, function()
                    self:browseSource(source, page_data, page, on_return_callback)
                end, view)
                return true
            end,"""
text = re.sub(browse_search_pattern, browse_search_repl, text)

# Modify caller inside search_callback of StoryResults (called when hitting search icon)
# Wait, inside StoryResults we don't return true, we just don't close it.
story_results_search_pattern = r"search_callback = function\(\)\s*self:showSearchDialog\(source, function\(\)\s*self:showStoryList\(page_data, source, on_return_callback\)\s*end\)\s*end,"
story_results_search_repl = """search_callback = function()
            self:showSearchDialog(source, function()
                self:showStoryList(page_data, source, on_return_callback)
            end, view)
        end,"""
text = re.sub(story_results_search_pattern, story_results_search_repl, text)

# Also fix the search_callback when story list is generated from search results!
# Wait, search() calls showStoryList too!
# Let's just find all self:showSearchDialog( calls.
# I will use a custom script for this.
with open("truyenviet.koplugin/truyenviet/browser.lua", "w", encoding="utf-8") as f:
    f.write(text)
