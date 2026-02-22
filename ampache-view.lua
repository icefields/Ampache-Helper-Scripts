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
----     Presentation Layer for Ampache Data    -----
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

local common = require("ampache-common")

local view = {}

-- Helper to print a separator
local function separator()
    print("\n")
end

function view.albums(data)
    if not data or not data["album"] then
        print("No album data found in response")
        return
    end

    for _, item in ipairs(data["album"]) do
        common.safePrint(item.artist.name .. " -", item.name)
        common.safePrint("id:", item.id)
        common.safePrint("Time:", item.time)
        common.safePrint("Year:", item.year)
        common.safePrint("Songcount:", item.songcount)

        if item.art and item.has_art then
            common.safePrint("Art:", item.art)
        end

        separator()
    end
end

function view.artists(data)
    if not data or not data["artist"] then
        print("No artist data found in response")
        return
    end

    for _, item in ipairs(data["artist"]) do
        common.safePrint("name", item.name)
        common.safePrint("id", item.id)
        common.safePrint("albums", item.albums)
        common.safePrint("songcount", item.songcount)

        if item.art and item.has_art then
            common.safePrint("art", item.art)
        end

        separator()
    end
end

function view.songs(data)
    if not data or not data["song"] then
        print("No song data found in response")
        return
    end

    for _, item in ipairs(data["song"]) do
        common.safePrint(item.artist.name, item.title)

        if item.url then
            print(item.url)
        end

        if item.album and item.album.name then
            print(item.album.name)
        end

        if item.art and item.has_art then
            print(item.art)
        end

        separator()
    end
end

function view.playlists(data)
    if not data or not data["playlist"] then
        print("No playlist data found in response")
        return
    end

    for _, item in ipairs(data["playlist"]) do
        common.safePrint("name", string.format("%s (id: %s)", item.name, item.id))
        if item.owner then
            common.safePrint("owner", item.owner)
        end
        if item.items then
            common.safePrint("items", item.items)
        end
        common.safePrint("type", item.type)
        common.safePrint("last_update", item.last_update)
        if item.has_art then
            common.safePrint("art", item.art)
        end
        common.safePrint("flag", item.flag)
        common.safePrint("rating", item.rating)
        common.safePrint("averagerating", item.averagerating)

        separator()
    end
end

function view.stats(data, type)
    if not data or not data[type] then
        print("No " .. type .. " data found in response")
        return
    end

    for _, item in ipairs(data[type]) do
        -- Print name if valid
        common.safePrint("name", string.format("%s (id: %s)", item.name, item.id))

        -- Print artist name if valid
        if item.artist then
            common.safePrint("artist", string.format("%s (id: %s)", item.artist.name, item.artist.id))
        end

        -- Print album name if valid
        if item.album then
            common.safePrint("album", string.format("%s (id: %s)", item.album.name, item.album.id))
        end

        -- print song url if available
        common.safePrint("url", item.url)
        
        -- Print time if valid
        common.safePrint("time", item.time)

        -- fields for song 
        common.safePrint("playlisttrack", item.playlisttrack)
        common.safePrint("format", item.format)
        common.safePrint("stream_format", item.stream_format)
        common.safePrint("stream_mime", item.stream_mime)
        common.safePrint("bitrate", item.bitrate)
        common.safePrint("stream_bitrate", item.stream_bitrate)
        common.safePrint("rate", item.rate)
        common.safePrint("mode", item.mode)
        common.safePrint("mime", item.mime)
        common.safePrint("stream_mime", item.stream_mime)

        -- Print year if valid
        common.safePrint("year", item.year)

        -- Print songcount if valid
        common.safePrint("songcount", item.songcount)

        -- Print diskcount if valid
        common.safePrint("diskcount", item.diskcount)

        -- Print genre if valid
        if item.genre and item.genre[1] then
            common.safePrint("genre", item.genre[1].name)  -- Assuming the first genre is the main one
        end

        -- Print art if valid and has_art is true
        if item.has_art then
            common.safePrint("art", item.art)
        end

        -- Print flag if valid
        common.safePrint("flag", item.flag)

        -- Print rating if valid
        common.safePrint("rating", item.rating)

        -- Print averagerating if valid
        common.safePrint("averagerating", item.averagerating)

        -- Print mbid if valid
        common.safePrint("mbid", item.mbid)

        separator()
    end
end

function view.song(item)
    if not item then
        print("No song data found in response")
        return
    end

    common.safePrint(item.artist.name .. " -", item.title)
    common.safePrint("Song Url:", item.url)
    common.safePrint("Album:", item.album.name)
    if item.art and item.has_art then
        common.safePrint("art:", item.art)
    end
    separator()
end

function view.similar(data, item_type)
    if not data or not data[item_type] then
        print("No " .. item_type .. " items found in response")
        return
    end

    for _, item in ipairs(data[item_type]) do
        if item_type == "artist" then
            common.safePrint("name", item.name)
            common.safePrint("id", item.id)
            common.safePrint("albums", item.albums)
            common.safePrint("songcount", item.songcount)
        elseif item_type == "song" then
            common.safePrint("title", item.title)
            common.safePrint("id", item.id)
            common.safePrint("artist", item.artist.name)
            common.safePrint("album", item.album.name)
        end

        if item.art and item.has_art then
            common.safePrint("art", item.art)
        end

        separator()
    end
end

function view.error(status)
    print("HTTP request failed with status: " .. (status or "Unknown"))
end

return view
