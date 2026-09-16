-- GitHub allowlist shim. Real TSB loader is fetched from the Dougys API.
local url = "https://api.dougys.duckdns.org/loader/JzS9pLWIVJHcRHGNwg_xp3bXTjnfFFN2?t="
    .. tostring(math.random(1000000, 9999999))
local ok, src = pcall(function()
    return game:HttpGet(url)
end)
if not ok or type(src) ~= "string" or src == "" then
    error("TSB: failed to fetch API: " .. tostring(src))
end
local fn, err = loadstring(src, "TSB")
if not fn then
    error("TSB: compile failed: " .. tostring(err))
end
return fn()
