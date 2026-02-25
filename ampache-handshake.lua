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
local ampache = require("ampache-common")

-- Determine token file path in user's home directory
local home_dir = os.getenv("HOME") or os.getenv("USERPROFILE")
local token_filename = "ampache_token"
local token_filepath = home_dir and (home_dir .. "/." .. token_filename) or token_filename

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
-- password_hash is optional. If provided, it is the SHA256 hash of the password.
local function handshake(serverUrl, username, password, password_hash)
    local timestamp = tostring(getTimestamp())
    -- Use provided hash or calculate from password
    local passwordSha256 = password_hash or calculateSha256(password)
    local auth = calculateSha256(timestamp .. passwordSha256)

    local url = string.format(
        "%s/server/json.server.php?action=handshake&timestamp=%s&auth=%s&user=%s",
        serverUrl,
        timestamp,
        auth,
        username
    )
    return str2Json(fetchJson(url))
end

local function getStoredToken()
    if ampache.isFileEmpty(token_filepath) then 
        return nil, nil
    end
    local content = ampache.readFile(token_filepath)
    if not content then return nil, nil end
    
    -- Format: token|expire_date
    local token, expire = content:match("([^|]+)|([^|]+)")
    return token, expire
end

local function storeToken(token, expire)
    local ok, err = ampache.writeFile(token_filepath, token .. "|" .. (expire or ""))
    if not ok then
        print("Warning: Could not save auth token to " .. token_filepath .. ": " .. tostring(err))
    end
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
    local jsonResp = handshake(serverUrl, username, password, password_hash)
    if jsonResp and jsonResp.auth then
        storeToken(jsonResp.auth, jsonResp.session_expire)
        return jsonResp.auth
    else
        error("Failed to obtain authentication token")
    end
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

return {
    getAuthToken = authToken,
    handshake = handshake
}
