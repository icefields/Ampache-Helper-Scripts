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

-- Mapping internal argument names to API parameter names
local param_mapping = {
    limit = "limit",
    filter = "filter",
    type = "type",
    offset = "offset",
    exact = "exact",
    include = "include",
    show_dupes = "show_dupes",
    hide_search = "hide_search",
    add = "add",
    update = "update",
    cond = "cond",
    sort = "sort",
    username_data = "username", -- Maps the stats-specific username_data to API 'username'
    random = "random",
    top50 = "top50"
}

local function buildQueryString(args, authToken)
    local parts = {}
    
    -- Add auth token
    if authToken then
        table.insert(parts, "auth=" .. authToken)
    end
    
    -- Add action
    if args.action then
        table.insert(parts, "action=" .. args.action)
    end
    
    -- Add other arguments based on mapping
    for arg_key, api_key in pairs(param_mapping) do
        if args[arg_key] ~= nil then
            table.insert(parts, api_key .. "=" .. ampache.urlencode(tostring(args[arg_key])))
        end
    end
    
    return table.concat(parts, "&")
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

local function getStoredToken()
    local filename = "token"
    if ampache.isFileEmpty(filename) then 
        return nil, nil
    end
    local content = ampache.readFile(filename)
    if not content then return nil, nil end
    
    -- Format: token|expire_date
    local token, expire = content:match("([^|]+)|([^|]+)")
    return token, expire
end

local function storeToken(token, expire)
    local filename = "token"
    ampache.writeFile(filename, token .. "|" .. (expire or ""))
end

local function isTokenExpired(expireStr)
    if not expireStr then return true end
    -- Basic ISO 8601 comparison (assumes server returns UTC like 2021-02-26T14:48:00+00:00)
    -- We compare strings because ISO 8601 is lexicographically sortable
    -- We need current time in UTC in the same format.
    -- Lua's os.date("!%Y-%m-%dT%H:%M:%S") gives UTC but without timezone.
    -- We will just compare the string up to seconds.
    -- This is a simplification; robust parsing is better but requires libraries.
    
    -- Get current UTC time table
    local now_utc = os.date("!*t")
    local now_str = string.format("%04d-%02d-%02dT%02d:%02d:%02d", 
        now_utc.year, now_utc.month, now_utc.day, now_utc.hour, now_utc.min, now_utc.sec)
    
    -- Compare
    return now_str >= expireStr:sub(1, 19) -- Compare up to seconds
end

function authToken(serverUrl, username, password)
    local token, expire = getStoredToken()
    
    if token and not isTokenExpired(expire) then
        return token
    end
    
    -- Token missing or expired, perform handshake
    local jsonResp = handshake.handshake(serverUrl, username, password)
    if jsonResp and jsonResp.auth then
        storeToken(jsonResp.auth, jsonResp.session_expire)
        return jsonResp.auth
    else
        error("Failed to obtain authentication token")
    end
end

function makeRequest(args, printUrl)
    -- Validate required arguments
    if not args.server_url then
        error("Missing required argument: server_url")
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
    if not args.server_url:match("^https?://") then
        error("Invalid server URL format. Must start with http:// or https://")
    end
    
    -- Validate action name
    if not args.action:match("^[a-z_]+$") then
        error("Invalid action name. Must contain only lowercase letters and underscores")
    end
    
    local auth = authToken(args.server_url, args.username, args.password)
    
    -- Build URL
    local queryString = buildQueryString(args, auth)
    local url = string.format("%s/server/json.server.php?%s", args.server_url, queryString)
    
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
