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
-- ----- Script to print a collage of album ------ --
-- ----- from Ampache. --------------------------- --
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

local tile_images = require("tile_images")
local handshake = require("ampache-handshake")
local print_arts = require("print-arts")

local function contains(array, element)
    for _, value in ipairs(array) do
        if value == element then
            return true
        end
    end
    return false
end


local helpMessage = "Usage: lua arts-collage.lua [-s | -h | -f]  <server.url> <username> <password>"
-- Check the number of command-line arguments
if #arg < 3 then
    error(helpMessage)
end

local validOptions = {
    ["-s"] = 16,
    ["-f"] = "recent",
    ["-h"] = false,
    ["--help"] = false
}
local isAnyOption = false
local values = {}
local argsToIgnore = {}
for i, currArg in ipairs(arg) do
    if currArg:sub(1, 2) == "-s" and validOptions[ currArg:sub(1, 2) ] ~= nil then
        validOptions[currArg] = arg[i+1]
        table.insert(argsToIgnore, i+1)
        isAnyOption = true
    elseif currArg:sub(1, 2) == "-f" then
        validOptions[currArg] = arg[i+1]
        table.insert(argsToIgnore, i+1)
        isAnyOption = true
    elseif not contains(argsToIgnore, i) then
        table.insert(values, currArg)
    end
end


local server_url = values[1]
local username = values[2]
local password = values[3]

local authToken = handshake.getAuthToken(server_url, username, password)
local reqUrl = server_url.."/server/json.server.php?action=stats&type=album&limit="..validOptions["-s"].."&filter="..validOptions["-f"].."&exact=1&offset=0&hide_search=0&show_dupes=1&auth="..authToken.."&username="..username
local artList = print_arts.artUrls(reqUrl, false)
tile_images.tileImages(artList, true)

