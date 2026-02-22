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

local common = require("ampache-common")
local client = require("ampache-client")
local view = require("ampache-view")

if (common.shouldPrintHelp()) then
    common.printHelp("similar.lua")
    return
end

local args = common.parseArgs(arg)

-- Validate type value
if args.type ~= "song" and args.type ~= "artist" then
    error("Invalid type specified. Valid values are: song, artist")
end

local api = client.new(args.server_url, args.username, args.password)
local res, code, response_headers, status, json_response, data = api:get_similar(args)

if code == 200 then
    if args.is_json_output == true then
        print(json_response)
        return
    end
    view.similar(data, args.type)
else
    view.error(status)
end
