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

local common = require("ampache-common")
local client = require("ampache-client")
local view = require("ampache-view")

-- Default values for optional arguments
local valid_types = {
    album = true,
    song = true,
    artist = true,
    video = true,
    playlist = true,
    podcast = true,
    podcast_episode = true
}

local valid_filters = {
    newest = true,
    highest = true,
    frequent = true,
    recent = true,
    forgotten = true,
    flagged = true,
    random = true
}

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
  -t <type>      Specify the type of items to retrieve (valid values: album, song, artist, video, playlist, podcast, podcast_episode; default: album)
  -f <filter>    Specify the filter for the items (valid values: newest, highest, frequent, recent, forgotten, flagged, random; default: newest)
  -u <username>  Specify a username to get the stats for
  -j             Prints the original json from the network response, when this is passed, all other optional args are ignored
  -d             Print the request url, useful for debugging
  -h             Show this help message
]])
end

if (common.shouldPrintHelp()) then
    printHelp()
    return
end

local args = common.parseArgs(arg)

-- Override defaults with parsed args
args.limit = args.limit or 10
args.type = args.type or "album"
args.filter = args.filter or "newest"

-- Validate type value
if not valid_types[args.type] then
    error("Invalid type specified. Valid values are: album, song, artist, video, playlist, podcast, podcast_episode.")
end

-- Validate filter value
if not valid_filters[args.filter] then
    error("Invalid filter specified. Valid values are: newest, highest, frequent, recent, forgotten, flagged, random.")
end

local api = client.new(args.server_url, args.username, args.password)
local res, code, response_headers, status, json_response, data = api:stats(args)

if code == 200 then
    if args.is_json_output == true then
        print(json_response)
        return
    end
    view.stats(data, args.type)
else
    view.error(status)
end
