-- GitHub allowlist shim. Real mobile UI is fetched from the Dougys API.
local url = "https://api.dougys.duckdns.org/ui/hXF-UCRNy1-NR8RFvcc6wCaN52Sx4-xM?t="
    .. tostring(math.random(1000000, 9999999))
local ok, src = pcall(function()
    return game:HttpGet(url)
end)
if not ok or type(src) ~= "string" or src == "" then
    error("DougysUI_Mobile: failed to fetch API: " .. tostring(src))
end
local fn, err = loadstring(src, "DougysUI_Mobile")
if not fn then
    error("DougysUI_Mobile: compile failed: " .. tostring(err))
end
return fn()
