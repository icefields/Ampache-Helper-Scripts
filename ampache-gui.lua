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
-- ----     Ampache GUI using LGI (GTK)        -----
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

local lfs = require('lfs')
local http = require('socket.http')
local ltn12 = require('ltn12')

print("Initializing Ampache GUI...")

-- Initialize random seed
math.randomseed(os.time())

-- Setup package path to find local modules
local info = debug.getinfo(1, "S")
local script_path = info.source:match("^@(.+)") or info.source
local script_dir = script_path:match("^(.*[\\/])") or "."
package.path = script_dir .. "/?.lua;" .. package.path

-- Path for storing credentials
local config_path = script_dir .. "/ampache-config.lua"

-- Helper function to save configuration
local function save_config(url, user, pass)
    local file, err = io.open(config_path, "w")
    if file then
        file:write(string.format("return { url = %q, user = %q, password = %q }", url, user, pass))
        file:close()
        print("Credentials saved to " .. config_path)
    else
        print("Failed to save credentials to " .. config_path .. ": " .. tostring(err))
    end
end

-- Helper function to load configuration
local function load_config()
    local ok, data = pcall(dofile, config_path)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

-- Helper function to delete configuration
local function delete_config()
    os.remove(config_path)
    print("Credentials deleted.")
end

-- Load LGI and dependencies with error handling
local lgi_status, lgi = pcall(require, 'lgi')
if not lgi_status then
    print("Error: Failed to load LGI library.")
    print("Please ensure 'lgi' is installed correctly for your Lua version.")
    print("On Debian/Ubuntu: sudo apt install lua-lgi libgirepository1.0-dev")
    os.exit(1)
end

local Gtk_status, Gtk = pcall(function() return lgi.require('Gtk', '3.0') end)
if not Gtk_status then
    print("Error: Failed to load GTK 3.0.")
    print("This usually means the GTK introspection data is missing.")
    print("On Debian/Ubuntu: sudo apt install gir1.2-gtk-3.0")
    os.exit(1)
end

local Gdk_status, Gdk = pcall(function() return lgi.require('Gdk', '3.0') end)
if not Gdk_status then
    print("Error: Failed to load Gdk 3.0.")
    print("On Debian/Ubuntu: sudo apt install gir1.2-gtk-3.0")
    os.exit(1)
end

local GdkPixbuf_status, GdkPixbuf = pcall(function() return lgi.require('GdkPixbuf', '2.0') end)
if not GdkPixbuf_status then
    print("Error: Failed to load GdkPixbuf.")
    print("On Debian/Ubuntu: sudo apt install gir1.2-gdk-pixbuf-2.0")
    os.exit(1)
end

local GObject_status, GObject = pcall(function() return lgi.require('GObject', '2.0') end)
if not GObject_status then
    print("Error: Failed to load GObject.")
    os.exit(1)
end

local GLib_status, GLib = pcall(function() return lgi.require('GLib', '2.0') end)
if not GLib_status then
    print("Error: Failed to load GLib.")
    os.exit(1)
end

-- Load GStreamer for audio playback
local Gst_status, Gst = pcall(function() return lgi.require('Gst', '1.0') end)
local playbin = nil
local is_playing = false
local playback_queue = {}
local current_song_index = 0
local is_shuffle = false
local is_repeat = false
local progress_timeout_id = nil
local is_seeking = false

if Gst_status then
    print("GStreamer loaded successfully.")
    Gst.init(nil)
    playbin = Gst.ElementFactory.make('playbin', 'playbin')
    if not playbin then
        print("Warning: Could not create GStreamer playbin. Playback disabled.")
    else
        -- Setup Bus watch to catch errors and EOS
        local bus = playbin:get_bus()
        local watch_id = bus:add_watch(GLib.PRIORITY_DEFAULT, function(self, message)
            if message.type == Gst.MessageType.ERROR then
                local err, debug = message:parse_error()
                print("GStreamer Error: " .. tostring(err.message))
                if debug then print("Debug info: " .. debug) end
                playbin.state = Gst.State.NULL
                is_playing = false
                if progress_timeout_id then GLib.source_remove(progress_timeout_id) end
            elseif message.type == Gst.MessageType.EOS then
                print("Playback finished.")
                play_next_song()
            end
            return true -- Keep the watch active
        end)
        
        if not watch_id then
            print("Warning: Failed to add GStreamer bus watch. Errors will not be reported.")
        end
    end
else
    print("Warning: GStreamer (Gst 1.0) not found. Audio playback will be disabled.")
    print("On Debian/Ubuntu: sudo apt install gir1.2-gst-plugins-base-1.0 gstreamer1.0-plugins-good")
end

local client = require("ampache-client")

local App = Gtk.Application()
App.application_id = 'com.github.icefields.ampache-gui'

local api_client = nil
local main_window = nil

-- UI Elements for Player
local player_bar = nil
local play_pause_button = nil
local prev_button = nil
local next_button = nil
local song_label = nil
local shuffle_button = nil
local repeat_button = nil
local progress_scale = nil
local current_time_label = nil
local total_time_label = nil

-- UI Elements for Navigation
local main_stack = nil
local stack_switcher = nil
local back_button = nil
local header_bar = nil

-- Helper function to download an image
local function download_image(url, filename)
    local file, err = io.open(filename, "wb")
    if not file then 
        return nil, err 
    end
    local response_body = {}
    local res, code = http.request{
        url = url,
        sink = ltn12.sink.table(response_body)
    }
    if not res then
         file:close()
         return nil, code
    end
    
    if code ~= 200 then
        file:close()
        return nil, "HTTP code " .. code
    end
    file:write(table.concat(response_body))
    file:close()
    return filename
end

-- Helper to format time (seconds to M:SS)
local function format_time(seconds)
    if not seconds or type(seconds) ~= "number" then return "--:--" end
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

-- Helper to escape Pango markup
local function escape_markup(text)
    if not text then return "" end
    return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

-- Playback Logic
local function update_player_ui()
    if not playbin then return end
    
    local current_song = playback_queue[current_song_index]
    if current_song then
        local title = escape_markup(current_song.title or "Unknown")
        local artist = escape_markup(current_song.artist and current_song.artist.name or "Unknown")
        song_label.label = string.format("<b>%s</b> - %s", title, artist)
        song_label.use_markup = true
        player_bar.visible = true
    else
        player_bar.visible = false
    end

    -- Update Play/Pause Icon
    if is_playing then
        play_pause_button.image = Gtk.Image { icon_name = "media-playback-pause-symbolic" }
    else
        play_pause_button.image = Gtk.Image { icon_name = "media-playback-start-symbolic" }
    end

    -- Update Shuffle/Repeat Icons
    if is_shuffle then
        shuffle_button.image = Gtk.Image { icon_name = "media-playlist-shuffle-symbolic" }
    else
        shuffle_button.image = Gtk.Image { icon_name = "media-playlist-consecutive-symbolic" } -- Or a dimmed version
    end

    if is_repeat then
        repeat_button.image = Gtk.Image { icon_name = "media-playlist-repeat-symbolic" }
    else
        repeat_button.image = Gtk.Image { icon_name = "media-playlist-normal-symbolic" } -- Or a dimmed version
    end
end

local function update_progress_bar()
    if not playbin or is_seeking then return true end -- Keep timer running
    
    local ok, position = playbin:query_position(Gst.Format.TIME)

    if ok and type(position) == "number" then
        local pos_sec = position / 1000000000
        progress_scale.adjustment.value = pos_sec
        current_time_label.label = format_time(pos_sec)
    end
    
    return true -- Continue timeout
end

local function play_song_at_index(index)
    if not playbin or index < 1 or index > #playback_queue then 
        if playbin then playbin.state = Gst.State.NULL end
        is_playing = false
        if progress_timeout_id then GLib.source_remove(progress_timeout_id) end
        update_player_ui()
        return 
    end

    current_song_index = index
    local song = playback_queue[index]
    
    if not api_client.auth or not api_client.server_url then
        print("Error: API client missing auth token or server URL.")
        return
    end

    print("Playing song ID: " .. tostring(song.id))
    
    playbin.state = Gst.State.NULL
    local stream_url = string.format("%s/play/index.php?ssid=%s&type=song&oid=%s", 
        api_client.server_url, api_client.auth, song.id)
    
    print("Stream URL: " .. stream_url)
    playbin.uri = stream_url
    playbin.state = Gst.State.PLAYING
    is_playing = true
    
    -- Set duration from metadata immediately
    local duration = song.time or 0
    total_time_label.label = format_time(duration)
    progress_scale.adjustment.upper = duration
    progress_scale.adjustment.value = 0
    current_time_label.label = "0:00"
    
    -- Start progress timer
    if progress_timeout_id then GLib.source_remove(progress_timeout_id) end
    progress_timeout_id = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, update_progress_bar)
    
    update_player_ui()
end

function play_next_song()
    if #playback_queue == 0 then
        if playbin then playbin.state = Gst.State.NULL end
        is_playing = false
        update_player_ui()
        return
    end

    local next_index = 0
    
    if is_shuffle then
        next_index = math.random(1, #playback_queue)
    else
        next_index = current_song_index + 1
        if next_index > #playback_queue then
            if is_repeat then
                next_index = 1
            else
                if playbin then playbin.state = Gst.State.NULL end
                is_playing = false
                update_player_ui()
                return
            end
        end
    end
    
    play_song_at_index(next_index)
end

function play_prev_song()
    if #playback_queue == 0 then return end
    
    -- Simple previous: just go back one index. 
    -- (Does not support history stack for shuffle)
    local prev_index = current_song_index - 1
    if prev_index < 1 then
        if is_repeat then
            prev_index = #playback_queue
        else
            prev_index = 1 -- Restart current or stop? Usually restart current or stop. Let's stop.
            if playbin then playbin.state = Gst.State.NULL end
            is_playing = false
            update_player_ui()
            return
        end
    end
    play_song_at_index(prev_index)
end

function toggle_play_pause()
    if not playbin then return end
    
    if is_playing then
        playbin.state = Gst.State.PAUSED
        is_playing = false
    else
        playbin.state = Gst.State.PLAYING
        is_playing = true
    end
    update_player_ui()
end

function toggle_shuffle()
    is_shuffle = not is_shuffle
    update_player_ui()
end

function toggle_repeat()
    is_repeat = not is_repeat
    update_player_ui()
end

-- Function to create the Main Window
local function create_main_window(app)
    print("Creating main window...")
    main_window = Gtk.ApplicationWindow {
        application = app,
        title = "Ampache",
        default_width = 900,
        default_height = 600,
    }

    -- Setup Header Bar
    header_bar = Gtk.HeaderBar {
        title = "Ampache",
        show_close_button = true,
        decoration_layout = "menu:close"
    }
    main_window:set_titlebar(header_bar)

    -- Back Button (initially hidden)
    back_button = Gtk.Button {
        image = Gtk.Image { icon_name = "go-previous-symbolic" },
        visible = false,
        tooltip_text = "Back"
    }
    header_bar:pack_start(back_button)

    -- Logout Button
    local logout_button = Gtk.Button {
        label = "Logout",
        tooltip_text = "Clear saved credentials and return to login"
    }
    header_bar:pack_end(logout_button)

    -- Main Vertical Box to hold content and player bar
    local main_box = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 0 }
    main_window.child = main_box

    -- Main Stack for navigation
    main_stack = Gtk.Stack { transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT }
    
    -- Stack Switcher (Tabs)
    stack_switcher = Gtk.StackSwitcher { stack = main_stack, halign = Gtk.Align.CENTER, margin = 5 }
    
    local content_box = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 0 }
    content_box:pack_start(stack_switcher, false, false, 0)
    content_box:pack_start(main_stack, true, true, 0)
    
    main_box:pack_start(content_box, true, true, 0)

    -- Player Bar
    player_bar = Gtk.ActionBar { visible = false }
    main_box:pack_start(player_bar, false, false, 0)

    prev_button = Gtk.Button {
        image = Gtk.Image { icon_name = "media-skip-backward-symbolic" },
        always_show_image = true,
        tooltip_text = "Previous"
    }
    
    play_pause_button = Gtk.Button {
        image = Gtk.Image { icon_name = "media-playback-start-symbolic" },
        always_show_image = true,
        tooltip_text = "Play/Pause"
    }
    
    next_button = Gtk.Button {
        image = Gtk.Image { icon_name = "media-skip-forward-symbolic" },
        always_show_image = true,
        tooltip_text = "Next"
    }

    shuffle_button = Gtk.Button {
        image = Gtk.Image { icon_name = "media-playlist-consecutive-symbolic" }, -- Icon changes based on state
        always_show_image = true,
        tooltip_text = "Toggle Shuffle"
    }

    repeat_button = Gtk.Button {
        image = Gtk.Image { icon_name = "media-playlist-normal-symbolic" }, -- Icon changes based on state
        always_show_image = true,
        tooltip_text = "Toggle Repeat"
    }

    song_label = Gtk.Label { 
        label = "Not Playing", 
        ellipsize = "END",
        halign = Gtk.Align.START,
        margin_start = 10
    }

    -- Progress Bar Area
    current_time_label = Gtk.Label { label = "0:00", margin_end = 5 }
    total_time_label = Gtk.Label { label = "0:00", margin_start = 5 }
    
    progress_scale = Gtk.Scale {
        orientation = Gtk.Orientation.HORIZONTAL,
        adjustment = Gtk.Adjustment { lower = 0, upper = 100, step_increment = 1, page_increment = 10, value = 0 },
        draw_value = false,
        hexpand = true
    }

    player_bar:pack_start(prev_button)
    player_bar:pack_start(play_pause_button)
    player_bar:pack_start(next_button)
    player_bar:pack_start(shuffle_button)
    player_bar:pack_start(repeat_button)
    player_bar:pack_start(song_label)
    
    -- Pack progress bar at the end or in a separate box?
    -- ActionBar puts items at start/end. Let's put time/progress in a center box.
    local progress_box = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 5, hexpand = true }
    progress_box:pack_start(current_time_label, false, false, 0)
    progress_box:pack_start(progress_scale, true, true, 0)
    progress_box:pack_start(total_time_label, false, false, 0)
    
    -- ActionBar doesn't have a 'center' area by default in Lua LGI easily, 
    -- but we can pack it as a regular widget if we use a Box instead of ActionBar.
    -- However, ActionBar is convenient. Let's just pack it at the end.
    player_bar:pack_end(progress_box) -- This might not align correctly visually.
    -- Actually, ActionBar packs start/end. Let's put controls at start, progress at end.
    
    -- Re-arranging:
    -- Start: Prev, Play, Next, Shuffle, Repeat, Song Label
    -- End: Time, Scale, Time
    
    -- Connect Player Buttons
    function prev_button:on_clicked() play_prev_song() end
    function play_pause_button:on_clicked() toggle_play_pause() end
    function next_button:on_clicked() play_next_song() end
    function shuffle_button:on_clicked() toggle_shuffle() end
    function repeat_button:on_clicked() toggle_repeat() end

    -- Seek Logic
    function progress_scale:on_button_press_event(event)
        is_seeking = true
        return false
    end

    function progress_scale:on_button_release_event(event)
        is_seeking = false
        if not playbin then return false end
        
        local value = progress_scale.adjustment.value
        local position_ns = value * 1000000000
        
        -- Seek to position
        playbin:seek(1.0, Gst.Format.TIME, Gst.SeekFlags.FLUSH + Gst.SeekFlags.KEY_UNIT, Gst.SeekType.SET, position_ns, Gst.SeekType.NONE, 0)
        return false
    end

    -- ==========================================
    -- PAGE: PLAYLISTS LIST (Moved to First)
    -- ==========================================
    local scrolled_playlists = Gtk.ScrolledWindow {}
    local playlist_flowbox = Gtk.FlowBox {
        valign = Gtk.Align.START,
        halign = Gtk.Align.START,
        column_spacing = 10,
        row_spacing = 10,
        margin = 10,
        min_children_per_line = 3,
        selection_mode = Gtk.SelectionMode.NONE
    }
    scrolled_playlists.child = playlist_flowbox
    main_stack:add_titled(scrolled_playlists, "playlists", "Playlists")

    local loading_playlists_label = Gtk.Label { label = "Loading playlists..." }
    playlist_flowbox:add(loading_playlists_label)
    
    -- Map to store playlist data
    local playlist_map = {}

    -- ==========================================
    -- PAGE: ALBUMS LIST
    -- ==========================================
    local scrolled_albums = Gtk.ScrolledWindow {}
    local album_flowbox = Gtk.FlowBox {
        valign = Gtk.Align.START,
        halign = Gtk.Align.START,
        column_spacing = 10,
        row_spacing = 10,
        margin = 10,
        min_children_per_line = 3,
        selection_mode = Gtk.SelectionMode.NONE
    }
    scrolled_albums.child = album_flowbox
    main_stack:add_titled(scrolled_albums, "albums", "Albums")

    local loading_albums_label = Gtk.Label { label = "Loading albums..." }
    album_flowbox:add(loading_albums_label)
    
    -- Map to store album data
    local album_map = {}

    -- ==========================================
    -- PAGE: ARTISTS (Placeholder)
    -- ==========================================
    local artists_placeholder = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 10, halign = Gtk.Align.CENTER, valign = Gtk.Align.CENTER }
    local artists_label = Gtk.Label { label = "Artists view coming soon..." }
    artists_placeholder:add(artists_label)
    main_stack:add_titled(artists_placeholder, "artists", "Artists")

    -- ==========================================
    -- PAGE: ALBUM DETAIL
    -- ==========================================
    local album_detail_box = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 10, margin = 10 }
    
    local album_header_box = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 15, margin_bottom = 10 }
    local album_art_image = Gtk.Image { icon_name = 'media-optical', pixel_size = 150 }
    
    local album_info_box = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 5, valign = Gtk.Align.START }
    local album_title_label = Gtk.Label { label = "Album Title", use_markup = true, halign = Gtk.Align.START, ellipsize = 'END' }
    local album_artist_label = Gtk.Label { label = "Artist", halign = Gtk.Align.START, sensitive = false }
    local album_year_label = Gtk.Label { label = "Year", halign = Gtk.Align.START, sensitive = false }
    local album_extra_label = Gtk.Label { label = "", halign = Gtk.Align.START, sensitive = false }
    
    local play_album_button = Gtk.Button {
        label = "Play Album",
        image = Gtk.Image { icon_name = "media-playback-start-symbolic" },
        always_show_image = true,
        tooltip_text = "Play all songs in this album",
        margin_top = 5
    }

    album_info_box:pack_start(album_title_label, false, false, 0)
    album_info_box:pack_start(album_artist_label, false, false, 0)
    album_info_box:pack_start(album_year_label, false, false, 0)
    album_info_box:pack_start(album_extra_label, false, false, 0)
    album_info_box:pack_start(play_album_button, false, false, 0)

    album_header_box:pack_start(album_art_image, false, false, 0)
    album_header_box:pack_start(album_info_box, true, true, 0)

    local album_songs_scrolled = Gtk.ScrolledWindow {}
    local album_songs_listbox = Gtk.ListBox {}
    album_songs_scrolled.child = album_songs_listbox

    album_detail_box:pack_start(album_header_box, false, false, 0)
    album_detail_box:pack_start(album_songs_scrolled, true, true, 0)
    
    main_stack:add_titled(album_detail_box, "album_detail", "")

    -- ==========================================
    -- PAGE: PLAYLIST DETAIL
    -- ==========================================
    local playlist_detail_box = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 10, margin = 10 }
    
    local playlist_header_box = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 15, margin_bottom = 10 }
    local playlist_art_image = Gtk.Image { icon_name = 'audio-x-generic', pixel_size = 150 }
    
    local playlist_info_box = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 5, valign = Gtk.Align.START }
    local playlist_title_label = Gtk.Label { label = "Playlist Title", use_markup = true, halign = Gtk.Align.START, ellipsize = 'END' }
    local playlist_extra_label = Gtk.Label { label = "", halign = Gtk.Align.START, sensitive = false }

    local play_playlist_button = Gtk.Button {
        label = "Play Playlist",
        image = Gtk.Image { icon_name = "media-playback-start-symbolic" },
        always_show_image = true,
        tooltip_text = "Play all songs in this playlist",
        margin_top = 5
    }

    playlist_info_box:pack_start(playlist_title_label, false, false, 0)
    playlist_info_box:pack_start(playlist_extra_label, false, false, 0)
    playlist_info_box:pack_start(play_playlist_button, false, false, 0)

    playlist_header_box:pack_start(playlist_art_image, false, false, 0)
    playlist_header_box:pack_start(playlist_info_box, true, true, 0)

    local playlist_songs_scrolled = Gtk.ScrolledWindow {}
    local playlist_songs_listbox = Gtk.ListBox {}
    playlist_songs_scrolled.child = playlist_songs_listbox

    playlist_detail_box:pack_start(playlist_header_box, false, false, 0)
    playlist_detail_box:pack_start(playlist_songs_scrolled, true, true, 0)
    
    main_stack:add_titled(playlist_detail_box, "playlist_detail", "")

    -- ==========================================
    -- LOGIC & CALLBACKS
    -- ==========================================

    -- Logout Button Callback
    function logout_button:on_clicked()
        print("Logging out...")
        delete_config()
        api_client = nil
        main_window:destroy()
        create_login_window(app)
    end

    -- Back Button Callback
    function back_button:on_clicked()
        local current = main_stack.visible_child_name
        if current == "album_detail" then
            main_stack.visible_child_name = "albums"
            main_stack:set_title(album_detail_box, "")
        elseif current == "playlist_detail" then
            main_stack.visible_child_name = "playlists"
            main_stack:set_title(playlist_detail_box, "")
        end
        header_bar.title = "Ampache"
    end

    -- Stack Switcher Visibility Logic
    main_stack.on_notify['visible-child-name'] = function(self)
        local name = main_stack.visible_child_name
        if name == "album_detail" or name == "playlist_detail" then
            back_button.visible = true
        else
            back_button.visible = false
            header_bar.title = "Ampache"
        end
    end

    -- Function to load album detail
    local function load_album_detail(album)
        -- Clear previous songs
        local children = album_songs_listbox:get_children()
        for _, child in ipairs(children) do album_songs_listbox:remove(child) end

        header_bar.title = album.name or "Album"
        main_stack:set_title(album_detail_box, album.name or "")
        
        album_title_label.label = "<span size='x-large' weight='bold'>" .. escape_markup(album.name or "Unknown") .. "</span>"
        album_artist_label.label = "by " .. escape_markup(album.artist and album.artist.name or "Unknown Artist")
        
        local year_str = "N/A"
        if album.year then
            local y = tonumber(album.year)
            if y then year_str = string.format("%d", y) else year_str = tostring(album.year) end
        end
        album_year_label.label = "Year: " .. year_str
        
        local extra_text = ""
        if album.playcount then extra_text = extra_text .. "Plays: " .. album.playcount .. "  " end
        if album.rating then
            local r = album.rating
            if type(r) == "string" or type(r) == "number" then extra_text = extra_text .. "Rating: " .. r .. "  " end
        end
        album_extra_label.label = extra_text

        -- Load Art
        local img_path = nil
        if album.art and album.has_art then
            local temp_dir = "temp_images"
            if not lfs.attributes(temp_dir) then lfs.mkdir(temp_dir) end
            local filename = temp_dir .. "/" .. (album.id or os.time()) .. ".jpg"
            if not lfs.attributes(filename) then pcall(download_image, album.art, filename) end
            if lfs.attributes(filename) then img_path = filename end
        end

        if img_path then
            local ok, pixbuf = pcall(GdkPixbuf.Pixbuf.new_from_file_at_size, img_path, 150, 150)
            if ok then album_art_image.pixbuf = pixbuf else album_art_image.icon_name = 'media-optical' end
        else
            album_art_image.icon_name = 'media-optical'
        end

        local loading_song_label = Gtk.Label { label = "Loading songs...", margin = 10 }
        album_songs_listbox:add(loading_song_label)
        main_stack.visible_child_name = "album_detail"
        main_window:show_all()

        GLib.timeout_add(GLib.PRIORITY_DEFAULT_IDLE, 0, function()
            local res, code, h, s, j, data = api_client:request('album_songs', { filter = album.id })
            
            local children = album_songs_listbox:get_children()
            for _, child in ipairs(children) do album_songs_listbox:remove(child) end

            if code ~= 200 or not data or not data.song then
                local err_label = Gtk.Label { label = "Error loading songs or album is empty.", margin = 10 }
                album_songs_listbox:add(err_label)
                main_window:show_all()
                return false
            end

            local album_songs = data.song

            function play_album_button:on_clicked()
                if not playbin then return end
                playback_queue = album_songs
                play_song_at_index(1)
            end

            for _, song in ipairs(album_songs) do
                local row = Gtk.ListBoxRow {}
                local hbox = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 10, margin = 5 }
                
                local track_num = tonumber(song.track)
                local track_str = track_num and string.format("%d", track_num) or "-"
                
                local track_label = Gtk.Label { label = track_str, width_chars = 3, halign = Gtk.Align.END }
                local title_label = Gtk.Label { label = song.title or "Unknown", halign = Gtk.Align.START, ellipsize = 'END' }
                local duration_label = Gtk.Label { label = format_time(song.time), halign = Gtk.Align.END }

                local play_button = Gtk.Button {
                    image = Gtk.Image { icon_name = "media-playback-start-symbolic" },
                    always_show_image = true,
                    tooltip_text = "Play " .. (song.title or "song")
                }

                function play_button:on_clicked()
                    if not playbin then return end
                    playback_queue = { song }
                    play_song_at_index(1)
                end

                hbox:pack_start(track_label, false, false, 0)
                hbox:pack_start(title_label, true, true, 0)
                hbox:pack_start(duration_label, false, false, 0)
                hbox:pack_start(play_button, false, false, 0)
                
                row:add(hbox)
                album_songs_listbox:add(row)
            end
            
            main_window:show_all()
            return false
        end)
    end

    -- Function to load playlist detail
    local function load_playlist_detail(playlist)
        -- Clear previous songs
        local children = playlist_songs_listbox:get_children()
        for _, child in ipairs(children) do playlist_songs_listbox:remove(child) end

        header_bar.title = playlist.name or "Playlist"
        main_stack:set_title(playlist_detail_box, playlist.name or "")
        
        playlist_title_label.label = "<span size='x-large' weight='bold'>" .. escape_markup(playlist.name or "Unknown") .. "</span>"
        playlist_extra_label.label = "Total items: " .. (playlist.items or "N/A")

        -- Load Art
        local img_path = nil
        if playlist.art then
            local temp_dir = "temp_images"
            if not lfs.attributes(temp_dir) then lfs.mkdir(temp_dir) end
            local filename = temp_dir .. "/pl_" .. (playlist.id or os.time()) .. ".jpg"
            if not lfs.attributes(filename) then pcall(download_image, playlist.art, filename) end
            if lfs.attributes(filename) then img_path = filename end
        end

        if img_path then
            local ok, pixbuf = pcall(GdkPixbuf.Pixbuf.new_from_file_at_size, img_path, 150, 150)
            if ok then playlist_art_image.pixbuf = pixbuf else playlist_art_image.icon_name = 'audio-x-generic' end
        else
            playlist_art_image.icon_name = 'audio-x-generic'
        end

        local loading_song_label = Gtk.Label { label = "Loading songs...", margin = 10 }
        playlist_songs_listbox:add(loading_song_label)
        main_stack.visible_child_name = "playlist_detail"
        main_window:show_all()

        GLib.timeout_add(GLib.PRIORITY_DEFAULT_IDLE, 0, function()
            local res, code, h, s, j, data = api_client:request('playlist_songs', { filter = playlist.id })
            
            local children = playlist_songs_listbox:get_children()
            for _, child in ipairs(children) do playlist_songs_listbox:remove(child) end

            if code ~= 200 or not data or not data.song then
                local err_label = Gtk.Label { label = "Error loading songs or playlist is empty.", margin = 10 }
                playlist_songs_listbox:add(err_label)
                main_window:show_all()
                return false
            end

            local playlist_songs = data.song

            function play_playlist_button:on_clicked()
                if not playbin then return end
                playback_queue = playlist_songs
                play_song_at_index(1)
            end

            for i, song in ipairs(playlist_songs) do
                local row = Gtk.ListBoxRow {}
                local hbox = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 10, margin = 5 }
                
                local num_label = Gtk.Label { label = tostring(i), width_chars = 3, halign = Gtk.Align.END }
                local title_label = Gtk.Label { label = song.title or "Unknown", halign = Gtk.Align.START, ellipsize = 'END' }
                local duration_label = Gtk.Label { label = format_time(song.time), halign = Gtk.Align.END }

                local play_button = Gtk.Button {
                    image = Gtk.Image { icon_name = "media-playback-start-symbolic" },
                    always_show_image = true,
                    tooltip_text = "Play " .. (song.title or "song")
                }

                function play_button:on_clicked()
                    if not playbin then return end
                    playback_queue = { song }
                    play_song_at_index(1)
                end

                hbox:pack_start(num_label, false, false, 0)
                hbox:pack_start(title_label, true, true, 0)
                hbox:pack_start(duration_label, false, false, 0)
                hbox:pack_start(play_button, false, false, 0)
                
                row:add(hbox)
                playlist_songs_listbox:add(row)
            end
            
            main_window:show_all()
            return false
        end)
    end

    -- Album Click Handler
    function album_flowbox:on_child_activated(child)
        local album = album_map[child]
        if album then load_album_detail(album) end
    end

    -- Playlist Click Handler
    function playlist_flowbox:on_child_activated(child)
        local playlist = playlist_map[child]
        if playlist then load_playlist_detail(playlist) end
    end

    -- Load Albums
    GLib.timeout_add(GLib.PRIORITY_DEFAULT_IDLE, 0, function()
        local res, code, h, s, j, data = api_client:albums({limit = 50})
        
        if code ~= 200 or not data or not data.album then
            loading_albums_label.label = "Error loading albums."
            return false
        end

        album_flowbox:remove(loading_albums_label)
        local temp_dir = "temp_images"
        if not lfs.attributes(temp_dir) then lfs.mkdir(temp_dir) end

        for _, album in ipairs(data.album) do
            local box = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 5, margin = 5, width_request = 150 }
            local img_path = nil
            if album.art and album.has_art then
                local filename = temp_dir .. "/" .. (album.id or os.time()) .. ".jpg"
                if not lfs.attributes(filename) then pcall(download_image, album.art, filename) end
                if lfs.attributes(filename) then img_path = filename end
            end

            local image_widget
            if img_path then
                local ok, pixbuf = pcall(GdkPixbuf.Pixbuf.new_from_file_at_size, img_path, 150, 150)
                if ok then image_widget = Gtk.Image { pixbuf = pixbuf } else image_widget = Gtk.Image { icon_name = 'media-optical', pixel_size = 150 } end
            else
                image_widget = Gtk.Image { icon_name = 'media-optical', pixel_size = 150 }
            end

            local name_label = Gtk.Label { label = album.name or "Unknown", ellipsize = 'END', max_width_chars = 20, tooltip_text = album.name }
            local artist_label = Gtk.Label { label = album.artist and album.artist.name or "Unknown", ellipsize = 'END', max_width_chars = 20, sensitive = false }

            box:add(image_widget)
            box:add(name_label)
            box:add(artist_label)

            local child_widget = Gtk.FlowBoxChild {}
            child_widget:add(box)
            album_map[child_widget] = album
            album_flowbox:add(child_widget)
        end
        
        main_window:show_all()
        return false
    end)

    -- Load Playlists
    GLib.timeout_add(GLib.PRIORITY_DEFAULT_IDLE, 0, function()
        local res, code, h, s, j, data = api_client:playlists({limit = 50})
        
        if code ~= 200 or not data or not data.playlist then
            loading_playlists_label.label = "Error loading playlists."
            return false
        end

        playlist_flowbox:remove(loading_playlists_label)

        -- Sort Playlists: Flagged > Rating > Date Added
        table.sort(data.playlist, function(a, b)
            -- 1. Flag (Liked)
            local a_flag = (a.flag == true or a.flag == 1)
            local b_flag = (b.flag == true or b.flag == 1)
            if a_flag ~= b_flag then return a_flag end

            -- 2. Rating
            local a_rating = tonumber(a.rating) or 0
            local b_rating = tonumber(b.rating) or 0
            if a_rating ~= b_rating then return a_rating > b_rating end

            -- 3. Date Added
            local a_add = a.add or ""
            local b_add = b.add or ""
            if a_add ~= b_add then return a_add > b_add end

            return false
        end)

        for _, playlist in ipairs(data.playlist) do
            local box = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 5, margin = 5, width_request = 150 }
            
            -- Load Playlist Art
            local img_path = nil
            if playlist.art then
                local temp_dir = "temp_images"
                if not lfs.attributes(temp_dir) then lfs.mkdir(temp_dir) end
                local filename = temp_dir .. "/pl_" .. (playlist.id or os.time()) .. ".jpg"
                if not lfs.attributes(filename) then pcall(download_image, playlist.art, filename) end
                if lfs.attributes(filename) then img_path = filename end
            end

            local image_widget
            if img_path then
                local ok, pixbuf = pcall(GdkPixbuf.Pixbuf.new_from_file_at_size, img_path, 150, 150)
                if ok then image_widget = Gtk.Image { pixbuf = pixbuf } else image_widget = Gtk.Image { icon_name = 'audio-x-generic', pixel_size = 150 } end
            else
                image_widget = Gtk.Image { icon_name = 'audio-x-generic', pixel_size = 150 }
            end
            
            local name_label = Gtk.Label { label = playlist.name or "Unknown", ellipsize = 'END', max_width_chars = 20, tooltip_text = playlist.name }
            local items_label = Gtk.Label { label = (playlist.items or "0") .. " items", ellipsize = 'END', max_width_chars = 20, sensitive = false }

            box:add(image_widget)
            box:add(name_label)
            box:add(items_label)

            local child_widget = Gtk.FlowBoxChild {}
            child_widget:add(box)
            playlist_map[child_widget] = playlist
            playlist_flowbox:add(child_widget)
        end
        
        main_window:show_all()
        return false
    end)
end

-- Function to create the Login Window
local function create_login_window(app)
    print("Creating login window...")
    local window = Gtk.ApplicationWindow {
        application = app,
        title = "Ampache Login",
        default_width = 300,
        default_height = 200,
        border_width = 10,
    }

    local grid = Gtk.Grid { column_spacing = 10, row_spacing = 10 }
    
    local url_entry = Gtk.Entry { placeholder_text = "Server URL" }
    local user_entry = Gtk.Entry { placeholder_text = "Username" }
    local pass_entry = Gtk.Entry { placeholder_text = "Password", visibility = false, input_purpose = Gtk.InputPurpose.PASSWORD }
    local status_label = Gtk.Label { label = "" }
    local login_button = Gtk.Button { label = "Login" }

    grid:attach(Gtk.Label { label = "Server:" }, 0, 0, 1, 1)
    grid:attach(url_entry, 1, 0, 1, 1)
    grid:attach(Gtk.Label { label = "User:" }, 0, 1, 1, 1)
    grid:attach(user_entry, 1, 1, 1, 1)
    grid:attach(Gtk.Label { label = "Pass:" }, 0, 2, 1, 1)
    grid:attach(pass_entry, 1, 2, 1, 1)
    grid:attach(login_button, 0, 3, 2, 1)
    grid:attach(status_label, 0, 4, 2, 1)

    window.child = grid

    function login_button:on_clicked()
        local url = url_entry.text
        local user = user_entry.text
        local pass = pass_entry.text

        if url == "" or user == "" or pass == "" then
            status_label.label = "<span foreground='red'>Please fill all fields.</span>"
            status_label.use_markup = true
            return
        end

        status_label.label = "Logging in..."
        print("Login button clicked. Attempting to connect to: " .. url)
        
        local ok, err = pcall(function()
            print("Creating client...")
            api_client = client.new(url, user, pass)
            print("Client created. Verifying connection...")
            local _, code = api_client:albums({limit = 1})
            if code ~= 200 then
                print("Connection verification failed with code: " .. tostring(code))
                error("Authentication failed or server error")
            end
            print("Connection verified successfully.")
        end)

        if ok then
            save_config(url, user, pass)
            print("Login successful. Opening main window.")
            window:destroy()
            create_main_window(app)
        else
            print("Login failed: " .. tostring(err))
            status_label.label = "<span foreground='red'>Error: " .. tostring(err) .. "</span>"
            status_label.use_markup = true
        end
    end

    window:show_all()
end

function App:on_activate()
    local config = load_config()
    if config then
        print("Found saved credentials. Attempting auto-login...")
        local ok, _ = pcall(function()
            api_client = client.new(config.url, config.user, config.password)
            local _, code = api_client:albums({limit = 1})
            if code ~= 200 then error("Auto-login failed") end
        end)

        if ok then
            print("Auto-login successful.")
            create_main_window(self)
            return
        else
            print("Auto-login failed. Showing login window.")
            api_client = nil
        end
    end

    create_login_window(self)
end

App:run(arg)
