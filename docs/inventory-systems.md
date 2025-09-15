# Inventory Systems Integration

## Supported Inventory Systems

Dusa Bridge provides comprehensive integration with multiple inventory systems, abstracting their differences through a unified API.

## OX Inventory

### Configuration
- **Resource Name**: `ox_inventory`
- **Image Path**: `ox_inventory/web/images/`
- **Type**: Modern inventory system

### Features
- Slot-based inventory
- Item metadata support
- Drag and drop interface
- Weight system
- Inventory logs

### Usage Example
```lua
-- Add item with metadata
Inventory.AddItem(source, 'weapon_pistol', 1, {
    serial = 'ABC123',
    ammo = 15
})

-- Check item with metadata
local item = Inventory.GetItem(source, 'weapon_pistol')
if item and item.metadata.serial == 'ABC123' then
    print('Found specific weapon')
end
```

## QB-Inventory Family

### QB-Inventory
- **Resource Name**: `qb-inventory`
- **Image Path**: `qb-inventory/html/images/`

### LJ-Inventory
- **Resource Name**: `lj-inventory`
- **Image Path**: `lj-inventory/html/images/`

### AJ-Inventory
- **Resource Name**: `aj-inventory`
- **Image Path**: `aj-inventory/html/images/`

### AX-Inventory
- **Resource Name**: `ax-inventory`
- **Image Path**: `ax-inventory/html/images/`

### PS-Inventory
- **Resource Name**: `ps-inventory`
- **Image Path**: `ps-inventory/html/images/`

### AK47 Inventory
- **Resource Name**: `ak47_inventory`
- **Image Path**: `ak47_inventory/html/images/`

### Codem Inventory
- **Resource Name**: `codem-inventory`
- **Image Path**: `codem-inventory/html/itemimages/`

### L2S Inventory
- **Resource Name**: `l2s-inventory`
- **Image Path**: `l2s-inventory/html/images/`

### Features
- QBCore integration
- Item durability
- Custom item images
- Hotbar system
- Inventory sharing

## QS-Inventory

### Configuration
- **Resource Name**: `qs-inventory`
- **Image Path**: `qs-inventory/html/images/`

### Features
- Advanced UI
- Custom animations
- Item combinations
- Crafting system integration

## TGiann Inventory

### Configuration
- **Resource Name**: `tgiann-inventory`
- **Image Path**: `inventory_images/images/`

### Features
- Modern interface
- Advanced item system
- Custom styling options

## Core Inventory

### Configuration
- **Resource Name**: `core_inventory`
- **Image Path**: `core_inventory/html/img/`

### Features
- Core framework integration
- Basic inventory management
- Simple item operations

## Unified Inventory API

### Basic Operations

```lua
-- Add item to player
Inventory.AddItem(source, 'bread', 5)

-- Remove item from player
Inventory.RemoveItem(source, 'bread', 2)

-- Get specific item
local item = Inventory.GetItem(source, 'bread')
if item then
    print('Player has', item.count, 'bread')
end

-- Check if player has item
local hasItem = Inventory.HasItem(source, 'bread', 3)
if hasItem then
    print('Player has at least 3 bread')
end

-- Get all items
local items = Inventory.GetItems(source)
for slot, item in pairs(items) do
    print('Slot', slot, ':', item.name, 'x', item.count)
end
```

### Advanced Operations

```lua
-- Add item with metadata (OX Inventory)
Inventory.AddItem(source, 'phone', 1, {
    number = '555-0123',
    battery = 100,
    contacts = {}
})

-- Add item with info (QB-Inventory family)
Inventory.AddItem(source, 'phone', 1, false, {
    number = '555-0123',
    battery = 100
})

-- Transfer items between players
Inventory.TransferItem(sourcePlayer, targetPlayer, 'money', 1000)

-- Set item durability
Inventory.SetItemDurability(source, 'weapon_pistol', 75)
```

### Inventory Events

```lua
-- Listen for item use
RegisterNetEvent('inventory:itemUsed', function(item)
    if item.name == 'bread' then
        -- Handle bread usage
        Framework.AddHealth(source, 25)
    end
end)

-- Listen for item received
RegisterNetEvent('inventory:itemReceived', function(item, count)
    print('Player received', count, 'of', item.name)
end)
```

## Item Image Management

### Automatic Path Detection

The bridge automatically detects the correct image path for your inventory system:

```lua
-- Get item image URL
local function GetItemImage(itemName)
    local imagePath = Bridge.InventoryImagePath
    return ('nui://%s%s.png'):format(imagePath, itemName)
end

-- Usage in NUI
SendNUIMessage({
    type = 'showItem',
    item = 'bread',
    image = GetItemImage('bread')
})
```

### Custom Image Paths

```lua
-- Override image path
override.imagepath = "my_custom_inventory/images/"

-- Framework-specific paths
if Bridge.Inventory == 'ox_inventory' then
    imagePath = 'ox_inventory/web/images/'
elseif Bridge.Inventory == 'qb-inventory' then
    imagePath = 'qb-inventory/html/images/'
end
```

## Inventory-Specific Configurations

### OX Inventory Configuration

```lua
-- override.lua
override.inventory = 'ox_inventory'
override.inventoryname = 'ox_inventory'
override.imagepath = "ox_inventory/web/images/"
```

### QB-Inventory Configuration

```lua
-- override.lua
override.inventory = 'qb-inventory'
override.inventoryname = 'qb-inventory'
override.imagepath = "qb-inventory/html/images/"
```

### Custom Inventory Configuration

```lua
-- override.lua
override.inventory = 'custom_inventory'
override.inventoryname = 'my_inventory'
override.imagepath = "my_inventory/html/images/"
```

## Item Registration

### Register Usable Items

```lua
-- Framework-agnostic item registration
local function RegisterUsableItem(itemName, callback)
    if Bridge.Framework == 'esx' then
        ESX.RegisterUsableItem(itemName, callback)
    elseif Bridge.Framework == 'qb' then
        QBCore.Functions.CreateUseableItem(itemName, callback)
    end
end

-- Register bread as usable
RegisterUsableItem('bread', function(source)
    Inventory.RemoveItem(source, 'bread', 1)
    Framework.AddHealth(source, 25)
    Framework.Notify(source, 'You ate bread and restored health')
end)
```

### Item Metadata Handling

```lua
-- OX Inventory metadata
local function AddWeaponWithSerial(source, weapon, serial)
    if Bridge.Inventory == 'ox_inventory' then
        Inventory.AddItem(source, weapon, 1, {
            serial = serial,
            ammo = exports.ox_inventory:GetWeaponAmmoCount(weapon)
        })
    else
        -- Fallback for other inventories
        Inventory.AddItem(source, weapon, 1)
    end
end
```

## Inventory UI Integration

### Opening Custom Inventories

```lua
-- Open inventory UI
local function OpenCustomInventory(source, inventoryType, items)
    if Bridge.Inventory == 'ox_inventory' then
        exports.ox_inventory:forceOpenInventory(source, inventoryType, items)
    elseif Bridge.Inventory == 'qb-inventory' then
        TriggerClientEvent('inventory:client:OpenInventory', source, items)
    end
end
```

### Inventory Notifications

```lua
-- Unified notification system
local function NotifyInventoryAction(source, message, type)
    if Bridge.Framework == 'esx' then
        TriggerClientEvent('esx:showNotification', source, message)
    elseif Bridge.Framework == 'qb' then
        TriggerClientEvent('QBCore:Notify', source, message, type)
    end
end
```

## Migration Between Inventory Systems

### Data Migration

```lua
-- Migrate inventory data structure
local function MigrateInventoryData(oldData, oldSystem, newSystem)
    local newData = {}

    if oldSystem == 'qb-inventory' and newSystem == 'ox_inventory' then
        for slot, item in pairs(oldData) do
            newData[slot] = {
                name = item.name,
                count = item.amount,
                metadata = item.info or {}
            }
        end
    end

    return newData
end
```

## Troubleshooting Inventory Issues

### Common Issues

1. **Items Not Appearing**: Check image paths and file extensions
2. **Metadata Not Saving**: Verify inventory system supports metadata
3. **Weight Issues**: Check item weight configurations
4. **Sync Problems**: Ensure proper server-client event handling

### Debug Commands

```lua
-- Debug inventory state
RegisterCommand('debuginv', function(source)
    local items = Inventory.GetItems(source)
    print('Player inventory:', json.encode(items, {indent = true}))
end, true)

-- Check inventory system
RegisterCommand('invinfo', function(source)
    print('Inventory System:', Bridge.Inventory)
    print('Image Path:', Bridge.InventoryImagePath)
end, true)
```

## Performance Optimization

### Batch Operations

```lua
-- Batch item operations
local function BatchAddItems(source, items)
    for itemName, count in pairs(items) do
        Inventory.AddItem(source, itemName, count)
    end

    -- Trigger single update event
    TriggerClientEvent('inventory:client:updateInventory', source)
end
```

### Caching

```lua
-- Cache inventory data
local inventoryCache = {}

local function GetCachedInventory(source)
    if not inventoryCache[source] then
        inventoryCache[source] = Inventory.GetItems(source)
    end
    return inventoryCache[source]
end

-- Clear cache on inventory change
RegisterNetEvent('inventory:server:itemChanged', function()
    inventoryCache[source] = nil
end)
```