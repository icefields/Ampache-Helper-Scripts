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
-- --- Centralized API method definitions ------- --
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

-- This module defines the correct parameters for each Ampache API method
-- Based on ampache-api-json-methods.md

local api_methods = {
    -- Auth Methods
    handshake = {
        required = {"auth", "user", "timestamp", "version"},
        optional = {},
        description = "Verifies a new handshake"
    },
    goodbye = {
        required = {"auth"},
        optional = {},
        description = "Destroys a session"
    },
    lost_password = {
        required = {"auth"},
        optional = {},
        description = "Emails a new password to the user"
    },
    ping = {
        required = {},
        optional = {"auth", "version"},
        description = "Checks server status and version"
    },
    register = {
        required = {"username", "password", "email"},
        optional = {"fullname"},
        description = "Registers as a new user"
    },
    
    -- Non-Data Methods
    system_update = {
        required = {},
        optional = {},
        description = "Checks for and runs updates",
        access_required = 100
    },
    system_preferences = {
        required = {},
        optional = {},
        description = "Gets server preferences",
        access_required = 100
    },
    users = {
        required = {},
        optional = {},
        description = "Gets user IDs and usernames"
    },
    user_preferences = {
        required = {},
        optional = {},
        description = "Gets user preferences"
    },
    
    -- Data Methods
    advanced_search = {
        required = {"operator", "rule_1", "rule_1_operator", "rule_1_input", "type"},
        optional = {"rule_2", "rule_2_operator", "rule_2_input", "random", "offset", "limit"},
        description = "Performs an advanced search"
    },
    albums = {
        required = {},
        optional = {"filter", "include", "exact", "add", "update", "offset", "limit", "cond", "sort"},
        description = "Returns albums based on search filters"
    },
    album = {
        required = {"filter"},
        optional = {"include"},
        description = "Returns a single album"
    },
    album_songs = {
        required = {"filter"},
        optional = {"offset", "limit", "cond", "sort"},
        description = "Returns the songs of a specified album"
    },
    artists = {
        required = {},
        optional = {"filter", "exact", "add", "update", "include", "album_artist", "offset", "limit", "cond", "sort"},
        description = "Returns artist objects"
    },
    artist = {
        required = {"filter"},
        optional = {"include"},
        description = "Returns a single artist"
    },
    artist_albums = {
        required = {"filter"},
        optional = {"album_artist", "offset", "limit", "cond", "sort"},
        description = "Returns the albums of an artist"
    },
    artist_songs = {
        required = {"filter"},
        optional = {"top50", "offset", "limit", "cond", "sort"},
        description = "Returns the songs of the specified artist"
    },
    bookmarks = {
        required = {},
        optional = {"client", "include"},
        description = "Gets information about bookmarked media"
    },
    bookmark = {
        required = {"filter"},
        optional = {"include"},
        description = "Gets a single bookmark by bookmark_id"
    },
    bookmark_create = {
        required = {"filter", "type", "position"},
        optional = {"client", "date", "include"},
        description = "Creates a placeholder for current media"
    },
    bookmark_delete = {
        required = {"filter", "type"},
        optional = {"client"},
        description = "Deletes an existing bookmark"
    },
    bookmark_edit = {
        required = {"filter", "type", "position"},
        optional = {"client", "date", "include"},
        description = "Edits a bookmark placeholder"
    },
    browse = {
        required = {},
        optional = {"filter", "type", "catalog", "add", "update", "offset", "limit", "cond", "sort"},
        description = "Returns children of a parent object in browse style"
    },
    catalogs = {
        required = {},
        optional = {"filter", "offset", "limit", "cond", "sort"},
        description = "Searches the catalogs and returns catalogs"
    },
    catalog = {
        required = {"filter"},
        optional = {},
        description = "Returns catalog by UID"
    },
    catalog_action = {
        required = {"task", "catalog"},
        optional = {"filter"},
        description = "Kicks off a catalog update or clean",
        access_required = 75
    },
    catalog_add = {
        required = {"name", "path"},
        optional = {"type", "media_type", "file_pattern", "folder_pattern", "username", "password"},
        description = "Creates a public URL for streaming media",
        access_required = 75
    },
    catalog_delete = {
        required = {"filter"},
        optional = {},
        description = "Deletes an existing catalog",
        access_required = 75
    },
    catalog_file = {
        required = {"file", "task"},
        optional = {"catalog", "filter"},
        description = "Performs actions on local catalog files",
        access_required = 50
    },
    catalog_folder = {
        required = {"folder", "task"},
        optional = {"catalog", "filter"},
        description = "Performs actions on local catalog folders",
        access_required = 50
    },
    deleted_podcast_episodes = {
        required = {},
        optional = {"offset", "limit"},
        description = "Returns deleted podcast episodes"
    },
    deleted_songs = {
        required = {},
        optional = {"offset", "limit"},
        description = "Returns deleted songs"
    },
    deleted_videos = {
        required = {},
        optional = {"offset", "limit"},
        description = "Returns deleted video objects"
    },
    flag = {
        required = {"type", "id", "flag"},
        optional = {"filter"},
        description = "Flags a library item as a favorite"
    },
    followers = {
        required = {"username"},
        optional = {"offset", "limit", "cond", "sort"},
        description = "Gets followers for a username"
    },
    following = {
        required = {"username"},
        optional = {},
        description = "Gets people that a user follows"
    },
    friends_timeline = {
        required = {},
        optional = {"limit", "since"},
        description = "Gets current user friends timeline"
    },
    genres = {
        required = {},
        optional = {"filter", "exact", "offset", "limit", "cond", "sort"},
        description = "Returns genres based on specified filter"
    },
    genre = {
        required = {"filter"},
        optional = {},
        description = "Returns a single genre"
    },
    genre_albums = {
        required = {"filter"},
        optional = {"offset", "limit", "cond", "sort"},
        description = "Returns albums associated with a genre"
    },
    genre_artists = {
        required = {"filter"},
        optional = {"offset", "limit", "cond", "sort"},
        description = "Returns artists associated with a genre"
    },
    genre_songs = {
        required = {"filter"},
        optional = {"offset", "limit", "cond", "sort"},
        description = "Returns songs for a genre"
    },
    get_bookmark = {
        required = {"filter", "type"},
        optional = {"include", "all"},
        description = "Gets a bookmark from object_id and object_type"
    },
    get_external_metadata = {
        required = {"filter", "type"},
        optional = {},
        description = "Returns external plugin metadata"
    },
    get_indexes = {
        required = {"type"},
        optional = {"filter", "hide_search", "add", "update", "include", "offset", "limit", "cond", "sort"},
        description = "Returns ID + name for object type (deprecated)"
    },
    get_lyrics = {
        required = {"filter"},
        optional = {"plugins"},
        description = "Returns database lyrics or searches with plugins"
    },
    get_similar = {
        required = {"type", "filter"},
        optional = {"offset", "limit"},
        description = "Returns similar artist or song IDs"
    },
    index = {
        required = {"type"},
        optional = {"filter", "hide_search", "exact", "add", "update", "include", "offset", "limit", "cond", "sort"},
        description = "Returns IDs for object type"
    },
    labels = {
        required = {},
        optional = {"filter", "exact", "add", "update", "offset", "limit", "cond", "sort"},
        description = "Returns labels based on specified filter"
    },
    label = {
        required = {"filter"},
        optional = {},
        description = "Returns a single label"
    },
    label_artists = {
        required = {"filter"},
        optional = {"offset", "limit", "cond", "sort"},
        description = "Returns artists for a label"
    },
    last_shouts = {
        required = {},
        optional = {"username", "limit"},
        description = "Gets latest posted shouts"
    },
    licenses = {
        required = {},
        optional = {"filter", "exact", "add", "update", "offset", "limit", "cond", "sort"},
        description = "Returns licenses based on specified filter"
    },
    license = {
        required = {"filter"},
        optional = {},
        description = "Returns a single license"
    },
    license_songs = {
        required = {"filter"},
        optional = {"offset", "limit", "cond", "sort"},
        description = "Returns songs for a license"
    },
    list = {
        required = {"type"},
        optional = {"filter", "hide_search", "add", "update", "offset", "limit", "cond", "sort"},
        description = "Returns named array of objects with ID, name, prefix and basename"
    },
    live_streams = {
        required = {},
        optional = {"filter", "exact", "add", "update", "offset", "limit", "cond", "sort"},
        description = "Returns live_streams based on specified filter"
    },
    live_stream = {
        required = {"filter"},
        optional = {},
        description = "Returns a single live_stream"
    },
    live_stream_create = {
        required = {"filter", "type", "position"},
        optional = {"client", "date"},
        description = "Creates a live_stream (radio station)",
        access_required = 50
    },
    live_stream_delete = {
        required = {"filter", "type"},
        optional = {"client"},
        description = "Deletes an existing live_stream",
        access_required = 50
    },
    live_stream_edit = {
        required = {"filter", "type", "position"},
        optional = {"client", "date"},
        description = "Edits a live_stream (radio station)",
        access_required = 50
    },
    now_playing = {
        required = {},
        optional = {},
        description = "Gets what is currently being played by all users"
    },
    player = {
        required = {},
        optional = {"filter", "type", "state", "time", "client"},
        description = "Informs server about client state"
    },
    playlists = {
        required = {},
        optional = {"filter", "hide_search", "show_dupes", "exact", "add", "update", "offset", "limit", "cond", "sort"},
        description = "Returns playlists based on specified filter"
    },
    playlist = {
        required = {"filter"},
        optional = {},
        description = "Returns a single playlist"
    },
    playlist_add = {
        required = {"filter", "id", "type"},
        optional = {},
        description = "Adds a song to a playlist"
    },
    playlist_add_song = {
        required = {"filter", "song"},
        optional = {"check"},
        description = "Adds a song to a playlist (deprecated)"
    },
    playlist_create = {
        required = {"name"},
        optional = {"type"},
        description = "Creates a new playlist"
    },
    playlist_delete = {
        required = {"filter"},
        optional = {},
        description = "Deletes a playlist"
    },
    playlist_edit = {
        required = {"filter"},
        optional = {"name", "type", "owner", "items", "tracks"},
        description = "Modifies name and type of a playlist"
    },
    playlist_generate = {
        required = {},
        optional = {"mode", "filter", "album", "artist", "flag", "format", "offset", "limit"},
        description = "Gets a list of songs based on search criteria"
    },
    playlist_hash = {
        required = {"filter"},
        optional = {},
        description = "Returns the MD5 hash for songs in a playlist"
    },
    playlist_remove_song = {
        required = {"filter"},
        optional = {"song", "track"},
        description = "Removes a song from a playlist"
    },
    playlist_songs = {
        required = {"filter"},
        optional = {"random", "offset", "limit"},
        description = "Returns the songs for a playlist"
    },
    podcasts = {
        required = {},
        optional = {"filter", "include", "offset", "limit", "cond", "sort"},
        description = "Gets information about podcasts"
    },
    podcast = {
        required = {"filter"},
        optional = {"include"},
        description = "Gets the podcast from its ID"
    },
    podcast_create = {
        required = {"url", "catalog"},
        optional = {},
        description = "Creates a podcast",
        access_required = 75
    },
    podcast_delete = {
        required = {"filter"},
        optional = {},
        description = "Deletes an existing podcast",
        access_required = 75
    },
    podcast_edit = {
        required = {"filter"},
        optional = {"feed", "title", "website", "description", "generator", "copyright"},
        description = "Updates an existing podcast",
        access_required = 50
    },
    podcast_episodes = {
        required = {"filter"},
        optional = {"offset", "limit", "cond", "sort"},
        description = "Returns the episodes for a podcast"
    },
    podcast_episode = {
        required = {"filter"},
        optional = {},
        description = "Gets the podcast_episode from its ID"
    },
    podcast_episode_delete = {
        required = {"filter"},
        optional = {},
        description = "Deletes an existing podcast_episode"
    },
    preference_create = {
        required = {"filter", "type", "default", "category"},
        optional = {"description", "subcategory", "level"},
        description = "Adds a new preference",
        access_required = 100
    },
    preference_delete = {
        required = {"filter"},
        optional = {},
        description = "Deletes a non-system preference",
        access_required = 100
    },
    preference_edit = {
        required = {"filter", "value"},
        optional = {"all", "default"},
        description = "Edits a preference value"
    },
    rate = {
        required = {"type", "id", "rating"},
        optional = {},
        description = "Rates a library item"
    },
    record_play = {
        required = {"id"},
        optional = {"filter", "user", "client", "date"},
        description = "Records a play",
        access_required = 100
    },
    scrobble = {
        required = {"song", "artist", "album"},
        optional = {"songmbid", "artistmbid", "albummbid", "date", "client"},
        description = "Searches for a song and records a play"
    },
    search_group = {
        required = {"operator", "rule_1", "rule_1_operator", "rule_1_input"},
        optional = {"rule_2", "rule_2_operator", "rule_2_input", "type", "random", "offset", "limit"},
        description = "Performs a group search"
    },
    search_rules = {
        required = {"filter"},
        optional = {},
        description = "Prints a list of valid search rules"
    },
    search_songs = {
        required = {"filter"},
        optional = {"offset", "limit"},
        description = "Searches the songs and returns songs"
    },
    shares = {
        required = {},
        optional = {"filter", "exact", "offset", "limit", "cond", "sort"},
        description = "Searches the shares and returns shares"
    },
    share = {
        required = {"filter"},
        optional = {},
        description = "Returns shares by UID"
    },
    share_create = {
        required = {"filter", "type"},
        optional = {"description", "expires"},
        description = "Creates a public URL for streaming media"
    },
    share_delete = {
        required = {"filter"},
        optional = {},
        description = "Deletes an existing share"
    },
    share_edit = {
        required = {"filter"},
        optional = {"stream", "download", "expires", "description"},
        description = "Updates an existing share"
    },
    smartlists = {
        required = {},
        optional = {"filter", "exact", "add", "update", "offset", "limit", "cond", "sort"},
        description = "Returns smartlists based on specified filter"
    },
    smartlist = {
        required = {"filter"},
        optional = {},
        description = "Returns a single smartlist"
    },
    smartlist_songs = {
        required = {"filter"},
        optional = {"random", "offset", "limit"},
        description = "Returns the songs for a smartlist"
    },
    smartlist_delete = {
        required = {"filter"},
        optional = {},
        description = "Deletes a smartlist"
    },
    songs = {
        required = {},
        optional = {"filter", "exact", "add", "update", "offset", "limit", "cond", "sort"},
        description = "Returns songs based on specified filter"
    },
    song = {
        required = {"filter"},
        optional = {},
        description = "Returns a single song"
    },
    song_delete = {
        required = {"filter"},
        optional = {},
        description = "Deletes an existing song"
    },
    song_tags = {
        required = {"filter"},
        optional = {},
        description = "Gets the full song file tags using VaInfo"
    },
    stats = {
        required = {},
        optional = {"type", "filter", "user_id", "username", "offset", "limit"},
        description = "Gets items based on search types and filters"
    },
    system_preference = {
        required = {"filter"},
        optional = {},
        description = "Gets server preference by name",
        access_required = 100
    },
    timeline = {
        required = {"username"},
        optional = {"limit", "since"},
        description = "Gets a user's timeline"
    },
    toggle_follow = {
        required = {"username"},
        optional = {},
        description = "Follows/unfollows a user"
    },
    update_art = {
        required = {"id"},
        optional = {"filter", "type", "overwrite"},
        description = "Updates a single album, artist, song art",
        access_required = 75
    },
    update_artist_info = {
        required = {"id"},
        optional = {"filter"},
        description = "Updates artist information and fetches similar artists",
        access_required = 75
    },
    update_from_tags = {
        required = {"type", "id"},
        optional = {"filter"},
        description = "Updates a single album, artist, song from tag data"
    },
    update_podcast = {
        required = {"filter"},
        optional = {"id"},
        description = "Syncs and downloads new podcast episodes",
        access_required = 50
    },
    url_to_song = {
        required = {"url"},
        optional = {"filter"},
        description = "Returns the song object for a URL"
    },
    user = {
        required = {},
        optional = {"username"},
        description = "Gets a user's public information"
    },
    user_create = {
        required = {"username", "password", "email"},
        optional = {"fullname", "disable", "group"},
        description = "Creates a new user",
        access_required = 100
    },
    user_delete = {
        required = {"username"},
        optional = {},
        description = "Deletes an existing user",
        access_required = 100
    },
    user_edit = {
        required = {"username"},
        optional = {"password", "email", "fullname", "website", "state", "city", "disable", "group", "maxbitrate", "fullname_public", "reset_apikey", "reset_streamtoken", "clear_stats"},
        description = "Updates an existing user",
        access_required = 100
    },
    user_playlists = {
        required = {},
        optional = {"filter", "exact", "include", "add", "update", "offset", "limit", "cond", "sort"},
        description = "Returns playlists based on specified filter"
    },
    user_preference = {
        required = {"filter"},
        optional = {},
        description = "Gets user preference by name"
    },
    user_smartlists = {
        required = {},
        optional = {"filter", "exact", "include", "add", "update", "offset", "limit", "cond", "sort"},
        description = "Returns smartlists based on specified filter"
    },
    videos = {
        required = {},
        optional = {"filter", "exact", "offset", "limit"},
        description = "Returns video objects"
    },
    video = {
        required = {"filter"},
        optional = {},
        description = "Returns a single video"
    },
    
    -- Binary Data Methods
    download = {
        required = {"id"},
        optional = {"filter", "type", "bitrate", "format", "stats"},
        description = "Downloads a given media file"
    },
    get_art = {
        required = {"id"},
        optional = {"filter", "type", "size"},
        description = "Gets an art image"
    },
    stream = {
        required = {"id"},
        optional = {"filter", "type", "bitrate", "format", "offset", "length", "stats"},
        description = "Streams a given media file"
    },
    
    -- Control Methods
    democratic = {
        required = {"oid", "method"},
        optional = {},
        description = "Controls democratic play"
    },
    localplay = {
        required = {"command"},
        optional = {"oid", "filter", "type", "clear"},
        description = "Controls localplay"
    }
}

return {
    methods = api_methods,
    
    -- Function to get method definition
    getMethod = function(method_name)
        return api_methods[method_name]
    end,
    
    -- Function to validate parameters for a method
    validateMethod = function(method_name, params)
        local method = api_methods[method_name]
        if not method then
            return false, "Unknown method: " .. method_name
        end
        
        -- Check required parameters
        for _, required_param in ipairs(method.required) do
            if params[required_param] == nil then
                return false, "Missing required parameter: " .. required_param
            end
        end
        
        return true, "OK"
    end
}
