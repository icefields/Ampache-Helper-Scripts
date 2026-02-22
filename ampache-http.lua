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
    local typeValue = args.type or 'album'
    local offset = args.offset or 0
    local exact = args.exact or 0
    local username = args.usernameData or nil
    local include = args.include or nil
    return serverUrl, action, limit, filterValue, authToken, showDupes, typeValue, offset, exact, username, include
end

local function getUrl(args)
    local serverUrl, action, limit, filterValue, authToken, showDupes, typeValue, offset, exact, username, include =
        parseUrlArgs(args)

    local url = string.format(
        "%s/server/json.server.php?action=%s&limit=%d&filter=%s&exact=%d&offset=%d&type=%s&show_dupes=%d&auth=%s",
        serverUrl, action, limit, filterValue, exact, offset, typeValue, showDupes, authToken
    )
    if username ~= nil then
        url = url .. "&username=" .. ampache.urlencode(username)
    end
    if include ~= nil then
        url = url .. "&include=" .. ampache.urlencode(include)
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
            redirect = false  -- handle redirects manually
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

                        -- The server can be returning an error json despite of the 200 response
                        if data.error ~= nil then 
                            return nil, data.error.errorCode or 500, response_headers, "Error Returned by server: " .. (data.error.message or "Unknown error"), json_response, data
                        end

                    else
                        return nil, 404, response_headers, "Error decoding JSON response", nil, nil
                    end
                else
                    return nil, 204, response_headers, "Empty response body", nil, nil
                end
            elseif code == 400 then
                return nil, 400, response_headers, "Bad Request: The request was malformed", nil, nil
            elseif code == 401 then
                return nil, 401, response_headers, "Unauthorized: Invalid authentication credentials", nil, nil
            elseif code == 403 then
                return nil, 403, response_headers, "Forbidden: Insufficient permissions", nil, nil
            elseif code == 404 then
                return nil, 404, response_headers, "Not Found: The requested resource was not found", nil, nil
            elseif code == 429 then
                return nil, 429, response_headers, "Too Many Requests: Rate limit exceeded", nil, nil
            elseif code >= 500 then
                return nil, code, response_headers, "Server Error: " .. (status or "Unknown server error"), nil, nil
            else
                return nil, code, response_headers, "Unexpected HTTP status: " .. (status or "Unknown"), nil, nil
            end
            
            return res, code, response_headers, status, json_response, data
        end
    end

    return nil, 310, response_headers, "Too many redirects", nil, nil
end

function authToken(serverUrl, username, password)
    local filename = "token"
    local token = nil
    if ampache.isFileEmpty(filename) then 
        token = handshake.getAuthToken(serverUrl, username, password)
        if token then
            ampache.writeFile(filename, token)
        else
            error("Failed to obtain authentication token")
        end
    else
        token = ampache.readFile(filename)
        if not token then
            error("Failed to read authentication token from file")
        end
    end
    return token
end

function makeRequest(args, printUrl)
    -- Validate required arguments
    if not args.serverUrl then
        error("Missing required argument: serverUrl")
    end
    if not args.action then
        error("Missing required argument: action")
    end
    if not args.username then
        error("Missing required argument: username")
    end
    if not args.password then
        error("Missing required argument: password")
    end
    
    -- Validate server URL format
    if not args.serverUrl:match("^https?://") then
        error("Invalid server URL format. Must start with http:// or https://")
    end
    
    -- Validate action name
    if not args.action:match("^[a-z_]+$") then
        error("Invalid action name. Must contain only lowercase letters and underscores")
    end
    
    res, code, response_headers, status, json_response, data = getTokenAndPerformRequest(args, printUrl)
    if code == 200 then
        return res, code, response_headers, status, json_response, data
    else 
        -- Clear the token on authentication errors
        if code == 401 or code == 403 then
            ampache.writeFile("token", "")
        end
        
        -- Add more context to the error message
        local error_msg = string.format("HTTP request failed with status %d: %s", code, status)
        if json_response then
            error_msg = error_msg .. " | Response: " .. json_response
        end
        error(error_msg)
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
    if not songId then
        error("Missing required argument: songId")
    end
    
    local auth = authToken or authToken(serverUrl, username, password)
    return string.format(
        "%s/server/json.server.php?action=stream&auth=%s&type=song&id=%s",
        serverUrl, auth, songId
    )
end

return {
    makeRequest = makeRequest,
    streamUrl = streamUrl,
    authToken = authToken
}

-- DEPRECATED
--local function makeRequestFromUrlOLD(url)
--    local response_body = {}
--    local res, code, response_headers, status = http.request{
--        url = url,
--        sink = ltn12.sink.table(response_body)  -- Capture the response into the table
--    }
--
--    local json_response = nil
--    local data = nil
--    if (code == 200) then
--        json_response = table.concat(response_body)
--        data = cjson.decode(json_response)
--    end
--
--    return res, code, response_headers, status, json_response, data
--end
