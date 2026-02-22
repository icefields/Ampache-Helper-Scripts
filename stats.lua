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
local ampacheHttp = require("ampache-http")

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

if (ampache.shouldPrintHelp()) then
    printHelp()
    return
end

local args = ampache.parseArgs(arg)

-- Override defaults with parsed args
args.limit = args.limit or 10
args.type = args.type or "album"
args.filter = args.filter or "newest"
args.action = "stats"

-- Validate type value
if not valid_types[args.type] then
    error("Invalid type specified. Valid values are: album, song, artist, video, playlist, podcast, podcast_episode.")
end

-- Validate filter value
if not valid_filters[args.filter] then
    error("Invalid filter specified. Valid values are: newest, highest, frequent, recent, forgotten, flagged, random.")
end

local res, code, response_headers, status, json_response, data =
    ampacheHttp.makeRequest(args, args.is_print_url)

-- Check if the request was successful
if code == 200 then
    -- if the -j option is passed, just print the json file
    if args.is_json_output == true then
    	print(json_response)
	    return
    end

    -- Check if the response contains data for the specified type
    if not data[args.type] then
        print("No " .. args.type .. " data found in response")
        return
    end

    for _, item in ipairs(data[args.type]) do
        -- Print name if valid
        ampache.safePrint("name", string.format("%s (id: %s)", item.name, item.id))

        -- Print artist name if valid
        if item.artist then
            ampache.safePrint("artist", string.format("%s (id: %s)", item.artist.name, item.artist.id))
        end

        -- Print album name if valid
        if item.album then
            ampache.safePrint("album", string.format("%s (id: %s)", item.album.name, item.album.id))
        end

        -- print song url if available
        ampache.safePrint("url", item.url)
        
        -- Print time if valid
        ampache.safePrint("time", item.time)

        -- fields for song 
        ampache.safePrint("playlisttrack", item.playlisttrack)
        ampache.safePrint("format", item.format)
        ampache.safePrint("stream_format", item.stream_format)
        ampache.safePrint("stream_mime", item.stream_mime)
        ampache.safePrint("bitrate", item.bitrate)
        ampache.safePrint("stream_bitrate", item.stream_bitrate)
        ampache.safePrint("rate", item.rate)
        ampache.safePrint("mode", item.mode)
        ampache.safePrint("mime", item.mime)
        ampache.safePrint("stream_mime", item.stream_mime)

        -- Print year if valid
        ampache.safePrint("year", item.year)

        -- Print songcount if valid
        ampache.safePrint("songcount", item.songcount)

        -- Print diskcount if valid
        ampache.safePrint("diskcount", item.diskcount)

        -- Print genre if valid
        if item.genre and item.genre[1] then
            ampache.safePrint("genre", item.genre[1].name)  -- Assuming the first genre is the main one
        end

        -- Print art if valid and has_art is true
        if item.has_art then
            ampache.safePrint("art", item.art)
        end

        -- Print flag if valid
        ampache.safePrint("flag", item.flag)

        -- Print rating if valid
        ampache.safePrint("rating", item.rating)

        -- Print averagerating if valid
        ampache.safePrint("averagerating", item.averagerating)

        -- Print mbid if valid
        ampache.safePrint("mbid", item.mbid)

        print("\n")  -- Add a blank line between items
    end
else
    -- Print an error message if the request fails
    print("HTTP request failed with status: " .. status)
end
