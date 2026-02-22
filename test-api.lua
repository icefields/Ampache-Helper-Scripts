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
----     Automated API Test Script              -----
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

local ampacheHttp = require("ampache-http")
local apiMethods = require("ampache-api-methods")
local cjson = require("cjson")

-- Configuration
local config = {
    serverUrl = nil,
    username = nil,
    password = nil
}

-- Test Results
local results = {
    passed = 0,
    failed = 0,
    skipped = 0,
    total = 0
}

-- Helper to print colored output (optional, works in most terminals)
local function printStatus(status, msg)
    local color = ""
    if status == "PASS" then color = "\27[32m" -- Green
    elseif status == "FAIL" then color = "\27[31m" -- Red
    elseif status == "SKIP" then color = "\27[33m" -- Yellow
    elseif status == "INFO" then color = "\27[34m" -- Blue
    end
    print(string.format("%s[%-5s]\27[0m %s", color, status, msg))
end

-- Wrapper to make a request and check for success
local function testCall(actionName, params, expectSuccess)
    results.total = results.total + 1
    local args = {
        action = actionName,
        server_url = config.serverUrl,
        username = config.username,
        password = config.password
    }
    
    -- Merge params
    for k, v in pairs(params or {}) do args[k] = v end
    
    -- Returns: res, code, headers, status, jsonStr, data
    local success, res, code, headers, status, jsonStr, data = pcall(ampacheHttp.makeRequest, args, false)
    
    if not success then
        -- res contains the error message
        results.failed = results.failed + 1
        printStatus("FAIL", string.format("%s - Execution Error: %s", actionName, tostring(res)))
        return nil
    end
    
    -- Check result
    -- We consider it a pass if we get a 200 and valid JSON (data), or if we expect failure and get one.
    local passed = false
    local reason = ""
    
    if code == 200 and data then
        if expectSuccess == false then
            passed = false -- Expected failure but got success? Maybe API logic changed.
            reason = "Expected failure but succeeded"
        else
            passed = true
        end
    else
        if expectSuccess == false then
            passed = true -- Expected failure and got non-200/error
        else
            reason = status or ("HTTP " .. tostring(code))
        end
    end
    
    if passed then
        results.passed = results.passed + 1
        printStatus("PASS", actionName)
        return data
    else
        results.failed = results.failed + 1
        printStatus("FAIL", string.format("%s - %s", actionName, reason))
        return nil
    end
end

-- Skip list: Methods that are destructive or require specific setup not suitable for automated testing
local skipList = {
    ["handshake"] = "Internal method handled by library",
    ["goodbye"] = "Invalidates session, breaking subsequent tests",
    ["user_delete"] = "Destructive",
    ["user_create"] = "Destructive",
    ["user_edit"] = "Destructive",
    ["playlist_create"] = "Destructive",
    ["playlist_delete"] = "Destructive",
    ["playlist_add_song"] = "Destructive",
    ["playlist_remove_song"] = "Destructive",
    ["catalog_add"] = "Destructive",
    ["catalog_delete"] = "Destructive",
    ["catalog_action"] = "Destructive/Long running",
    ["register"] = "Destructive",
    ["scrobble"] = "Destructive (writes history)",
    ["record_play"] = "Destructive (writes history)",
    ["rate"] = "Destructive (modifies data)",
    ["flag"] = "Destructive (modifies data)",
    ["bookmark_create"] = "Destructive",
    ["bookmark_delete"] = "Destructive",
    ["bookmark_edit"] = "Destructive",
    ["download"] = "Binary data, not JSON API test",
    ["stream"] = "Binary data, not JSON API test",
    ["localplay"] = "Requires hardware/setup",
    ["democratic"] = "Requires specific setup",
    ["system_update"] = "Destructive/Long running",
    ["update_art"] = "Destructive",
    ["update_artist_info"] = "Destructive",
    ["update_from_tags"] = "Destructive",
    ["update_podcast"] = "Destructive/Long running",
    ["podcast_create"] = "Destructive",
    ["podcast_delete"] = "Destructive",
    ["podcast_episode_delete"] = "Destructive",
    ["preference_create"] = "Destructive",
    ["preference_delete"] = "Destructive",
    ["preference_edit"] = "Destructive",
    ["share_create"] = "Destructive",
    ["share_delete"] = "Destructive",
    ["share_edit"] = "Destructive",
    ["live_stream_create"] = "Destructive",
    ["live_stream_delete"] = "Destructive",
    ["live_stream_edit"] = "Destructive",
    ["song_delete"] = "Destructive",
    ["lost_password"] = "Side effects (email)",
    ["toggle_follow"] = "Destructive",
    
    -- Methods requiring complex parameters not easily automated
    ["advanced_search"] = "Requires complex rule parameters",
    ["search_group"] = "Requires complex rule parameters",
    ["url_to_song"] = "Requires valid URL input",
    ["catalog_file"] = "Requires file path input",
    ["catalog_folder"] = "Requires folder path input",
    
    -- Admin methods (often fail with regular user permissions)
    ["system_preference"] = "Requires admin privileges",
    ["system_preferences"] = "Requires admin privileges"
}

-- Helper to safely extract the first ID from a response
local function getFirstId(data, key)
    if not data then return nil end
    local list = data[key]
    if not list then return nil end
    if type(list) ~= "table" then return nil end
    
    -- Check if it's an array (has [1]) or a single object (has .id)
    if list[1] and list[1].id then
        return list[1].id
    elseif list.id then
        return list.id
    end
    return nil
end

local function runTests()
    printStatus("INFO", "Starting API Tests...")
    printStatus("INFO", "Connecting to " .. config.serverUrl)
    
    -- 1. Test Handshake (Implicitly tested via auth, but we can test ping)
    testCall("ping", {})
    
    -- 2. Test List Methods (Get data to use for subsequent tests)
    local artistsData = testCall("artists", {limit = 1})
    local albumsData = testCall("albums", {limit = 1})
    local songsData = testCall("songs", {limit = 1})
    local playlistsData = testCall("playlists", {limit = 1})
    
    -- Extract IDs for specific tests
    local artistId = getFirstId(artistsData, "artist")
    local albumId = getFirstId(albumsData, "album")
    local songId = getFirstId(songsData, "song")
    local playlistId = getFirstId(playlistsData, "playlist")
    
    if not artistId then printStatus("INFO", "No artists found on server. Some tests will be skipped.") end
    if not songId then printStatus("INFO", "No songs found on server. Some tests will be skipped.") end
    
    -- 3. Iterate all methods
    for name, def in pairs(apiMethods.methods) do
        if skipList[name] then
            results.skipped = results.skipped + 1
            results.total = results.total + 1 -- Count skipped in total
            printStatus("SKIP", name .. " (" .. skipList[name] .. ")")
        else
            -- Dynamic testing based on requirements
            local params = {}
            local canTest = true
            
            -- Check if we have required IDs
            if def.required then
                for _, req in ipairs(def.required) do
                    if req == "filter" then
                        -- 'filter' usually means ID for single-item methods
                        if name == "artist" then params.filter = artistId
                        elseif name == "album" then params.filter = albumId
                        elseif name == "song" then params.filter = songId
                        elseif name == "playlist" then params.filter = playlistId
                        elseif name == "playlist_songs" then params.filter = playlistId
                        elseif name == "artist_albums" then params.filter = artistId
                        elseif name == "artist_songs" then params.filter = artistId
                        elseif name == "album_songs" then params.filter = albumId
                        elseif name == "genre" then params.filter = "1" -- Guess
                        elseif name == "user" then params.filter = config.username
                        elseif name == "user_preference" then params.filter = "language" -- Guess
                        elseif name == "bookmark" then params.filter = "1" -- Guess, likely to fail but valid param
                        else
                            -- If we don't have a specific ID, try to skip or use generic
                            if not params.filter then
                                -- For methods like 'get_indexes' or 'advanced_search', filter might be optional in practice or string
                                if name == "get_indexes" or name == "index" or name == "list" then
                                     params.filter = "" -- Often optional or accepts empty
                                else
                                     canTest = false
                                end
                            end
                        end
                    elseif req == "id" then
                         if name == "rate" or name == "flag" then 
                             params.id = songId 
                             params.type = "song" 
                             if name == "rate" then params.rating = 5 end
                             if name == "flag" then params.flag = 1 end
                         elseif name == "get_art" then
                             params.id = songId
                             params.type = "song"
                         else
                             params.id = songId -- Fallback
                         end
                    elseif req == "type" then
                        params.type = "song" -- Default to song for tests
                    elseif req == "username" then
                        params.username = config.username
                    end
                end
            end
            
            -- Special handling for specific methods
            if name == "stats" then
                params.type = "song" -- Stats usually requires a type to be useful
            end
            
            -- If we assigned a nil ID (because the server is empty), skip the test
            if params.id == nil and def.required then
                for _, req in ipairs(def.required) do
                    if req == "id" then
                        canTest = false
                        break
                    end
                end
            end
            
            if canTest then
                -- Add limit to list methods to reduce load
                if not params.limit and (name:sub(1, 4) ~= "get_" and name ~= "song" and name ~= "album" and name ~= "artist") then
                    params.limit = 1
                end
                
                testCall(name, params)
            else
                results.skipped = results.skipped + 1
                results.total = results.total + 1
                printStatus("SKIP", name .. " (Missing required ID for test)")
            end
        end
    end
    
    print("\n-----------------------------------------")
    print("Test Summary:")
    print(string.format("  Total:  %d", results.total))
    print(string.format("  \27[32mPassed: %d\27[0m", results.passed))
    print(string.format("  \27[31mFailed: %d\27[0m", results.failed))
    print(string.format("  \27[33mSkipped: %d\27[0m", results.skipped))
    print("-----------------------------------------")
end

-- Main Entry Point
local function main()
    if not arg[1] or not arg[2] or not arg[3] then
        print("Usage: lua test-api.lua <server_url> <username> <password>")
        print("Example: lua test-api.lua https://music.example.com user pass")
        return
    end
    
    config.serverUrl = arg[1]
    config.username = arg[2]
    config.password = arg[3]
    
    -- Remove trailing slash from URL if present
    if config.serverUrl:sub(-1) == "/" then
        config.serverUrl = config.serverUrl:sub(1, -2)
    end
    
    runTests()
end

main()
