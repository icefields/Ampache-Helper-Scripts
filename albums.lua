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
    ampache.printHelp("albums.lua")
    return
end

local args = ampache.parseArgs(arg)
args.action = "albums"

local res, code, response_headers, status, json_response, data =
    ampacheHttp.makeRequest(args, args.is_print_url)

if code == 200 and data ~= nil then
    -- if the -j option is passed, just print the json file
    if args.is_json_output == true then
    	print(json_response)
	    return
    end

    for _, item in ipairs(data["album"]) do
        ampache.safePrint(item.artist.name .. " -", item.name)
        ampache.safePrint("id:", item.id)
        ampache.safePrint("Time:", item.time)
        ampache.safePrint("Year:", item.year)
        ampache.safePrint("Songcount:", item.songcount)

        if item.art and item.has_art then
            ampache.safePrint("Art:", item.art)
        end

        print("\n")  -- Add a blank line between items
    end
else
    print("HTTP request failed with status: " .. status)
end
