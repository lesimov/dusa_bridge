# Framework Integration

## Supported Frameworks

Dusa Bridge provides seamless integration with multiple FiveM frameworks through a unified API that abstracts framework-specific differences.

## ESX Integration

### Configuration
- **Resource Name**: `es_extended`
- **Event**: `esx:getSharedObject`
- **Prefix**: `esx`

### Features
- Player data management
- Job system integration
- Item and inventory management
- Vehicle management
- Society system support

### Usage Example
```lua
-- Get player data
local xPlayer = Framework.Player
print('Player job:', xPlayer.Job.Name)

-- Server-side player management
local xPlayer = Framework.GetPlayer(source)
xPlayer.addMoney('bank', 1000)
```

## QBCore Integration

### Configuration
- **Resource Name**: `qb-core`
- **Event**: `QBCore:GetObject`
- **Prefix**: `QBCore`

### Features
- Player data management
- Job and gang systems
- Metadata system
- Vehicle keys integration
- Banking system support

### Usage Example
```lua
-- Get player data
local PlayerData = Framework.Player
print('Player identifier:', PlayerData.Identifier)

-- Server-side player management
local Player = Framework.GetPlayer(source)
Player.Functions.AddMoney('bank', 1000)
```

## QBox Integration

### Configuration
- **Resource Name**: `qbx_core`
- **Prefix**: `QBCore`

### Features
- Modern QBCore variant
- Enhanced performance
- Improved exports system
- Advanced player management

### Usage Example
```lua
-- Get player data
local PlayerData = Framework.Player
print('Player source:', PlayerData.source)

-- Server-side operations
local player = Framework.GetPlayer(source)
player.addMoney('cash', 500)
```

## OX Core Integration

### Configuration
- **Resource Name**: `ox_core`
- **Prefix**: `ox`

### Features
- Modern framework architecture
- Group system integration
- Advanced permission system
- State management

### Usage Example
```lua
-- Get player data
local player = Framework.Player
print('Player name:', player.get('firstName'))

-- Server-side operations
local player = Framework.GetPlayer(source)
player.set('money', player.get('money') + 1000)
```

## vRP Integration

### Configuration
- **Resource Name**: `vrp`

### Features
- User management
- Permission system
- Item system
- Vehicle system

### Usage Example
```lua
-- Get user ID
local user_id = Framework.GetUserId(source)

-- Money operations
Framework.AddMoney(user_id, 1000)
```

## NDCore Integration

### Configuration
- **Resource Name**: `ND_Core`
- **Prefix**: `ND`

### Features
- Character system
- Job management
- Vehicle ownership
- Banking integration

### Usage Example
```lua
-- Get player data
local player = Framework.Player
print('Character ID:', player.character.id)
```

## Unified Framework API

The bridge provides a consistent API regardless of the underlying framework:

### Player Management

```lua
-- Client-side
local playerData = Framework.Player
local job = playerData.Job or playerData.job or playerData.groups

-- Server-side
local player = Framework.GetPlayer(source)
Framework.AddMoney(source, 'cash', 1000)
Framework.RemoveMoney(source, 'bank', 500)
```

### Callbacks

```lua
-- Register server callback
Framework.RegisterCallback('myResource:getData', function(source, cb, data)
    local result = ProcessData(data)
    cb(result)
end)

-- Call from client
Framework.TriggerCallback('myResource:getData', function(result)
    print('Received:', result)
end, inputData)
```

### Events

```lua
-- Framework-agnostic events
Framework.TriggerEvent('myResource:playerReady', source)
Framework.RegisterEvent('myResource:updateData', function(data)
    UpdatePlayerData(data)
end)
```

### Player Identification

```lua
-- Get unique player identifier
local identifier = Framework.GetIdentifier(source)

-- Works across all frameworks:
-- ESX: steam:110000XXXXX or license:XXXXX
-- QBCore: Identifier
-- OX: character ID
```

## Framework-Specific Configurations

### Custom ESX Setup

```lua
-- override.lua
override.framework = 'esx'
override.frameworkname = 'my_esx'
override.frameworkevent = 'esx:getSharedObject'
override.frameworkprefix = 'ESX'
```

### Custom QBCore Setup

```lua
-- override.lua
override.framework = 'qb'
override.frameworkname = 'my_qbcore'
override.frameworkevent = 'QBCore:GetObject'
override.frameworkprefix = 'QBCore'
```

## Migration Between Frameworks

The bridge makes it easier to migrate resources between frameworks:

```lua
-- This code works on any supported framework
local function GivePlayerMoney(source, amount)
    local player = Framework.GetPlayer(source)
    if player then
        Framework.AddMoney(source, 'cash', amount)
        Framework.Notify(source, 'You received $' .. amount)
    end
end
```

## Framework Detection

The bridge automatically detects your framework:

```lua
-- Check current framework
if Bridge.Framework == 'esx' then
    -- ESX-specific code
elseif Bridge.Framework == 'qb' then
    -- QBCore-specific code
end
```

## Advanced Framework Features

### Job System Integration

```lua
-- Get player job (works across frameworks)
local function GetPlayerJob(source)
    local player = Framework.GetPlayer(source)
    if Bridge.Framework == 'esx' then
        return player.job
    elseif Bridge.Framework == 'qb' then
        return player.PlayerData.job
    elseif Bridge.Framework == 'ox' then
        return player.getGroup()
    end
end
```

### Inventory Integration

```lua
-- Framework-agnostic inventory operations
local function GiveItem(source, item, count)
    if Bridge.Framework == 'esx' then
        local xPlayer = Framework.GetPlayer(source)
        xPlayer.addInventoryItem(item, count)
    elseif Bridge.Framework == 'qb' then
        local Player = Framework.GetPlayer(source)
        Player.Functions.AddItem(item, count)
    end
end
```

## Troubleshooting Framework Issues

### Framework Not Detected

1. Check framework resource is started before bridge
2. Verify framework resource name matches expected names
3. Use override configuration for custom names

### Framework Events Not Working

1. Ensure proper event registration order
2. Check framework-specific event naming conventions
3. Verify callback registration timing

### Player Data Issues

1. Check player data structure for your framework
2. Verify player is fully loaded before accessing data
3. Use framework-specific player ready events