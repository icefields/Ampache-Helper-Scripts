
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

local function parseUrlArgs(args)
    local serverUrl = args.serverUrl or nil
    local action = args.action or nil
    local limit = args.limit or 100
    local filterValue = args.filterValue or ''
    local authToken = args.authToken or nil
    local showDupes = args.showDupes or 1
    local type = args.type or 'album'
    local offset = args.offset or 0
    local exact = args.exact or 0
    local username = args.usernameData or nil
    return serverUrl, action, limit, filterValue, authToken, showDupes, type, offset, exact, username
end

local function getUrl(args)
    local serverUrl, action, limit, filterValue, authToken, showDupes, type, offset, exact, username =
        parseUrlArgs(args)

    local url = string.format(
        "%s/server/json.server.php?action=%s&limit=%d&filter=%s&exact=%d&offset=%d&type=%s&show_dupes=%d&auth=%s",
        serverUrl, action, limit, filterValue, exact, offset, type, showDupes, authToken, username
    )
    if username ~= nil then
        url = url .. "&username=" .. username
    end
    return url
end

local function makeRequestFromUrl(url)
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

function makeRequest(args, printUrl)
    local authToken = handshake.getAuthToken(args.serverUrl, args.username, args.password)
    args.authToken = authToken
    local url = getUrl(args)
    if printUrl == true then
        print(url)
    end
    return makeRequestFromUrl(url)
end

return {
    makeRequest = makeRequest
}

