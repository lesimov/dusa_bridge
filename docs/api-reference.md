# API Reference

## Core Bridge API

### Bridge Object

The main bridge object provides access to all detected systems and configuration.

```lua
-- Access bridge information
local bridgeName = Bridge.Name
local bridgeVersion = Bridge.Version
local context = Bridge.Context  -- 'client' or 'server'
local framework = Bridge.Framework
local inventory = Bridge.Inventory
local target = Bridge.Target
```

### Framework API

```lua
-- Get framework object
local framework = Framework

-- Common framework methods (varies by framework)
Framework.Player                    -- Get player data table
Framework.GetPlayers()              -- Get all players (server)
Framework.GetPlayer(source)         -- Get specific player (server)
Framework.RegisterCallback()        -- Register server callback
Framework.TriggerCallback()         -- Trigger callback
```


### Inventory API

```lua
-- Inventory operations
Inventory.GetItem(source, item)              -- Get item from player
Inventory.AddItem(source, item, count)       -- Add item to player
Inventory.RemoveItem(source, item, count)    -- Remove item from player
Inventory.HasItem(source, item, count)       -- Check if player has item
Inventory.GetItems(source)                   -- Get all player items
```

### Target API

```lua
-- Target system integration
Target.AddBoxZone(name, coords, length, width, options)
Target.AddCircleZone(name, coords, radius, options)
Target.AddEntityZone(name, entity, options)
Target.RemoveZone(name)
```

### Zone API

```lua
-- Zone management
Zone.CreateBox(coords, size, rotation, options)
Zone.CreateCircle(coords, radius, options)
Zone.CreatePoly(points, options)
Zone.Remove(zone)
```

### Menu API

```lua
-- Menu system
Menu.Show(menuData)                          -- Show menu
Menu.Hide()                                  -- Hide menu
Menu.RegisterMenu(name, menuData)            -- Register menu
```

## Interaction System API

The interaction system provides a unified way to create interactive elements.

```lua
-- Client-side interaction creation
interact.create({
    coords = vector3(x, y, z),
    distance = 2.0,
    interactDst = 1.5,
    indicator = {
        prompt = 'Press E to interact',
        key = 'E'
    },
    action = function()
        -- Interaction logic
    end
})
```

## Utility Functions

### Player Utilities

```lua
-- Get player identifier
local identifier = Utils.GetIdentifier(source)

-- Get player name
local name = Utils.GetPlayerName(source)

-- Check if player is online
local isOnline = Utils.IsPlayerOnline(source)
```

### Math Utilities

```lua
-- Distance calculations
local distance = Utils.GetDistance(coords1, coords2)

-- Vector operations
local result = Utils.AddVectors(vec1, vec2)
local result = Utils.SubtractVectors(vec1, vec2)
```

### String Utilities

```lua
-- String formatting
local formatted = Utils.FormatString(template, args)

-- String validation
local isValid = Utils.ValidateString(str, pattern)
```

## Event System

### Server Events

```lua
-- Register server event
RegisterNetEvent('dusa_bridge:serverEvent', function(data)
    local source = source
    -- Handle event
end)

-- Trigger client event
TriggerClientEvent('dusa_bridge:clientEvent', source, data)
```

### Client Events

```lua
-- Register client event
RegisterNetEvent('dusa_bridge:clientEvent', function(data)
    -- Handle event
end)

-- Trigger server event
TriggerServerEvent('dusa_bridge:serverEvent', data)
```

## Callback System

### Server Callbacks

```lua
-- Register server callback
Framework.RegisterCallback('dusa_bridge:getData', function(source, cb, args)
    local data = GetSomeData(args)
    cb(data)
end)

-- Client calling server callback
Framework.TriggerCallback('dusa_bridge:getData', function(data)
    -- Handle response
end, args)
```

### Client Callbacks

```lua
-- Register client callback
Framework.RegisterCallback('dusa_bridge:getClientData', function(cb, args)
    local data = GetClientData(args)
    cb(data)
end)

-- Server calling client callback
Framework.TriggerCallback(source, 'dusa_bridge:getClientData', function(data)
    -- Handle response
end, args)
```

## Configuration Access

```lua
-- Access bridge configuration
local isDebugMode = Bridge.DebugMode
local locale = Bridge.Locale
local frameworkName = Bridge.FrameworkName
local inventoryName = Bridge.InventoryName

-- Check if module is disabled
local isDisabled = Bridge.Disabled['moduleName']
```

## Error Handling

```lua
-- Safe function execution
local success, result = pcall(function()
    -- Your code here
    return someFunction()
end)

if not success then
    print('Error:', result)
end
```

## Locale System

```lua
-- Get localized string
local text = Locale('key', args)

-- Register locale strings
Locale.RegisterStrings('en', {
    ['hello'] = 'Hello %s',
    ['goodbye'] = 'Goodbye'
})
```

## Hook System (Server Only)

```lua
-- Register hook
Hook.Register('playerConnect', function(source)
    -- Handle player connection
end)

-- Trigger hook
Hook.Trigger('customEvent', data)
```

## Version Checking

```lua
-- Check bridge version
local version = Bridge.Version

-- Version comparison utilities
local isNewer = Utils.CompareVersions(version1, version2)
```

## Type Definitions

The bridge includes type definitions for better IDE support:

```lua
---@class Bridge
---@field Resource string
---@field Name string
---@field Version string
---@field Context string
---@field Framework string
---@field Inventory string

---@class Framework
---@field GetPlayerData fun(): table
---@field GetPlayers fun(): table

---@class Database
---@field Execute fun(query: string, params: table, callback: function)
---@field Fetch fun(query: string, params: table, callback: function)
```