--[[
	Example usage of Persist
	Place this in a Script inside ServerScriptService
--]]

local Players = game:GetService("Players")
local Persist = require(game.ServerScriptService.Persist)

-- initialise Persist once — sets up auto-save and PlayerRemoving
Persist.init()

Players.PlayerAdded:Connect(function(player)
	-- load data when the player joins
	local ok, err = Persist.load(player)
	if not ok then
		warn("Failed to load", player.Name, err)
		-- you may want to kick the player here to prevent data loss
		-- player:Kick("Failed to load your data. Please rejoin.")
		return
	end

	-- reading values
	local coins = Persist.get(player, "coins")
	local level = Persist.get(player, "level")
	print(player.Name, "joined - coins:", coins, "level:", level)

	-- setting values
	Persist.set(player, "coins", coins + 100)

	-- incrementing (shorthand for common operations)
	Persist.increment(player, "xp", 50)
	Persist.increment(player, "playtime") -- defaults to +1
end)

-- example: giving coins from another script (e.g. a shop)
local function awardCoins(player, amount)
	Persist.increment(player, "coins", amount)
	print("Awarded", amount, "coins to", player.Name)
end
