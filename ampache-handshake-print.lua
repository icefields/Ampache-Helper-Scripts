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
-- -------- Helper script for handshake  --------- --
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

local original_script = require("ampache-handshake")

local helpMessage = "Usage: lua ampache-handshake-print.lua [-h | --handshake | -a | --auth]  <server.url> <username> <password>"
-- Check the number of command-line arguments
if #arg < 3 then
    error(helpMessage)
end

local OPTION_DEFAULT = "-H"
local validOptions = {
    ["-H"] = false,
    ["--handshake"] = false,
    ["-a"] = false,
    ["--auth"] = false,
    ["-h"] = false,
    ["--help"] = false
}
local isAnyOption = false
local values = { }

for i, currArg in ipairs(arg) do
    if currArg:sub(1, 1) == "-" and validOptions[currArg] ~= nil then
        validOptions[currArg] = true
        isAnyOption = true
    else
        table.insert(values, currArg)
    end
end

if not isAnyOption then validOptions[OPTION_DEFAULT] = true end

local server_url = values[1]
local username = values[2]
local password = values[3]

if validOptions[OPTION_DEFAULT] or validOptions["--handshake"] then
    -- Call handshake and print JSON elements line by line
    local jsonResp = original_script.handshake(server_url, username, password)
    for key, value in pairs(jsonResp) do
        print(key .. ":", value)
    end
elseif validOptions["-a"] or validOptions["--auth"] then
    -- Call getAuthToken and print authentication token
    local auth_token = original_script.getAuthToken(server_url, username, password)
    print(auth_token)
elseif validOptions["-h"] or validOptions["--help"] then
    print(helpMessage)
end

