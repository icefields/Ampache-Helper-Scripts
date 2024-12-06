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
-- ------- Luci4 util print Ampache stats -------- --
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

local handshake = require("ampache-handshake")
local http = require("socket.http")
local ltn12 = require("ltn12")  -- For handling response body
local cjson = require("cjson")  -- For decoding JSON

-- Default values for optional arguments
local limit = 10  -- Default limit
local filter_value = ""  -- Default filter
local is_json_output = false

-- Function to check if a value is valid (not nil, empty, or 'null')
local function isValid(value)
    return value ~= nil and value ~= '' and value ~= 'null' and tostring(value) ~= 'userdata: (nil)'
end

-- Function to print only if valid
local function safePrint(label, value)
    if isValid(value) then
        print(string.format("%s: %s", label, tostring(value)))
    end
end

-- Function to print the help guide
local function printHelp()
    print([[
Usage: lua stats.lua <server_url> <username> <password> [OPTIONS]

Required arguments:
  <server_url>   The URL of the Ampache server
  <username>     The username for authentication
  <password>     The password for authentication

Optional arguments:
  -l <limit>     Limit the number of items to retrieve (default: 10)
  -f <filter>    Specify the filter for the items
  -j		     Prints the original json from the network response, when this is passed, all other optional args are ignored
  -h             Show this help message
]])
end

-- Check for the help flag (-h)
if arg[1] == "-h" then
    printHelp()
    return  -- Exit the script after printing help
end

-- Ensure that the server_url, username, and password are provided
if not arg[1] or not arg[2] or not arg[3] then
    print("Error: Missing required arguments (server_url, username, password). Use -h for help.")
    printHelp()
    return  -- Exit the script if required arguments are missing
end

local server_url = arg[1]
local username = arg[2]
local password = arg[3]

-- Parse the command-line arguments
for i = 4, #arg do
    local arg_val = arg[i]
    if arg_val == "-l" then
        -- Limit argument
        limit = tonumber(arg[i + 1]) or 100
        i = i + 1  -- Skip the next argument
    elseif arg_val == "-f" then
        -- Filter argument
        filter_value = arg[i + 1] or ""
        i = i + 1  -- Skip the next argument
    elseif arg_val == "-j" then
	is_json_output = true
    end
end

-- Get the auth token
local authToken = handshake.getAuthToken(server_url, username, password)

-- Prepare the URL with the authToken, limit, type, and filter
local url = string.format(
    "%s/server/json.server.php?action=playlists&limit=%d&filter=%s&exact=0&offset=0&hide_search=1&show_dupes=1&auth=%s",
    server_url, limit, filter_value, authToken
)

-- Perform the HTTP GET request
local response_body = {}
local res, code, response_headers, status = http.request{
    url = url,
    sink = ltn12.sink.table(response_body)  -- Capture the response into the table
}

-- Check if the request was successful
if code == 200 then
    
    -- Join the response body into a string
    local json_response = table.concat(response_body)
    
    -- if the -j option is passed, just print the json file
    if is_json_output == true then
    	print(json_response)
	return
    end

    -- Decode the JSON response
    local data = cjson.decode(json_response)

    -- Iterate over the "album" array (or type array based on the passed type) and print the desired information
    for _, item in ipairs(data["playlist"]) do
        -- Print name if valid
        safePrint("name", string.format("%s (id: %s)", item.name, item.id))

        if item.owner then
            safePrint("owner", item.owner)
        end

        if item.items then
            safePrint("items", item.items)
        end

        safePrint("type", item.type)
        safePrint("last_update", item.last_update)

        -- Print art if valid and has_art is true
        if item.has_art then
            safePrint("art", item.art)
        end

        -- Print flag if valid
        safePrint("flag", item.flag)

        -- Print rating if valid
        safePrint("rating", item.rating)

        -- Print averagerating if valid
        safePrint("averagerating", item.averagerating)

        print("\n")  -- Add a blank line between items
    end
else
    -- Print an error message if the request fails
    print("HTTP request failed with status: " .. status)
end

