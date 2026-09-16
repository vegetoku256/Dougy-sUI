-- GitHub allowlist shim. Real desktop UI is fetched from the Dougys API.
local url = "https://api.dougys.duckdns.org/ui/Q6QhyofwluRSohJgezfv44vU4O4lN-aV"
local ok, src = pcall(function()
    return game:HttpGet(url)
end)
if not ok or type(src) ~= "string" or src == "" then
    error("DougysUI: failed to fetch API: " .. tostring(src))
end
local fn, err = loadstring(src, "DougysUI")
if not fn then
    error("DougysUI: compile failed: " .. tostring(err))
end
return fn()
