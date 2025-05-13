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

-- setting the local path so the script can find dependencies
local script_path = debug.getinfo(1, "S").source:match("(.*/)") or ""
script_path = script_path:sub(2)  -- Removes the '@' at the beginning if it exists
local script_dir = script_path:match("(.+)/")  -- Get everything before the last '/'
script_dir = script_dir or ""  -- If no directory, make it an empty string
package.path = script_dir .. "/?.lua;" .. package.path

local ampache = require("ampache-utils")
local ampacheHttp = require("ampache-http")

-- Default values for optional arguments
local limit = 100  -- Default limit
local filter_value = ""  -- Default filter
local is_json_output = false

-- Function to print the help guide
local function printHelp()
    print([[
Usage: lua stats.lua <server_url> <username> <password> [OPTIONS]

Required arguments:
  <server_url>   The URL of the Ampache server
  <username>     The username for authentication
  <password>     The password for authentication

Optional arguments:
  -l <limit>     Limit the number of items to retrieve (default: 100)
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

local res, code, response_headers, status, json_response, data = ampacheHttp.makeRequest(server_url, "songs", username, password, limit, filter_value, is_json_output)

-- Check if the request was successful
if code == 200 then
    
    -- if the -j option is passed, just print the json file
    if is_json_output == true then
    	print(json_response)
	    return
    end

    for _, item in ipairs(data["song"]) do
        -- Print name if valid
        -- safePrint("title", string.format("%s (id: %s)", item.title, item.id))
        ampache.safePrint(item.artist.name, item.title)

        if item.url then
            print(item.url)
        end

        if item.album.name then
            print(item.album.name)
        end

        if item.art and item.has_art then
            print(item.art)
        end

        print("\n")  -- Add a blank line between items
    end
else
    -- Print an error message if the request fails
    print("HTTP request failed with status: " .. status)
end

