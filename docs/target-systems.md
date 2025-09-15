# Target Systems Integration

## Supported Target Systems

Dusa Bridge provides unified integration with multiple target systems, allowing developers to create interactive elements that work across different targeting solutions.

## OX Target

### Configuration
- **Resource Name**: `ox_target`
- **Modern targeting system with advanced features**

### Features
- Entity targeting
- Model targeting
- Bone targeting
- Network entity support
- Zone-based targeting
- Distance optimization

### Usage Example
```lua
-- Add box zone target
Target.AddBoxZone('mechanic_shop', vector3(100.0, 200.0, 30.0), 2.0, 2.0, {
    name = 'mechanic_shop',
    heading = 0.0,
    debugPoly = false,
    minZ = 29.0,
    maxZ = 31.0
}, {
    options = {
        {
            type = 'client',
            event = 'mechanic:openMenu',
            icon = 'fas fa-wrench',
            label = 'Open Mechanic Menu'
        }
    },
    distance = 2.5
})
```

## QB-Target

### Configuration
- **Resource Name**: `qb-target`
- **QBCore's targeting system**

### Features
- Player targeting
- Vehicle targeting
- Object targeting
- Model-based targeting
- Job restrictions

### Usage Example
```lua
-- Add target to specific model
Target.AddTargetModel({'prop_atm_01', 'prop_atm_02'}, {
    options = {
        {
            type = 'client',
            event = 'banking:openATM',
            icon = 'fas fa-credit-card',
            label = 'Use ATM',
            job = 'all'
        }
    },
    distance = 2.0
})
```

## QTarget

### Configuration
- **Resource Name**: `qtarget`
- **Alternative QB targeting system**

### Features
- Similar to QB-Target
- Enhanced performance
- Custom styling options

## Meta Target

### Configuration
- **Resource Name**: `meta_target`
- **Advanced targeting solution**

### Features
- Multi-framework support
- Custom UI themes
- Advanced filtering
- Performance optimizations

## Unified Target API

### Zone Creation

```lua
-- Box Zone
Target.AddBoxZone(name, coords, length, width, options)

-- Circle Zone
Target.AddCircleZone(name, coords, radius, options)

-- Poly Zone
Target.AddPolyZone(name, points, options)

-- Example: Shop zone
Target.AddBoxZone('general_store', vector3(25.7, -1347.3, 29.49), 2.0, 2.0, {
    name = 'general_store',
    heading = 0,
    debugPoly = false,
    minZ = 28.5,
    maxZ = 30.5
}, {
    options = {
        {
            type = 'client',
            event = 'shop:openMenu',
            icon = 'fas fa-shopping-cart',
            label = 'Browse Shop'
        }
    },
    distance = 2.5
})
```

### Entity Targeting

```lua
-- Add target to specific entity
Target.AddEntityZone(name, entity, options)

-- Add target to entity model
Target.AddTargetModel(models, options)

-- Example: Vehicle targeting
Target.AddTargetModel({'adder', 'zentorno'}, {
    options = {
        {
            type = 'client',
            event = 'vehicle:tune',
            icon = 'fas fa-car',
            label = 'Tune Vehicle',
            job = 'mechanic'
        }
    },
    distance = 3.0
})
```

### Player Targeting

```lua
-- Add player target options
Target.AddGlobalPlayer({
    options = {
        {
            type = 'client',
            event = 'police:cuff',
            icon = 'fas fa-handcuffs',
            label = 'Cuff Player',
            job = 'police'
        },
        {
            type = 'client',
            event = 'ems:revive',
            icon = 'fas fa-heart',
            label = 'Revive Player',
            job = 'ambulance'
        }
    },
    distance = 2.0
})
```

### Zone Management

```lua
-- Remove zone
Target.RemoveZone(name)

-- Example: Temporary event zone
local function CreateEventZone()
    Target.AddCircleZone('event_zone', vector3(0.0, 0.0, 50.0), 10.0, {
        name = 'event_zone',
        debugPoly = false
    }, {
        options = {
            {
                type = 'client',
                event = 'event:participate',
                icon = 'fas fa-star',
                label = 'Join Event'
            }
        },
        distance = 10.0
    })

    -- Remove after 30 minutes
    SetTimeout(30 * 60 * 1000, function()
        Target.RemoveZone('event_zone')
    end)
end
```

## Advanced Target Features

### Job Restrictions

```lua
-- Job-specific targeting
Target.AddBoxZone('police_station', vector3(441.0, -975.0, 30.0), 5.0, 5.0, {
    name = 'police_station'
}, {
    options = {
        {
            type = 'client',
            event = 'police:clockIn',
            icon = 'fas fa-clock',
            label = 'Clock In',
            job = 'police'
        },
        {
            type = 'client',
            event = 'police:armory',
            icon = 'fas fa-gun',
            label = 'Access Armory',
            job = 'police',
            grade = 2 -- Minimum grade required
        }
    },
    distance = 2.0
})
```

### Conditional Options

```lua
-- Dynamic options based on conditions
local function GetVehicleOptions()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local options = {}

    if vehicle ~= 0 then
        table.insert(options, {
            type = 'client',
            event = 'vehicle:exit',
            icon = 'fas fa-sign-out-alt',
            label = 'Exit Vehicle'
        })

        if GetPedInVehicleSeat(vehicle, -1) == ped then
            table.insert(options, {
                type = 'client',
                event = 'vehicle:engine',
                icon = 'fas fa-power-off',
                label = 'Toggle Engine'
            })
        end
    end

    return options
end

-- Update vehicle targeting
CreateThread(function()
    while true do
        local options = GetVehicleOptions()
        Target.UpdateGlobalVehicle(options)
        Wait(1000)
    end
end)
```

### Custom Distance Checks

```lua
-- Custom distance validation
Target.AddBoxZone('custom_shop', vector3(100.0, 200.0, 30.0), 2.0, 2.0, {
    name = 'custom_shop'
}, {
    options = {
        {
            type = 'client',
            event = 'shop:open',
            icon = 'fas fa-shopping-bag',
            label = 'Open Shop',
            canInteract = function()
                local playerJob = Framework.GetPlayerData().job.name
                local hasKey = Inventory.HasItem('shop_key')
                return playerJob == 'shopowner' or hasKey
            end
        }
    },
    distance = 2.0
})
```

## Target System Events

### Client Events

```lua
-- Handle target interactions
RegisterNetEvent('shop:openMenu', function(data)
    -- Open shop UI
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'openShop',
        items = GetShopItems()
    })
end)

-- Vehicle interaction
RegisterNetEvent('vehicle:tune', function(data)
    local vehicle = data.entity
    if vehicle then
        -- Open tuning menu for vehicle
        TriggerEvent('tuning:openMenu', vehicle)
    end
end)
```

### Server Events

```lua
-- Handle server-side target events
RegisterNetEvent('police:cuff', function(targetId)
    local source = source
    local target = tonumber(targetId)

    if target and GetPlayerPed(target) then
        -- Cuff player logic
        TriggerClientEvent('police:getCuffed', target, source)
    end
end)
```

## Target System Configuration

### OX Target Configuration

```lua
-- override.lua
override.target = 'ox_target'
override.targetname = 'ox_target'
```

### QB-Target Configuration

```lua
-- override.lua
override.target = 'qb-target'
override.targetname = 'qb-target'
```

### Custom Target Configuration

```lua
-- override.lua
override.target = 'custom_target'
override.targetname = 'my_target_system'
```

## Performance Optimization

### Zone Batching

```lua
-- Batch zone creation
local zones = {
    {
        name = 'shop1',
        coords = vector3(100.0, 200.0, 30.0),
        type = 'box',
        options = { /* ... */ }
    },
    {
        name = 'shop2',
        coords = vector3(150.0, 250.0, 30.0),
        type = 'circle',
        options = { /* ... */ }
    }
}

for _, zone in pairs(zones) do
    if zone.type == 'box' then
        Target.AddBoxZone(zone.name, zone.coords, 2.0, 2.0, {}, zone.options)
    elseif zone.type == 'circle' then
        Target.AddCircleZone(zone.name, zone.coords, 2.0, {}, zone.options)
    end
end
```

### Dynamic Loading

```lua
-- Load zones based on player location
local loadedZones = {}

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())

        -- Load nearby zones
        for _, zone in pairs(CONFIG_ZONES) do
            local distance = #(playerCoords - zone.coords)

            if distance < 100.0 and not loadedZones[zone.name] then
                Target.AddBoxZone(zone.name, zone.coords, zone.size.x, zone.size.y, {}, zone.options)
                loadedZones[zone.name] = true
            elseif distance > 150.0 and loadedZones[zone.name] then
                Target.RemoveZone(zone.name)
                loadedZones[zone.name] = nil
            end
        end

        Wait(5000) -- Check every 5 seconds
    end
end)
```

## Migration Between Target Systems

### Universal Target Wrapper

```lua
-- Create wrapper for easy migration
local TargetWrapper = {}

function TargetWrapper.AddZone(zoneType, name, coords, size, options, targetOptions)
    if Bridge.Target == 'ox_target' then
        if zoneType == 'box' then
            exports.ox_target:addBoxZone(name, coords, size.x, size.y, options, targetOptions)
        elseif zoneType == 'circle' then
            exports.ox_target:addSphereZone(name, coords, size.radius, options, targetOptions)
        end
    elseif Bridge.Target == 'qb-target' then
        if zoneType == 'box' then
            exports['qb-target']:AddBoxZone(name, coords, size.x, size.y, options, targetOptions)
        elseif zoneType == 'circle' then
            exports['qb-target']:AddCircleZone(name, coords, size.radius, options, targetOptions)
        end
    end
end
```

## Troubleshooting Target Issues

### Common Issues

1. **Targets Not Appearing**: Check resource start order and dependencies
2. **Performance Issues**: Reduce number of zones or increase distance checks
3. **Options Not Working**: Verify event names and job requirements
4. **Zone Overlap**: Check for conflicting zone names

### Debug Tools

```lua
-- Debug target zones
RegisterCommand('debugtargets', function()
    if Bridge.Target == 'ox_target' then
        exports.ox_target:debug(true)
    elseif Bridge.Target == 'qb-target' then
        exports['qb-target']:ToggleDebug()
    end
end)

-- List active zones
RegisterCommand('listzones', function()
    print('Active zones:', json.encode(loadedZones, {indent = true}))
end)
```