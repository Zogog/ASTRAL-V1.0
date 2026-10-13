-- ASTRAL bootstrap loader
-- Keeps the phone-side command short while forcing a fresh dist/ASTRAL.lua fetch.

local url = "https://raw.githubusercontent.com/Zogog/ASTRAL-V1.0/main/dist/ASTRAL.lua"
    .. "?fresh=" .. tostring(os.time())

local source = game:HttpGet(url)
local chunk, err = loadstring(source)

if not chunk then
    error("ASTRAL loader failed to compile dist/ASTRAL.lua: " .. tostring(err))
end

return chunk()
