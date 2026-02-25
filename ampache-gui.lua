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

-- Setup package path to find local modules
local script_path = debug.getinfo(1, "S").source:match("(.*/)") or ""
script_path = script_path:sub(2) -- Remove '@'
local script_dir = script_path:match("(.+)/") or ""
package.path = script_dir .. "/?.lua;" .. package.path

-- Path for storing credentials
local config_path = script_dir .. "/ampache-config.lua"

-- Helper function to save configuration
local function save_config(url, user, pass)
    local file = io.open(config_path, "w")
    if file then
        file:write(string.format("return { url = %q, user = %q, password = %q }", url, user, pass))
        file:close()
        print("Credentials saved.")
    else
        print("Failed to save credentials.")
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

local client = require("ampache-client")

local App = Gtk.Application()
App.application_id = 'com.github.icefields.ampache-gui'

local api_client = nil
local main_window = nil

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
    local secs = seconds % 60
    return string.format("%d:%02d", mins, secs)
end

-- Function to create the Main Window
local function create_main_window(app)
    print("Creating main window...")
    main_window = Gtk.ApplicationWindow {
        application = app,
        title = "Ampache Albums",
        default_width = 800,
        default_height = 600,
    }

    -- Setup Header Bar
    local header_bar = Gtk.HeaderBar {
        title = "Ampache Albums",
        show_close_button = true,
        decoration_layout = "menu:close"
    }
    -- Use set_titlebar method instead of property assignment for broader compatibility
    main_window:set_titlebar(header_bar)

    -- Back Button (initially hidden)
    local back_button = Gtk.Button {
        image = Gtk.Image { icon_name = "go-previous-symbolic" },
        visible = false,
        tooltip_text = "Back to Albums"
    }
    header_bar:pack_start(back_button)

    -- Logout Button
    local logout_button = Gtk.Button {
        label = "Logout",
        tooltip_text = "Clear saved credentials and return to login"
    }
    header_bar:pack_end(logout_button)

    -- Main Stack for navigation
    local stack = Gtk.Stack {}
    main_window.child = stack

    -- Map to store album data associated with FlowBox children
    local album_map = {}

    -- ==========================================
    -- PAGE 1: ALBUMS LIST
    -- ==========================================
    local scrolled_albums = Gtk.ScrolledWindow {}
    local flowbox = Gtk.FlowBox {
        valign = Gtk.Align.START,
        halign = Gtk.Align.START,
        column_spacing = 10,
        row_spacing = 10,
        margin = 10,
        min_children_per_line = 3,
        selection_mode = Gtk.SelectionMode.NONE
    }
    scrolled_albums.child = flowbox
    stack:add_named(scrolled_albums, "albums")

    local loading_label = Gtk.Label { label = "Loading albums..." }
    flowbox:add(loading_label)
    main_window:show_all()

    -- ==========================================
    -- PAGE 2: ALBUM DETAIL
    -- ==========================================
    local detail_box = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 10, margin = 10 }
    
    -- Album Info Header (Art + Metadata)
    local album_header_box = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 15, margin_bottom = 10 }
    
    local album_art_image = Gtk.Image { 
        icon_name = 'media-optical', 
        pixel_size = 150 
    }
    
    local album_info_box = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 5, valign = Gtk.Align.START }
    local album_title_label = Gtk.Label { 
        label = "Album Title", 
        use_markup = true,
        halign = Gtk.Align.START,
        ellipsize = 'END'
    }
    local album_artist_label = Gtk.Label { label = "Artist", halign = Gtk.Align.START, sensitive = false }
    local album_year_label = Gtk.Label { label = "Year", halign = Gtk.Align.START, sensitive = false }
    local album_extra_label = Gtk.Label { label = "", halign = Gtk.Align.START, sensitive = false }
    
    album_info_box:pack_start(album_title_label, false, false, 0)
    album_info_box:pack_start(album_artist_label, false, false, 0)
    album_info_box:pack_start(album_year_label, false, false, 0)
    album_info_box:pack_start(album_extra_label, false, false, 0)

    album_header_box:pack_start(album_art_image, false, false, 0)
    album_header_box:pack_start(album_info_box, true, true, 0)

    -- Songs List
    local songs_scrolled = Gtk.ScrolledWindow {}
    local songs_listbox = Gtk.ListBox {}
    songs_scrolled.child = songs_listbox

    detail_box:pack_start(album_header_box, false, false, 0)
    detail_box:pack_start(songs_scrolled, true, true, 0)

    stack:add_named(detail_box, "detail")

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
        stack.visible_child_name = "albums"
        back_button.visible = false
        header_bar.title = "Ampache Albums"
    end

    -- Function to load album detail
    local function load_album_detail(album)
        -- Clear previous songs
        local children = songs_listbox:get_children()
        for _, child in ipairs(children) do
            songs_listbox:remove(child)
        end

        -- Update Header
        header_bar.title = album.name or "Album"
        back_button.visible = true
        
        -- Update Album Info
        album_title_label.label = "<span size='x-large' weight='bold'>" .. (album.name or "Unknown") .. "</span>"
        album_artist_label.label = "by " .. (album.artist and album.artist.name or "Unknown Artist")
        
        -- Format Year as integer
        local year_str = "N/A"
        if album.year then
            local y = tonumber(album.year)
            if y then
                year_str = string.format("%d", y)
            else
                year_str = tostring(album.year)
            end
        end
        album_year_label.label = "Year: " .. year_str
        
        local extra_text = ""
        if album.playcount then extra_text = extra_text .. "Plays: " .. album.playcount .. "  " end
        
        -- Safe check for rating to avoid concatenating userdata/table
        if album.rating then
            local r = album.rating
            if type(r) == "string" or type(r) == "number" then
                extra_text = extra_text .. "Rating: " .. r .. "  "
            end
        end
        
        album_extra_label.label = extra_text

        -- Load Art
        local img_path = nil
        if album.art and album.has_art then
            local temp_dir = "temp_images"
            if not lfs.attributes(temp_dir) then lfs.mkdir(temp_dir) end
            local filename = temp_dir .. "/" .. (album.id or os.time()) .. ".jpg"
            if not lfs.attributes(filename) then
                pcall(download_image, album.art, filename)
            end
            if lfs.attributes(filename) then
                img_path = filename
            end
        end

        if img_path then
            local ok, pixbuf = pcall(GdkPixbuf.Pixbuf.new_from_file_at_size, img_path, 150, 150)
            if ok then
                album_art_image.pixbuf = pixbuf
            else
                album_art_image.icon_name = 'media-optical'
            end
        else
            album_art_image.icon_name = 'media-optical'
        end

        -- Switch to detail view immediately with loading indicator
        local loading_song_label = Gtk.Label { label = "Loading songs...", margin = 10 }
        songs_listbox:add(loading_song_label)
        stack.visible_child_name = "detail"
        main_window:show_all()

        -- Fetch Songs Async
        GLib.timeout_add(GLib.PRIORITY_DEFAULT_IDLE, 0, function()
            -- Use 'album_songs' method via the generic request function
            local res, code, h, s, j, data = api_client:request('album_songs', { filter = album.id })
            
            -- Clear loading indicator (ListBox wraps it in a row, so we clear all children)
            local children = songs_listbox:get_children()
            for _, child in ipairs(children) do
                songs_listbox:remove(child)
            end

            if code ~= 200 or not data or not data.song then
                local err_label = Gtk.Label { label = "Error loading songs or album is empty.", margin = 10 }
                songs_listbox:add(err_label)
                main_window:show_all()
                return false
            end

            print("Found " .. #data.song .. " songs for album " .. (album.name or "ID " .. album.id))
            
            for _, song in ipairs(data.song) do
                local row = Gtk.ListBoxRow {}
                local hbox = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 10, margin = 5 }
                
                -- Format track number as integer
                local track_num = tonumber(song.track)
                local track_str = track_num and string.format("%d", track_num) or "-"
                
                local track_label = Gtk.Label { 
                    label = track_str, 
                    width_chars = 3, 
                    halign = Gtk.Align.END 
                }
                
                local title_label = Gtk.Label { 
                    label = song.title or "Unknown", 
                    halign = Gtk.Align.START,
                    ellipsize = 'END'
                }
                
                local duration_label = Gtk.Label { 
                    label = format_time(song.time), 
                    halign = Gtk.Align.END 
                }

                hbox:pack_start(track_label, false, false, 0)
                hbox:pack_start(title_label, true, true, 0)
                hbox:pack_start(duration_label, false, false, 0)
                
                row:add(hbox)
                songs_listbox:add(row)
            end
            
            main_window:show_all()
            return false
        end)
    end

    -- Album Click Handler
    function flowbox:on_child_activated(child)
        local album = album_map[child]
        if album then
            print("Album activated: " .. (album.name or "Unknown"))
            load_album_detail(album)
        end
    end

    -- Load Albums
    print("Scheduling album loading via GLib.timeout_add(0)...")
    GLib.timeout_add(GLib.PRIORITY_DEFAULT_IDLE, 0, function()
        print("Idle callback started: Fetching albums...")
        local res, code, h, s, j, data = api_client:albums({limit = 50})
        
        print("API call finished. HTTP Code: " .. tostring(code))
        
        if code ~= 200 or not data or not data.album then
            print("Error loading albums: " .. tostring(code))
            loading_label.label = "Error loading albums."
            return false
        end

        print("Found " .. #data.album .. " albums. Processing...")
        flowbox:remove(loading_label)

        local temp_dir = "temp_images"
        if not lfs.attributes(temp_dir) then
            print("Creating temp directory: " .. temp_dir)
            lfs.mkdir(temp_dir)
        end

        local count = 0
        for _, album in ipairs(data.album) do
            count = count + 1
            -- print("Processing album " .. count .. ": " .. (album.name or "Unknown")) -- Verbose
            
            local box = Gtk.Box {
                orientation = Gtk.Orientation.VERTICAL,
                spacing = 5,
                margin = 5,
                width_request = 150,
            }

            local img_path = nil
            if album.art and album.has_art then
                local filename = temp_dir .. "/" .. (album.id or os.time()) .. ".jpg"
                if not lfs.attributes(filename) then
                    local ok, err = pcall(download_image, album.art, filename)
                    if not ok then
                        -- print("Failed to download image: " .. tostring(err)) -- Optional debug
                    end
                end
                if lfs.attributes(filename) then
                    img_path = filename
                end
            end

            local image_widget
            if img_path then
                local ok, pixbuf = pcall(GdkPixbuf.Pixbuf.new_from_file_at_size, img_path, 150, 150)
                if ok then
                    image_widget = Gtk.Image { pixbuf = pixbuf }
                else
                     image_widget = Gtk.Image { 
                        icon_name = 'media-optical', 
                        pixel_size = 150 
                    }
                end
            else
                image_widget = Gtk.Image { 
                    icon_name = 'media-optical', 
                    pixel_size = 150 
                }
            end

            local name_label = Gtk.Label { 
                label = album.name or "Unknown",
                ellipsize = 'END',
                max_width_chars = 20,
                tooltip_text = album.name
            }
            
            local artist_label = Gtk.Label {
                label = album.artist and album.artist.name or "Unknown",
                ellipsize = 'END',
                max_width_chars = 20,
                sensitive = false
            }

            box:add(image_widget)
            box:add(name_label)
            box:add(artist_label)

            -- Wrap in FlowBoxChild to store data
            local child_widget = Gtk.FlowBoxChild {}
            child_widget:add(box)
            
            -- Store album data in our map using the child widget as key
            album_map[child_widget] = album
            
            flowbox:add(child_widget)
        end
        
        print("Finished processing " .. count .. " albums.")
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

    local grid = Gtk.Grid {
        column_spacing = 10,
        row_spacing = 10,
    }
    
    local url_entry = Gtk.Entry { placeholder_text = "Server URL" }
    local user_entry = Gtk.Entry { placeholder_text = "Username" }
    local pass_entry = Gtk.Entry { 
        placeholder_text = "Password",
        visibility = false,
        input_purpose = Gtk.InputPurpose.PASSWORD
    }
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
        
        -- Perform login and initial fetch synchronously
        local ok, err = pcall(function()
            print("Creating client...")
            api_client = client.new(url, user, pass)
            print("Client created. Verifying connection...")
            -- Verify connection by trying to get albums
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
    -- Check for saved credentials
    local config = load_config()
    if config then
        print("Found saved credentials. Attempting auto-login...")
        local ok, _ = pcall(function()
            api_client = client.new(config.url, config.user, config.password)
            -- Verify connection
            local _, code = api_client:albums({limit = 1})
            if code ~= 200 then
                error("Auto-login failed: Server returned code " .. code)
            end
        end)

        if ok then
            print("Auto-login successful.")
            create_main_window(self)
            return
        else
            print("Auto-login failed. Showing login window.")
            api_client = nil
            -- If auto-login fails, we proceed to show the login window
        end
    end

    create_login_window(self)
end

App:run(arg)
