local root = "."
package.path = table.concat({
    root .. "/truyenviet.koplugin/?.lua",
    root .. "/truyenviet.koplugin/?/init.lua",
    package.path,
}, ";")

local ImageUtils = require("truyenviet/image_utils")
local tests_run = 0

local function assertEqual(expected, actual, message)
    tests_run = tests_run + 1
    if expected ~= actual then
        error(string.format(
            "%s: expected %s, got %s",
            message,
            tostring(expected),
            tostring(actual)
        ))
    end
end

assertEqual(
    true,
    ImageUtils:isSupported(nil, "\137PNG\r\n\26\npayload"),
    "Recognizes PNG signature"
)
assertEqual(
    true,
    ImageUtils:isSupported(
        { ["content-type"] = "image/jpeg; charset=binary" },
        "payload"
    ),
    "Recognizes image content type"
)
assertEqual(
    false,
    ImageUtils:isSupported(
        { ["content-type"] = "text/html" },
        "<html>blocked</html>"
    ),
    "Rejects HTML payload"
)
assertEqual(
    "webp",
    ImageUtils:detectExtension(nil, "RIFFxxxxWEBPpayload", "page"),
    "Detects WebP signature"
)

print(string.format("Image utils tests passed: %d assertions", tests_run))
