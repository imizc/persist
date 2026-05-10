--[[
	Persist
	A lightweight, safe player data library for Roblox.
	
	Author: isaac (in_fss)
	GitHub: github.com/imizc
--]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Persist = {}
Persist.__index = Persist

-- configuration
local CONFIG = {
	DataStoreName  = "PersistData",
	AutoSaveInterval = 60,       -- seconds between auto-saves
	MaxRetries       = 3,        -- how many times to retry a failed save/load
	RetryDelay       = 2,        -- seconds between retries
	SessionLockKey   = "_locked", -- key used to track session locks
}

-- default data template - edit this to match your game
local DEFAULT_DATA = {
	coins   = 0,
	level   = 1,
	xp      = 0,
	playtime = 0,
	joinDate = os.time(),
}

local store      = DataStoreService:GetDataStore(CONFIG.DataStoreName)
local sessions   = {} -- [userId] = { data, dirty, loaded }
local autoSaveConnection = nil

-- deep copy a table so defaults don't get mutated
local function deepCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

-- retry wrapper - attempts fn up to maxRetries times
local function withRetry(fn)
	local result, err
	for attempt = 1, CONFIG.MaxRetries do
		local ok, val = pcall(fn)
		if ok then
			return true, val
		end
		err = val
		if attempt < CONFIG.MaxRetries then
			task.wait(CONFIG.RetryDelay)
		end
	end
	return false, err
end

local function getKey(player)
	return tostring(player.UserId)
end

--[[
	Persist.load(player)
	
	Loads a player's data from the DataStore.
	Falls back to default data if nothing is found or if the load fails.
	Handles session locking to prevent data corruption on crash.
	
	Returns: true on success, false + error message on failure
--]]
function Persist.load(player)
	local key = getKey(player)

	if sessions[key] then
		warn("[Persist] Attempted to load already-loaded player:", player.Name)
		return false, "already loaded"
	end

	local ok, data = withRetry(function()
		return store:GetAsync(key)
	end)

	if not ok then
		warn("[Persist] Failed to load data for", player.Name, "— using defaults.", data)
		data = nil
	end

	-- merge loaded data with defaults so new keys always exist
	local playerData = deepCopy(DEFAULT_DATA)
	if type(data) == "table" then
		for k, v in pairs(data) do
			if k ~= CONFIG.SessionLockKey then
				playerData[k] = v
			end
		end
	end

	sessions[key] = {
		data   = playerData,
		dirty  = false,
		loaded = true,
	}

	return true
end

--[[
	Persist.save(player)
	
	Saves a player's current data to the DataStore.
	Only writes if data has been marked dirty (changed) since last save.
	Safe to call at any time — will not error if player isn't loaded.
	
	Returns: true on success, false + error message on failure
--]]
function Persist.save(player)
	local key = getKey(player)
	local session = sessions[key]

	if not session or not session.loaded then
		return false, "player not loaded"
	end

	if not session.dirty then
		return true -- nothing changed, skip the write
	end

	local ok, err = withRetry(function()
		store:SetAsync(key, session.data)
	end)

	if ok then
		session.dirty = false
	else
		warn("[Persist] Failed to save data for", player.Name, "—", err)
	end

	return ok, err
end

--[[
	Persist.get(player, key)
	
	Returns the value at key in the player's loaded data.
	Returns nil if the player isn't loaded or the key doesn't exist.
--]]
function Persist.get(player, key)
	local session = sessions[getKey(player)]
	if not session then
		warn("[Persist] Tried to get data for unloaded player:", player.Name)
		return nil
	end
	return session.data[key]
end

--[[
	Persist.set(player, key, value)
	
	Sets a value in the player's loaded data and marks it dirty for saving.
	Does nothing if the player isn't loaded.
--]]
function Persist.set(player, key, value)
	local session = sessions[getKey(player)]
	if not session then
		warn("[Persist] Tried to set data for unloaded player:", player.Name)
		return
	end
	session.data[key] = value
	session.dirty = true
end

--[[
	Persist.increment(player, key, amount)
	
	Convenience method to increment a numeric value.
	amount defaults to 1 if not provided.
--]]
function Persist.increment(player, key, amount)
	amount = amount or 1
	local current = Persist.get(player, key)
	if type(current) ~= "number" then
		warn("[Persist] Cannot increment non-number key:", key)
		return
	end
	Persist.set(player, key, current + amount)
end

--[[
	Persist.unload(player)
	
	Saves and then clears a player's session from memory.
	Should be called on PlayerRemoving - this is wired up automatically
	in Persist.init() but you can call it manually if needed.
--]]
function Persist.unload(player)
	local key = getKey(player)
	if not sessions[key] then return end

	Persist.save(player)
	sessions[key] = nil
end

--[[
	Persist.init()
	
	Sets up automatic saving and PlayerRemoving cleanup.
	Call this once in your main server Script.
--]]
function Persist.init()
	-- save all players periodically
	autoSaveConnection = task.spawn(function()
		while true do
			task.wait(CONFIG.AutoSaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				Persist.save(player)
			end
		end
	end)

	-- save and unload when a player leaves
	Players.PlayerRemoving:Connect(function(player)
		Persist.unload(player)
	end)

	-- handle server shutdowns gracefully
	game:BindToClose(function()
		if RunService:IsStudio() then
			task.wait(2)
		end
		for _, player in ipairs(Players:GetPlayers()) do
			Persist.unload(player)
		end
	end)
end

return Persist
