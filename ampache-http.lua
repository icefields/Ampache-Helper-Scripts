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
local apiMethods = require("ampache-api-methods")

-- Mapping internal argument names to API parameter names
-- This handles cases where the CLI arg name differs from the API spec
local paramMapping = {
    limit = "limit",
    filter = "filter",
    type = "type",
    offset = "offset",
    exact = "exact",
    include = "include",
    showDupes = "show_dupes",
    hideSearch = "hide_search",
    add = "add",
    update = "update",
    cond = "cond",
    sort = "sort",
    usernameData = "username", -- Maps the stats-specific usernameData to API 'username'
    random = "random",
    top50 = "top50",
    id = "id",
    song = "song",
    artist = "artist",
    album = "album",
    name = "name",
    user = "user",
    client = "client",
    date = "date",
    position = "position",
    rating = "rating",
    flag = "flag",
    oid = "oid",
    method = "method",
    task = "task",
    catalog = "catalog",
    folder = "folder",
    file = "file",
    url = "url",
    mode = "mode",
    format = "format",
    bitrate = "bitrate",
    length = "length",
    offsetStream = "offset", -- Avoid conflict with pagination offset if needed, though API uses 'offset' for both usually
    stats = "stats"
}

local function buildQueryString(args, authToken, methodDef)
    local parts = {}
    
    -- Add auth token
    if authToken then
        table.insert(parts, "auth=" .. authToken)
    end
    
    -- Add action
    if args.action then
        table.insert(parts, "action=" .. args.action)
    end

    -- Helper to add a parameter
    local function addParam(key, value)
        if value ~= nil then
            table.insert(parts, key .. "=" .. ampache.urlencode(tostring(value)))
        end
    end
    
    -- 1. Add Required Parameters
    if methodDef and methodDef.required then
        for _, reqParam in ipairs(methodDef.required) do
            -- Check if we have a mapped arg or a direct arg
            local argVal = nil
            
            local found = false
            for argKey, apiKey in pairs(paramMapping) do
                if apiKey == reqParam and args[argKey] ~= nil then
                    addParam(apiKey, args[argKey])
                    found = true
                    break
                end
            end
            
            if not found and args[reqParam] ~= nil then
                addParam(reqParam, args[reqParam])
                found = true
            end
        end
    end

    -- 2. Add Optional Parameters provided in args
    if methodDef and methodDef.optional then
        for _, optParam in ipairs(methodDef.optional) do
             -- Check mapping
             local found = false
             for argKey, apiKey in pairs(paramMapping) do
                if apiKey == optParam and args[argKey] ~= nil then
                    addParam(apiKey, args[argKey])
                    found = true
                    break
                end
            end
            
            if not found and args[optParam] ~= nil then
                addParam(optParam, args[optParam])
            end
        end
    end
    
    -- 3. Fallback: Add any other arguments passed that might not be in definition (flexibility)
    for argKey, val in pairs(args) do
        -- Skip internal args
        if argKey ~= "action" and argKey ~= "server_url" and argKey ~= "username" and argKey ~= "password" and argKey ~= "password_hash" and argKey ~= "isJsonOutput" and argKey ~= "isPrintUrl" then
            local apiKey = paramMapping[argKey] or argKey
            -- Check if we already added it
            local alreadyAdded = false
            for _, part in ipairs(parts) do
                if part:match("^" .. apiKey .. "=") then
                    alreadyAdded = true
                    break
                end
            end
            
            if not alreadyAdded then
                addParam(apiKey, val)
            end
        end
    end
    
    return table.concat(parts, "&")
end

local function makeRequestFromUrl(url)
    local maxRedirects = 5
    local responseBody = {}

    for _ = 1, maxRedirects do
        responseBody = {}
        local request = url:match("^https") and https or http

        local res, code, responseHeaders, status = request.request{
            url = url,
            sink = ltn12.sink.table(responseBody),
            redirect = false  -- handle redirects manually
        }

        -- Follow redirect if needed
        if (code == 301 or code == 302) and responseHeaders and responseHeaders.location then
            url = responseHeaders.location
        else
            local jsonResponse = nil
            local data = nil
            if code == 200 then
                if responseBody and #responseBody > 0 then
                    jsonResponse = table.concat(responseBody)
                    
                    local ok, decoded = pcall(cjson.decode, jsonResponse)
                    if ok then
                        data = decoded

                        -- The server can be returning an error json despite of the 200 response
                        if data.error ~= nil then 
                            return nil, data.error.errorCode or 500, responseHeaders, "Error Returned by server: " .. (data.error.message or "Unknown error"), jsonResponse, data
                        end

                    else
                        return nil, 404, responseHeaders, "Error decoding JSON response", nil, nil
                    end
                else
                    return nil, 204, responseHeaders, "Empty response body", nil, nil
                end
            elseif code == 400 then
                return nil, 400, responseHeaders, "Bad Request: The request was malformed", nil, nil
            elseif code == 401 then
                return nil, 401, responseHeaders, "Unauthorized: Invalid authentication credentials", nil, nil
            elseif code == 403 then
                return nil, 403, responseHeaders, "Forbidden: Insufficient permissions", nil, nil
            elseif code == 404 then
                return nil, 404, responseHeaders, "Not Found: The requested resource was not found", nil, nil
            elseif code == 429 then
                return nil, 429, responseHeaders, "Too Many Requests: Rate limit exceeded", nil, nil
            elseif code >= 500 then
                return nil, code, responseHeaders, "Server Error: " .. (status or "Unknown server error"), nil, nil
            else
                return nil, code, responseHeaders, "Unexpected HTTP status: " .. (status or "Unknown"), nil, nil
            end
            
            return res, code, responseHeaders, status, jsonResponse, data
        end
    end

    return nil, 310, responseHeaders, "Too many redirects", nil, nil
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
    local nowUtc = os.date("!*t")
    local nowStr = string.format("%04d-%02d-%02dT%02d:%02d:%02d", 
        nowUtc.year, nowUtc.month, nowUtc.day, nowUtc.hour, nowUtc.min, nowUtc.sec)
    
    -- Compare
    return nowStr >= expireStr:sub(1, 19) -- Compare up to seconds
end

local function authToken(serverUrl, username, password, password_hash)
    local token, expire = getStoredToken()
    
    if token and not isTokenExpired(expire) then
        return token
    end
    
    -- Token missing or expired, perform handshake
    local jsonResp = handshake.handshake(serverUrl, username, password, password_hash)
    if jsonResp and jsonResp.auth then
        storeToken(jsonResp.auth, jsonResp.session_expire)
        return jsonResp.auth
    else
        error("Failed to obtain authentication token")
    end
end

local function makeRequest(args, printUrl)
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
    if not args.password and not args.password_hash then
        error("Missing required argument: password or password_hash")
    end
    
    -- Validate server URL format
    if not args.server_url:match("^https?://") then
        error("Invalid server URL format. Must start with http:// or https://")
    end
    
    -- Validate action name
    if not args.action:match("^[a-z_]+$") then
        error("Invalid action name. Must contain only lowercase letters and underscores")
    end
    
    -- Validate against API definition
    local methodDef = apiMethods.getMethod(args.action)
    if methodDef then
        local ok, err = apiMethods.validateMethod(args.action, args)
        if not ok then
            -- Log warning but proceed? Or error out? 
            -- We will log a warning to stderr but try to proceed for flexibility
            -- as some params might be passed under different names.
            io.stderr:write("Warning: " .. err .. "\n")
        end
    else
        io.stderr:write("Warning: Unknown API method '" .. args.action .. "'\n")
    end
    
    local auth = authToken(args.server_url, args.username, args.password, args.password_hash)
    
    -- Build URL
    local queryString = buildQueryString(args, auth, methodDef)
    local url = string.format("%s/server/json.server.php?%s", args.server_url, queryString)
    
    if printUrl == true then
        print(url)
    end
    
    return makeRequestFromUrl(url)
end

local function streamUrl(serverUrl, username, password, songId, authTokenArg)
    if not songId then
        error("Missing required argument: songId")
    end
    
    local auth = authTokenArg or authToken(serverUrl, username, password)
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
