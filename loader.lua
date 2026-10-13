-- ASTRAL persistent bootstrap loader
-- Resolves the latest main commit first, then pins the entire ASTRAL boot to
-- that immutable revision. This avoids raw.githubusercontent.com serving a
-- stale mix of dist and module files during rapid development.

local HttpService = game:GetService("HttpService")
local owner = "Zogog"
local repo = "ASTRAL-V1.0"
local nonce = tostring(os.time())

local revision
local ok, response = pcall(function()
    return game:HttpGet(
        "https://api.github.com/repos/" .. owner .. "/" .. repo
        .. "/commits/main?fresh=" .. nonce
    )
end)

if ok and type(response) == "string" then
    local decodedOk, decoded = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    if decodedOk and type(decoded) == "table" and type(decoded.sha) == "string" then
        revision = decoded.sha
    end
end

-- API lookup can fail if GitHub's unauthenticated rate limit is exhausted.
-- Keep a cache-busted main fallback so ASTRAL remains startable.
local ref = revision or "main"
local url = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo
    .. "/" .. ref .. "/dist/ASTRAL.lua?fresh=" .. nonce

local source = game:HttpGet(url)

-- When we resolved a commit SHA, make every module fetch use that same
-- revision too. This prevents a fresh dist file loading stale main modules.
if revision then
    source = source:gsub(
        'Branch = "main",',
        'Branch = "' .. revision .. '",',
        1
    )
end

local chunk, err = loadstring(source)
if not chunk then
    error(
        "ASTRAL loader failed to compile dist/ASTRAL.lua"
        .. " [" .. tostring(ref) .. "]: "
        .. tostring(err)
    )
end

print("[ASTRAL LOADER] Revision " .. tostring(ref))
return chunk()
