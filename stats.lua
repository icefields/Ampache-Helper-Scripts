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

local ampache = require("ampache-common")
local handshake = require("ampache-handshake")
local ampacheHttp = require("ampache-http")

-- Default values for optional arguments
local limit = 10  -- Default limit
local type_value = "album"  -- Default type
local filter_value = "newest"  -- Default filter
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
  -l <limit>     Limit the number of items to retrieve (default: 10)
  -t <type>      Specify the type of items to retrieve (valid values: album, song, artist, video, playlist, podcast, podcast_episode; default: album)
  -f <filter>    Specify the filter for the items (valid values: newest, highest, frequent, recent, forgotten, flagged, random; default: newest)
  -j		     Prints the original json from the network response, when this is passed, all other optional args are ignored
  -h             Show this help message
]])
end

local function safePrint(title, value)
    ampache.safePrint(title, value)
end

if (ampache.shouldPrintHelp()) then
    printHelp()
    return
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
    elseif arg_val == "-t" then
        -- Type argument
        type_value = arg[i + 1] or "album"
        -- Validate type value
        local valid_types = {
            album = true,
            song = true,
            artist = true,
            video = true,
            playlist = true,
            podcast = true,
            podcast_episode = true
        }
        if not valid_types[type_value] then
            error("Invalid type specified. Valid values are: album, song, artist, video, playlist, podcast, podcast_episode.")
        end
        i = i + 1  -- Skip the next argument
    elseif arg_val == "-f" then
        -- Filter argument
        filter_value = arg[i + 1] or "newest"
        -- Validate filter value
        local valid_filters = {
            newest = true,
            highest = true,
            frequent = true,
            recent = true,
            forgotten = true,
            flagged = true,
            random = true
        }
        if not valid_filters[filter_value] then
            error("Invalid filter specified. Valid values are: newest, highest, frequent, recent, forgotten, flagged, random.")
        end
        i = i + 1  -- Skip the next argument
    elseif arg_val == "-j" then
	is_json_output = true
    end
end

local authToken = handshake.getAuthToken(server_url, username, password)
local url = string.format(
    "%s/server/json.server.php?action=stats&limit=%d&filter=%s&exact=0&offset=0&type=%s&show_dupes=1&auth=%s",
    server_url, limit, filter_value, type_value, authToken
)

local res, code, response_headers, status, json_response, data =
    ampacheHttp.makeRequestFromUrl(url)

-- Check if the request was successful
if code == 200 then
    -- if the -j option is passed, just print the json file
    if is_json_output == true then
    	print(json_response)
	    return
    end

    for _, item in ipairs(data[type_value]) do
        -- Print name if valid
        safePrint("name", string.format("%s (id: %s)", item.name, item.id))

        -- Print artist name if valid
        if item.artist then
            safePrint("artist", string.format("%s (id: %s)", item.artist.name, item.artist.id))
        end

        -- Print album name if valid
        if item.album then
            safePrint("album", string.format("%s (id: %s)", item.album.name, item.album.id))
        end

        -- print song url if available
        safePrint("url", item.url)
        
        -- Print time if valid
        safePrint("time", item.time)

        -- fields for song 
        safePrint("playlisttrack", item.playlisttrack)
        safePrint("format", item.format)
        safePrint("stream_format", item.stream_format)
        safePrint("stream_mime", item.stream_mime)
        safePrint("bitrate", item.bitrate)
        safePrint("stream_bitrate", item.stream_bitrate)
        safePrint("rate", item.rate)
        safePrint("mode", item.mode)
        safePrint("mime", item.mime)
        safePrint("stream_mime", item.stream_mime)

        -- Print year if valid
        safePrint("year", item.year)

        -- Print songcount if valid
        safePrint("songcount", item.songcount)

        -- Print diskcount if valid
        safePrint("diskcount", item.diskcount)

        -- Print genre if valid
        if item.genre and item.genre[1] then
            safePrint("genre", item.genre[1].name)  -- Assuming the first genre is the main one
        end

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

        -- Print mbid if valid
        safePrint("mbid", item.mbid)

        print("\n")  -- Add a blank line between items
    end
else
    -- Print an error message if the request fails
    print("HTTP request failed with status: " .. status)
end

