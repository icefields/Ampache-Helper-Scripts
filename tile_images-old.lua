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
-- ---- Helper script to tile ampache images ----- --
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

local socket = require("socket.http")
local ltn12 = require("ltn12")
local lfs = require("lfs")

-- Function to download image from URL and save it locally
local function download_image(url, filename)
    local file, err = io.open(filename, "wb")
    if not file then
        error("Failed to open file: " .. err)
    end

    local response_body = {}
    local _, code = socket.request{
        url = url,
        sink = ltn12.sink.table(response_body)
    }

    if code ~= 200 then
        file:close()
        error("Failed to download " .. url .. ": HTTP code " .. code)
    end

    file:write(table.concat(response_body))
    file:close()
end

-- Function to split a string by a given delimiter
local function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

-- function to tile the images from the urls parameter in a single image
-- commaSeparated boolean that indicates if the urls are a single comma 
--  separated string or an array of strings
local function tileImages(urlList, commaSeparated)
    local urls
    if (commaSeparated) then
        urls = split(urlList, ",")
    elseif type(myVariable) == "table" then
        urls = urlList
    end

    -- Create a directory to store downloaded images
    local img_dir = "images"
    if not lfs.attributes(img_dir, "mode") then
        lfs.mkdir(img_dir)
    end

    -- Check if at least one URL is provided
    if #urls == 0 then
        error("No URLs provided. Usage: lua tile_images.lua <url1> <url2> ... <urlN>")
    end

    -- Determine the number of images
    local num_images = #urls

    -- Calculate the dimensions of the grid
    local grid_size = math.ceil(math.sqrt(num_images))
    local num_rows = grid_size
    local num_cols = grid_size

    -- Download images
    for i, url in ipairs(urls) do
        local filename = img_dir .. "/image" .. i .. ".jpg"
        download_image(url, filename)
    end

    -- Prepare the ImageMagick montage command
    local command = "montage"
    for i = 1, num_images do
        local filename = img_dir .. "/image" .. i .. ".jpg"
        command = command .. " " .. filename
    end
    command = command .. " -tile " .. num_cols .. "x" .. num_rows .. " -geometry +0+0 tiled_image.jpg"

    -- Execute the command to tile images
    os.execute(command)

    -- Remove temporary image files
    for i = 1, num_images do
        local filename = img_dir .. "/image" .. i .. ".jpg"
        os.remove(filename)
    end

end

-- Parse command line arguments
if arg[1] == "-t" then
    -- Get URLs from command line arguments
    tileImages(arg[2], true)
end

return {
    tileImages = tileImages
}

