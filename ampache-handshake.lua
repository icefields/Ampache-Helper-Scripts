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
---- Luci4 util to get Ampache handshake values -----
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

local http = require("socket.http")
local ltn12 = require("ltn12")
local cjson = require("cjson")
local sha2 = require("sha2")

-- get the current Unix timestamp
local function getTimestamp()
    return os.time()
end

local function calculateSha256(input)
    return sha2.sha256(input)
end

-- fetch JSON from the URL
local function fetchJson(url)
    local responseBody = {}
    local _, code, _, _ = http.request{
        url = url,
        sink = ltn12.sink.table(responseBody)
    }
    
    if code ~= 200 and code ~= 301 and code ~=302 then
        error("HTTP request failed with status code " .. code)
    end
    return table.concat(responseBody)
end

local function str2Json(str)
    return cjson.decode(str)
end

-- Main function
local function handshake(serverUrl, username, password)
    local timestamp = tostring(getTimestamp())
    local passwordSha256 = calculateSha256(password)
    local auth = calculateSha256(timestamp .. passwordSha256)

    local url = string.format(
        "%s/server/json.server.php?action=handshake&timestamp=%s&auth=%s&user=%s",
        serverUrl,
        timestamp,
        auth,
        username
    )
    -- print(password)
    -- print()
    -- print(url)
    return str2Json(fetchJson(url))
end

local function getAuthToken(serverUrl, username, password)
    local jsonResp = handshake(serverUrl, username, password)
    return jsonResp['auth']
end

-- print(getAuthToken())
-- Return a table containing the functions
return {
    getAuthToken = getAuthToken,
    handshake = handshake
}
