# Persist

A DataStore library that gets out of your way.

Persist handles the parts nobody wants to write — retry logic, session safety, dirty-flag saves, and graceful shutdowns. Drop it in, define your data shape, and move on.

---

## Installation

Grab `src/Persist.lua` and place it in `ServerScriptService`. Then in a server Script:

```lua
local Persist = require(game.ServerScriptService.Persist)
Persist.init()
```

That's it. Auto-saving and cleanup are wired up from that point on.

---

## Defining your data

Open `Persist.lua` and edit `DEFAULT_DATA` at the top:

```lua
local DEFAULT_DATA = {
    coins    = 0,
    level    = 1,
    xp       = 0,
    playtime = 0,
}
```

New keys added here will show up automatically for existing players on their next load.

---

## Basic usage

```lua
Players.PlayerAdded:Connect(function(player)
    local ok, err = Persist.load(player)
    if not ok then
        player:Kick("Could not load your data. Please rejoin.")
        return
    end

    print(Persist.get(player, "coins"))   -- 0
    Persist.set(player, "coins", 500)
    Persist.increment(player, "xp", 100)
end)
```

---

## API

**`Persist.init()`**
Call once at server start. Sets up the auto-save loop and handles `PlayerRemoving` and `BindToClose`.

**`Persist.load(player)`**
Loads from the DataStore with retry logic. Returns `true` on success or `false, err` on failure.

**`Persist.save(player)`**
Writes to the DataStore only if the session is dirty. Safe to call manually at any time.

**`Persist.get(player, key)`**
Returns the current value at `key` for the player.

**`Persist.set(player, key, value)`**
Sets `key` to `value` and marks the session for saving.

**`Persist.increment(player, key, amount?)`**
Adds `amount` to a numeric key. Defaults to `+1`.

**`Persist.unload(player)`**
Saves and removes the player's session from memory. Called automatically — rarely needed manually.

---

## Configuration

At the top of `Persist.lua`:

| Key | Default | What it does |
|---|---|---|
| `DataStoreName` | `"PersistData"` | The DataStore to read/write from |
| `AutoSaveInterval` | `60` | Seconds between background saves |
| `MaxRetries` | `3` | Attempts before giving up on a request |
| `RetryDelay` | `2` | Seconds between retry attempts |

---

## License

MIT. Use it however you want.

Built by [isaac](https://github.com/imizc).
