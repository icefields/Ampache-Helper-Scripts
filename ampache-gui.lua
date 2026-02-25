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
    print("Downloading image: " .. url)
    local file, err = io.open(filename, "wb")
    if not file then 
        print("Failed to open file for writing: " .. filename .. " Error: " .. tostring(err))
        return nil, err 
    end
    local response_body = {}
    local res, code = http.request{
        url = url,
        sink = ltn12.sink.table(response_body)
    }
    -- http.request returns code as second return value in this signature
    -- but checking res first is safer for connection errors
    if not res then
         print("Connection error downloading image: " .. tostring(code))
         file:close()
         return nil, code
    end
    
    if code ~= 200 then
        print("HTTP error downloading image: " .. tostring(code))
        file:close()
        return nil, "HTTP code " .. code
    end
    file:write(table.concat(response_body))
    file:close()
    print("Saved image to: " .. filename)
    return filename
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

    local scrolled = Gtk.ScrolledWindow {}
    local flowbox = Gtk.FlowBox {
        valign = Gtk.Align.START,
        halign = Gtk.Align.START,
        column_spacing = 10,
        row_spacing = 10,
        margin = 10,
        min_children_per_line = 3,
        selection_mode = Gtk.SelectionMode.NONE
    }

    scrolled.child = flowbox
    main_window.child = scrolled

    local loading_label = Gtk.Label { label = "Loading albums..." }
    flowbox:add(loading_label)
    main_window:show_all()

    -- Use timeout_add with 0 interval to load data without blocking UI startup
    -- This is effectively the same as idle_add but avoids argument signature issues
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
            print("Processing album " .. count .. ": " .. (album.name or "Unknown"))
            
            local box = Gtk.Box {
                orientation = Gtk.Orientation.VERTICAL,
                spacing = 5,
                margin = 5,
                width_request = 150,
            }

            local img_path = nil
            if album.art and album.has_art then
                local filename = temp_dir .. "/" .. (album.id or os.time()) .. ".jpg"
                -- Simple check to avoid re-downloading if file exists (optional)
                if not lfs.attributes(filename) then
                    -- pcall to handle download errors gracefully
                    local ok, err = pcall(download_image, album.art, filename)
                    if not ok then
                        print("Failed to download image for album " .. (album.name or "unknown") .. ": " .. tostring(err))
                    end
                else
                    print("Image already cached: " .. filename)
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

            flowbox:add(box)
        end
        
        print("Finished processing " .. count .. " albums.")
        main_window:show_all()
        return false -- Return false to remove the timeout
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
    create_login_window(self)
end

App:run(arg)
