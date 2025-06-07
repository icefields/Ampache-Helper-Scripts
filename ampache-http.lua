
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
local https = require("ssl.https")
local ltn12 = require("ltn12")
local cjson = require("cjson")
local ampache = require("ampache-common")

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
    local include = args.include or nil
    return serverUrl, action, limit, filterValue, authToken, showDupes, type, offset, exact, username, include
end

local function getUrl(args)
    local serverUrl, action, limit, filterValue, authToken, showDupes, type, offset, exact, username, include =
        parseUrlArgs(args)

    local url = string.format(
        "%s/server/json.server.php?action=%s&limit=%d&filter=%s&exact=%d&offset=%d&type=%s&show_dupes=%d&auth=%s",
        serverUrl, action, limit, filterValue, exact, offset, type, showDupes, authToken, username
    )
    if username ~= nil then
        url = url .. "&username=" .. username
    end
    if include ~= nil then
        url = url .. "&include=" .. include
    end

    return url
end



local function makeRequestFromUrl(url)
    local max_redirects = 5
    local response_body = {}

    for _ = 1, max_redirects do
        response_body = {}
        local request = url:match("^https") and https or http

        local res, code, response_headers, status = request.request{
            url = url,
            sink = ltn12.sink.table(response_body),
            redirect = false  -- we handle redirects manually
        }

        -- Follow redirect if needed
        if (code == 301 or code == 302) and response_headers and response_headers.location then
            url = response_headers.location
        else
            local json_response = nil
            local data = nil
            if code == 200 then
                if response_body and #response_body > 0 then
                    json_response = table.concat(response_body)
                    local ok, decoded = pcall(cjson.decode, json_response)
                    if ok then
                       data = decoded
                    else
                        return nil, 404, {}, "error decoding json", nil, nil
                    end
                end
            end
            return res, code, response_headers, status, json_response, data
        end
    end

    return nil, 310, {}, "Too many redirects", nil, nil
end





local function makeRequestFromUrlOLD(url)
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

function authToken(serverUrl, username, password)
    local filename = "token"
    local token = nil
    if ampache.isFileEmpty(filename) then 
        token = handshake.getAuthToken(serverUrl, username, password)
        ampache.writeFile(filename, token)
    else
        token = ampache.readFile(filename)
    end
    return token
end

function makeRequest(args, printUrl)
    res, code, response_headers, status, json_response, data = getTokenAndPerformRequest(args, printUrl)
    if code == 200 then
        return res, code, response_headers, status, json_response, data
    else 
        ampache.writeFile("token", "")
        return getTokenAndPerformRequest(args, printUrl)
    end
end

function getTokenAndPerformRequest(args, printUrl)
    local authToken = authToken(args.serverUrl, args.username, args.password)
    args.authToken = authToken
    local url = getUrl(args)
    if printUrl == true then
        print(url)
    end
    return makeRequestFromUrl(url)
end

function streamUrl(serverUrl, username, password, songId, authToken)
    local authToken = authToken(serverUrl, username, password)
    return string.format(
        "%s/server/json.server.php?action=stream&auth=%s&type=song&id=%s",
        serverUrl, authToken, songId
    )
end

return {
    makeRequest = makeRequest,
    streamUrl = streamUrl,
    authToken = authToken
}

