-- GitHub allowlist shim. Real TSB loader is fetched from the Dougys API.
local url = "https://api.dougys.duckdns.org/loader/JzS9pLWIVJHcRHGNwg_xp3bXTjnfFFN2"

local function bodyOf(res)
    if type(res) == "string" and #res > 0 then
        return res
    end
    if type(res) == "table" then
        local code = res.StatusCode or res.status_code or res.Status
        local body = res.Body or res.body
        if type(body) == "string" and #body > 0 and (code == nil or code == 200) then
            return body
        end
    end
end

local function fetch(u)
    local last
    local steps = {
        function()
            return game:HttpGet(u)
        end,
        function()
            return game:HttpGetAsync(u)
        end,
        function()
            local req = (syn and syn.request) or (http and http.request) or http_request or request
            if not req then
                error("no request")
            end
            return req({
                Url = u,
                Method = "GET",
                Headers = {
                    ["User-Agent"] = "Mozilla/5.0",
                    ["Accept"] = "*/*",
                },
            })
        end,
    }
    for i = 1, #steps do
        local ok, res = pcall(steps[i])
        if ok then
            local body = bodyOf(res)
            if body then
                return body
            end
            last = res
        else
            last = res
        end
    end
    error("TSB: failed to fetch API: " .. tostring(last))
end

local src = fetch(url)
local fn, err = loadstring(src, "TSB")
if not fn then
    error("TSB: compile failed: " .. tostring(err))
end
return fn()
