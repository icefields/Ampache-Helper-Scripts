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

function shouldPrintHelp()
    -- Check for the help flag (-h)
    if arg[1] == "-h" then
        return true
    end

    -- Ensure that the server_url, username, and password are provided
    if not arg[1] or not arg[2] or not arg[3] then
        print("Error: Missing required arguments (server_url, username, password). Use -h for help.")
        return true
    end
    return false
end

function parseArgs(arg)
    local limit = 100  -- Default limit
    local filterValue = ""  -- Default filter
    local isJsonOutput = false
    local isPrintUrl = false
    
    local serverUrl = arg[1]
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
            filterValue = arg[i + 1] or ""
            i = i + 1  -- Skip the next argument
        elseif arg_val == "-j" then
	        isJsonOutput = true
        elseif arg_val == "-d" then
	        isPrintUrl = true
        end
    end

    return serverUrl, username, password, limit, filterValue, isJsonOutput, isPrintUrl
end

-- Print the help guide
local function printHelp(name)
    print("Usage: lua " .. name .. 
[[ <server_url> <username> <password> [OPTIONS]

Required arguments:
  <server_url>   The URL of the Ampache server
  <username>     The username for authentication
  <password>     The password for authentication

Optional arguments:
  -l <limit>     Limit the number of items to retrieve (default: 100)
  -f <filter>    Specify the filter for the items
  -j		     Prints the original json from the network response, when this is passed, all other optional args are ignored
  -h             Show this help message
  -d             Print the request url, useful for debugging
]])
end

-- Function to check if a value is valid (not nil, empty, or 'null')
local function isValid(value)
    return value ~= nil and value ~= '' and value ~= 'null' and tostring(value) ~= 'userdata: (nil)'
end

local function format_value(v)
    if type(v) == "number" and v % 1 == 0 then
        return string.format("%d", v)  -- remove .0
    else
        return tostring(v)  -- fallback
    end
end

-- Function to print only if valid
local function safePrint(label, value)
    if isValid(value) then
        print(string.format("%s %s", label, format_value(value)))
    end
end

function urlencode(str)
    return (str:gsub("([^%w%-%.%_~])", function(c)
        return string.format("%%%02X", string.byte(c))  -- Replace each non-URL-safe character with its encoded form
    end))
end

return {
    format_value = format_value,
    isValid = isValid,
    safePrint = safePrint,
    urlencode = urlencode,
    getUrl = getUrl,
    printHelp = printHelp,
    shouldPrintHelp = shouldPrintHelp,
    parseArgs = parseArgs
}
