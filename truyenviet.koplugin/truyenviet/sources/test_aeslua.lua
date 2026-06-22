local current_dir = "d:\\Project\\truyenfull\\truyenviet.koplugin\\truyenviet\\sources\\"
package.path = package.path .. ";" .. current_dir .. "aeslua/src/?.lua;" .. current_dir .. "?.lua"
local ciphermode = require("aeslua.ciphermode")
print("success")
