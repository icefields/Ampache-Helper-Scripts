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
----     SQLite Database Handler for Ampache      -----
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

local sqlite3 = require("luasql.sqlite3")
local env = sqlite3.sqlite3()

local M = {}

-- Determine DB path
local home_dir = os.getenv("HOME") or os.getenv("USERPROFILE")
local config_dir = home_dir and (home_dir .. "/.config/powerampache") or "."
local db_path = config_dir .. "/music.db"

local function ensure_dir_exists(path)
    -- Basic implementation to create directory if it doesn't exist
    -- Requires lfs, which is already used in other parts of the project
    local lfs = require("lfs")
    local dir = path:match("(.*/)")
    if dir and not lfs.attributes(dir) then
        lfs.mkdir(dir)
    end
end

-- Helper to escape single quotes for SQL
local function escape_sql(s)
    return (s or ""):gsub("'", "''")
end

function M.init()
    ensure_dir_exists(db_path)
    local db, err = env:connect(db_path)
    if not db then
        error("Failed to connect to database: " .. tostring(err))
    end

    -- Create session table
    db:execute[[
        CREATE TABLE IF NOT EXISTS session (
            id INTEGER PRIMARY KEY CHECK (id = 0),
            server_url TEXT,
            username TEXT,
            password_hash TEXT,
            token TEXT,
            token_expire TEXT
        )
    ]]

    -- Create user table
    db:execute[[
        CREATE TABLE IF NOT EXISTS user (
            id INTEGER PRIMARY KEY,
            username TEXT,
            fullname TEXT,
            email TEXT,
            access INTEGER,
            disabled INTEGER,
            last_seen TEXT,
            create_date TEXT
        )
    ]]

    return db
end

function M.save_session(db, server_url, username, password_hash, token, expire)
    -- Clear existing session (we only support one active session)
    db:execute("DELETE FROM session")
    
    local sql = string.format(
        "INSERT INTO session (id, server_url, username, password_hash, token, token_expire) VALUES (0, '%s', '%s', '%s', '%s', '%s')",
        escape_sql(server_url), escape_sql(username), escape_sql(password_hash), escape_sql(token), escape_sql(expire)
    )
    db:execute(sql)
end

function M.load_session(db)
    local cursor = db:execute("SELECT server_url, username, password_hash, token, token_expire FROM session WHERE id = 0")
    local row = cursor:fetch({}, "a")
    cursor:close()
    return row
end

function M.clear_session(db)
    db:execute("DELETE FROM session")
end

function M.save_user(db, user_data)
    if not user_data or not user_data.id then return end
    
    -- Simple upsert: delete then insert
    local del_sql = string.format("DELETE FROM user WHERE id = %d", user_data.id)
    db:execute(del_sql)

    local ins_sql = string.format(
        "INSERT INTO user (id, username, fullname, email, access, disabled, last_seen, create_date) VALUES (%d, '%s', '%s', '%s', %d, %d, '%s', '%s')",
        user_data.id,
        escape_sql(user_data.username),
        escape_sql(user_data.fullname or ""),
        escape_sql(user_data.email or ""),
        user_data.access or 0,
        user_data.disabled or 0,
        escape_sql(user_data.last_seen or ""),
        escape_sql(user_data.create_date or "")
    )
    db:execute(ins_sql)
end

function M.get_user(db)
    local cursor = db:execute("SELECT * FROM user LIMIT 1")
    local row = cursor:fetch({}, "a")
    cursor:close()
    return row
end

return M
