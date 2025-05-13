
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
----     Luci4 utils for Ampache API calls      -----
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

local handshake = require("ampache-handshake")
local http = require("socket.http")
local ltn12 = require("ltn12")
local cjson = require("cjson")

function getUrl(server_url, action, authToken, username, password, limit, filter_value)
    return string.format(
        "%s/server/json.server.php?action=%s&limit=%d&filter=%s&exact=0&offset=0&auth=%s",
        server_url, action, limit, urlencode(filter_value:gsub('"', '')), authToken
    )
end

function makeRequest(server_url, action, username, password, limit, filter_value)
    local authToken = handshake.getAuthToken(server_url, username, password)
    local url = getUrl(server_url, action, authToken, username, password, limit, filter_value)
    -- print(url)
    local response_body = {}
    local res, code, response_headers, status = http.request{
        url = url,
        sink = ltn12.sink.table(response_body)  -- Capture the response into the table
    }

    local json_response = nil 
    local data = nil
    if (code == 200) then
        json_response = table.concat(response_body)
        data = cjson.decode(json_response)
    end

    return res, code, response_headers, status, json_response, data
end

return {
    makeRequest = makeRequest
}

