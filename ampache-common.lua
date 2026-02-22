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

local function shouldPrintHelp()
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

local function parseArgs(arg)
    local args = {}
    
    args.server_url = arg[1]
    args.username = arg[2]
    args.password = arg[3]

    -- Default values
    args.limit = 100
    args.filter = ""
    args.type = ""
    args.offset = 0
    args.exact = 0
    args.show_dupes = 1
    args.is_json_output = false
    args.is_print_url = false
    args.include = nil
    args.hide_search = nil
    args.add = nil
    args.update = nil
    args.cond = nil
    args.sort = nil
    args.username_data = nil -- For stats specific username

    -- Parse the command-line arguments
    for i = 4, #arg do
        local arg_val = arg[i]
        if arg_val == "-l" then
            args.limit = tonumber(arg[i + 1]) or 100
            i = i + 1
        elseif arg_val == "-f" then
            args.filter = arg[i + 1] or ""
            i = i + 1
        elseif arg_val == "-t" then
            args.type = arg[i + 1] or ""
            i = i + 1
        elseif arg_val == "-i" then
            args.include = arg[i + 1]
            i = i + 1
        elseif arg_val == "-j" then
            args.is_json_output = true
        elseif arg_val == "-d" then
            args.is_print_url = true
        elseif arg_val == "-o" then
            args.offset = tonumber(arg[i + 1]) or 0
            i = i + 1
        elseif arg_val == "-e" then
            args.exact = tonumber(arg[i + 1]) or 0
            i = i + 1
        elseif arg_val == "-s" then
            args.show_dupes = tonumber(arg[i + 1]) or 1
            i = i + 1
        elseif arg_val == "-u" then
            args.username_data = arg[i + 1]
            i = i + 1
        elseif arg_val == "--hide-search" then
            args.hide_search = tonumber(arg[i + 1]) or 1
            i = i + 1
        elseif arg_val == "--add" then
            args.add = arg[i + 1]
            i = i + 1
        elseif arg_val == "--update" then
            args.update = arg[i + 1]
            i = i + 1
        elseif arg_val == "--cond" then
            args.cond = arg[i + 1]
            i = i + 1
        elseif arg_val == "--sort" then
            args.sort = arg[i + 1]
            i = i + 1
        end
    end

    return args
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
  -t <type>      Type
  -i <include>   Include related data (e.g., songs for albums)
  -j             Prints the original json from the network response
  -d             Print the request url, useful for debugging
  -o <offset>    Set the offset for pagination (default: 0)
  -e <exact>     Set exact match flag (0 or 1, default: 0)
  -s <show_dupes> Show duplicate items (0 or 1, default: 1)
  -u <username>  Username for stats (specific to stats action)
  --hide-search <0|1> Hide search results
  --add <date>   ISO 8601 Date Format (e.g. 2020-09-16)
  --update <date> ISO 8601 Date Format
  --cond <string> Additional filters (e.g. 'filter1,value1')
  --sort <string> Sort name or comma-separated key pair
  -h             Show this help message
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

local function urlencode(str)
    return (str:gsub("([^%w%-%.%_~])", function(c)
        return string.format("%%%02X", string.byte(c))  -- Replace each non-URL-safe character with its encoded form
    end))
end

local function fileExists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    else
        return false
    end
end

local function isFileEmpty(path)
    local f = io.open(path, "r")
    if not f then return true end  -- file doesn't exist
    local size = f:seek("end")
    f:close()
    return size == 0
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")  -- read entire file
    f:close()
    return content
end

local function writeFile(path, string)
    local file = io.open(path, "w")
    file:write(string)
    file:close()
end

return {
    format_value = format_value,
    isValid = isValid,
    safePrint = safePrint,
    urlencode = urlencode,
    printHelp = printHelp,
    shouldPrintHelp = shouldPrintHelp,
    parseArgs = parseArgs,
    fileExists = fileExists,
    isFileEmpty = isFileEmpty,
    readFile = readFile,
    writeFile = writeFile
}
