-----------------------------------------------------
-- ----------------------------------------------- --
--   ▄        ▄     ▄  ▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄  ▄     ▄   --
--  ▐░▌      ▐░▌   ▐░▌▐░█▀▀▀▀▀  ▀▀█░█▀▀ ▐░▌   ▐░▌  --
--  ▐░▌      ▐░▌   ▐░▌▐░▌         ▐░▌   ▐░█   █░▌  --
--  ▐░▌      ▐░▌   ▐░▌▐░▌         ▐░▌   ▐░░░░░░░▌  --
--  ▐░▌      ▐░▌   ▐░▌▐░▌         ▐░▌    ▀▀▀▀▀█░▌  --
--  ▐░█▄▄▄▄▄ ▐░█▄▄▄█░▌▐░█▄▄▄▄▄  ▄▄█░█▄▄       ▐░▌  --
--   ▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀        ▀   --
-- ----------------------------------------------- --
-- ---- Helper script for printing album arts ---  --
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

local http = require("socket.http")
local json = require("dkjson")

-- Function to fetch JSON data from a URL
local function fetchJson(url)
    local response, status = http.request(url)
    if status ~= 200 then
        error("Failed to fetch data. HTTP status: " .. status)
    end
    return response
end

-- returns a comma-separated list of art url from the provided url
-- quote is a boolean that if true will put the urls between double quotes
local function artUrls(url, quote)
    -- Fetch the JSON response from the URL
    local response = fetchJson(url)

    -- Decode the JSON string
    local success, data = pcall(json.decode, response)

    if not success then
        error("Failed to parse JSON: " .. data)
    end

    -- Ensure 'data' is properly parsed
    if not data then
        error("Parsed data is nil")
    end

    -- Check if the input has an "album" field that is an array
    if type(data.album) ~= "table" then
        error("Invalid JSON format. Expected an 'album' array")
    end

    -- Iterate over the array and collect the "art" values
    local arts = {}
    for _, item in ipairs(data.album) do
        if type(item.art) == "string" and item.has_art == true then
            if quote then
                table.insert(arts, '"' .. item.art .. '"')
            else
                table.insert(arts, item.art)
            end
        end
    end
    return table.concat(arts, ",") 
end

-- Check if the URL argument is provided
if not arg[1] then
    error("No URL provided. Usage: lua script.lua [-q] '<url>'")
end

local url
local quote = false
local printOutput = false
-- Parse command line arguments
if arg[1] == "-q" then
    quote = true
    url = arg[2]
elseif arg[1] =="-o" then
    printOutput = true
    url = arg[2]
else
    url = arg[1]
end

if not url then
    error("No URL provided. Usage: lua script.lua [-q] '<url>'")
end

-- Print the "art" values separated by commas
if (quote or printOutput) then
    print(artUrls(url, quote))
end

return {
    artUrls = artUrls
}

