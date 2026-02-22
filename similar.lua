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
-- ------- Luci4 util print Ampache albums ------- --
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

-- setting the local path so the script can find dependencies
local script_path = debug.getinfo(1, "S").source:match("(.*/)") or ""
script_path = script_path:sub(2)  -- Removes the '@' at the beginning if it exists
local script_dir = script_path:match("(.+)/")  -- Get everything before the last '/'
script_dir = script_dir or ""  -- If no directory, make it an empty string
package.path = script_dir .. "/?.lua;" .. package.path

local ampache = require("ampache-common")
local ampacheHttp = require("ampache-http")

if (ampache.shouldPrintHelp()) then
    ampache.printHelp("similar.lua")
    return
end

local args = ampache.parseArgs(arg)
args.action = "get_similar"

-- Validate type value
if args.type ~= "song" and args.type ~= "artist" then
    error("Invalid type specified. Valid values are: song, artist")
end

local res, code, response_headers, status, json_response, data =
    ampacheHttp.makeRequest(args, args.is_print_url)

if code == 200 then
    -- if the -j option is passed, just print the json file
    if args.is_json_output == true then
    	print(json_response)
	    return
    end

    -- Check if the response contains the expected data type
    local items = data[args.type]
    if not items then
        print("No " .. args.type .. " items found in response")
        return
    end

    for _, item in ipairs(items) do
        if args.type == "artist" then
            ampache.safePrint("name", item.name)
            ampache.safePrint("id", item.id)
            ampache.safePrint("albums", item.albums)
            ampache.safePrint("songcount", item.songcount)
        elseif args.type == "song" then
            ampache.safePrint("title", item.title)
            ampache.safePrint("id", item.id)
            ampache.safePrint("artist", item.artist.name)
            ampache.safePrint("album", item.album.name)
        end

        if item.art and item.has_art then
            ampache.safePrint("art", item.art)
        end

        print("\n")  -- Add a blank line between items
    end
else
    print("HTTP request failed with status: " .. status)
end
