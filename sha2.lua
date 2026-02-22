-- main.lua in a LÖVE2D project
local ampache = require("ampache-client")

function love.load()
    -- Configure the client
    local server = "https://your-ampache-server.com"
    local user = "username"
    local pass = "password"

    -- Create the client instance
    local client = ampache.new(server, user, pass)

    -- Make a request (this will block the game loop, so do it in a thread or loading screen)
    local res, code, headers, status, json, data = client:albums({ limit = 5 })

    if code == 200 then
        print("Found " .. #data.album .. " albums")
        for _, album in ipairs(data.album) do
            print(album.name)
        end
    else
        print("Error: " .. status)
    end
end
