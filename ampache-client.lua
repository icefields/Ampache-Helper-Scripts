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
----     High-Level Ampache API Client          -----
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

local http = require("ampache-http")
local handshake = require("ampache-handshake")

local client = {}

-- Constructor for the Ampache Client
-- password_hash is optional. If provided, it is the SHA256 hash of the password.
function client.new(server_url, username, password, password_hash)
    -- Perform handshake to get auth token
    local auth_token = handshake.getAuthToken(server_url, username, password, password_hash)
    
    local instance = {
        server_url = server_url,
        username = username,
        password = password,
        password_hash = password_hash, -- Store hash if provided
        auth = auth_token -- Store auth token for stream URLs
    }
    setmetatable(instance, { __index = client })
    return instance
end

-- Internal helper to merge connection details with request arguments
local function prepare_args(self, action, args)
    args = args or {}
    args.action = action
    args.server_url = self.server_url
    args.username = self.username
    args.password = self.password
    args.auth = self.auth -- Pass auth token if available
    return args
end

-- API Methods

function client:albums(args)
    return http.makeRequest(prepare_args(self, "albums", args), args.is_print_url)
end

function client:artists(args)
    return http.makeRequest(prepare_args(self, "artists", args), args.is_print_url)
end

function client:songs(args)
    return http.makeRequest(prepare_args(self, "songs", args), args.is_print_url)
end

function client:playlists(args)
    return http.makeRequest(prepare_args(self, "playlists", args), args.is_print_url)
end

function client:stats(args)
    return http.makeRequest(prepare_args(self, "stats", args), args.is_print_url)
end

function client:artist_songs(args)
    return http.makeRequest(prepare_args(self, "artist_songs", args), args.is_print_url)
end

function client:album_songs(args)
    return http.makeRequest(prepare_args(self, "album_songs", args), args.is_print_url)
end

function client:playlist_songs(args)
    return http.makeRequest(prepare_args(self, "playlist_songs", args), args.is_print_url)
end

function client:song(args)
    return http.makeRequest(prepare_args(self, "song", args), args.is_print_url)
end

function client:get_similar(args)
    return http.makeRequest(prepare_args(self, "get_similar", args), args.is_print_url)
end

function client:user(args)
    return http.makeRequest(prepare_args(self, "user", args), args.is_print_url)
end

-- Generic request method for any action not covered by specific methods
function client:request(action, args)
    return http.makeRequest(prepare_args(self, action, args), args and args.is_print_url)
end

return client
