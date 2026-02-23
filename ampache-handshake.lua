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
local https = require("ssl.https")

-- get the current Unix timestamp
local function getTimestamp()
    return os.time()
end

local function calculateSha256(input)
    return sha2.sha256(input)
end

local function fetchJson(url, maxRedirects)
    maxRedirects = maxRedirects or 5

    local responseBody = {}
    local requester = url:match("^https://") and https or http

    local _, code, headers = requester.request{
        url = url,
        sink = ltn12.sink.table(responseBody)
    }

    if code == 301 or code == 302 or code == 307 or code == 308 then
        if maxRedirects <= 0 then
            error("Too many redirects (possible http/https loop)")
        end

        local newUrl = headers.location
        if not newUrl then
            error("Redirect without Location header")
        end

        return fetchJson(newUrl, maxRedirects - 1)
    end

    if code ~= 200 then
        error("HTTP request failed with status code " .. tostring(code))
    end

    return table.concat(responseBody)
end
-- fetch JSON from the URL
local function fetchJson2(url)
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
    return str2Json(fetchJson(url, 20))
end

local function getAuthToken(serverUrl, username, password)
    local jsonResp = handshake(serverUrl, username, password)
    return jsonResp['auth']
end

-- Return a table containing the functions
return {
    getAuthToken = getAuthToken,
    handshake = handshake
}
