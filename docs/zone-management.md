# Zone Management

## Supported Zone Systems

Dusa Bridge provides unified zone management across different zone libraries, allowing developers to create interactive areas with consistent APIs.

## OX Lib Zones

### Configuration
- **Resource Name**: `ox_lib`
- **Modern zone system with advanced features**

### Features
- Box zones
- Sphere zones
- Polygon zones
- Zone callbacks (onEnter, onExit, inside)
- Debug visualization
- Performance optimization

### Usage Example
```lua
-- Create box zone
local zone = Zone.CreateBox({
    coords = vector3(100.0, 200.0, 30.0),
    size = vector3(4.0, 4.0, 2.0),
    rotation = 45.0,
    debug = false,
    onEnter = function(self)
        print('Entered zone:', self.name)
        Framework.Notify('Entered safe zone', 'info')
    end,
    onExit = function(self)
        print('Exited zone:', self.name)
        Framework.Notify('Exited safe zone', 'info')
    end,
    inside = function(self)
        -- Called while inside zone
        DisableControlAction(0, 24, true) -- Disable attack
    end
})
```

## PolyZone

### Configuration
- **Resource Name**: `PolyZone`
- **Polygon-based zone system**

### Features
- Complex polygon shapes
- Box zones
- Circle zones
- Combo zones
- Entity zones

### Usage Example
```lua
-- Create polygon zone
local zone = Zone.CreatePoly({
    points = {
        vector2(100.0, 200.0),
        vector2(120.0, 200.0),
        vector2(120.0, 220.0),
        vector2(100.0, 220.0)
    },
    minZ = 29.0,
    maxZ = 31.0,
    options = {
        name = 'custom_zone',
        debugPoly = false
    },
    onEnter = function(data)
        print('Entered polygon zone')
    end,
    onExit = function(data)
        print('Exited polygon zone')
    end
})
```

## Unified Zone API

### Box Zones

```lua
-- Create box zone
local zone = Zone.CreateBox(coords, size, rotation, options)

-- Example: Safe zone
local safeZone = Zone.CreateBox(
    vector3(0.0, 0.0, 50.0),          -- Center coordinates
    vector3(20.0, 20.0, 5.0),         -- Size (length, width, height)
    0.0,                              -- Rotation
    {
        name = 'safe_zone',
        debug = false,
        onEnter = function(self)
            TriggerEvent('safezone:enter')
        end,
        onExit = function(self)
            TriggerEvent('safezone:exit')
        end,
        inside = function(self)
            SetPlayerInvincible(PlayerId(), true)
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 25, true) -- Aim
        end
    }
)
```

### Circle/Sphere Zones

```lua
-- Create sphere zone
local zone = Zone.CreateCircle(coords, radius, options)

-- Example: Shop zone
local shopZone = Zone.CreateCircle(
    vector3(25.7, -1347.3, 29.49),    -- Center
    5.0,                              -- Radius
    {
        name = 'general_store',
        debug = false,
        onEnter = function(self)
            Framework.Notify('Welcome to General Store!', 'info')
            TriggerEvent('shop:showBlip', true)
        end,
        onExit = function(self)
            TriggerEvent('shop:showBlip', false)
        end
    }
)
```

### Polygon Zones

```lua
-- Create polygon zone
local zone = Zone.CreatePoly(points, options)

-- Example: Complex area
local complexZone = Zone.CreatePoly({
    vector2(100.0, 200.0),
    vector2(150.0, 180.0),
    vector2(170.0, 220.0),
    vector2(130.0, 250.0),
    vector2(90.0, 230.0)
}, {
    name = 'complex_area',
    minZ = 25.0,
    maxZ = 35.0,
    debug = false,
    onEnter = function(self)
        TriggerEvent('area:complexEnter')
    end,
    onExit = function(self)
        TriggerEvent('area:complexExit')
    end
})
```

## Zone Management Functions

### Zone Removal

```lua
-- Remove zone
Zone.Remove(zone)

-- Example: Temporary event zone
local eventZone = Zone.CreateCircle(vector3(0.0, 0.0, 50.0), 10.0, {
    name = 'temp_event'
})

-- Remove after 30 minutes
SetTimeout(30 * 60 * 1000, function()
    Zone.Remove(eventZone)
    print('Event zone removed')
end)
```

### Zone Queries

```lua
-- Check if point is inside zone
local isInside = zone:isPointInside(coords)

-- Get all players in zone (if supported)
local playersInZone = zone:getPlayersInside()

-- Get zone data
local zoneData = {
    name = zone.name,
    coords = zone.coords,
    size = zone.size
}
```

## Advanced Zone Features

### Multiple Zone Types

```lua
-- Combo zone system
local function CreateGangTerritory(territoryData)
    -- Main territory (polygon)
    local mainZone = Zone.CreatePoly(territoryData.points, {
        name = territoryData.name .. '_main',
        minZ = territoryData.minZ,
        maxZ = territoryData.maxZ,
        onEnter = function(self)
            TriggerEvent('gangs:enterTerritory', territoryData.gang)
        end,
        onExit = function(self)
            TriggerEvent('gangs:exitTerritory', territoryData.gang)
        end
    })

    -- Safe zone within territory (circle)
    local safeZone = Zone.CreateCircle(territoryData.safeSpot, 10.0, {
        name = territoryData.name .. '_safe',
        onEnter = function(self)
            TriggerEvent('gangs:enterSafeZone', territoryData.gang)
        end,
        inside = function(self)
            DisableControlAction(0, 24, true) -- No violence in safe zone
        end
    })

    return { main = mainZone, safe = safeZone }
end
```

### Conditional Zones

```lua
-- Zone with conditional behavior
local conditionalZone = Zone.CreateBox(coords, size, 0.0, {
    name = 'police_station',
    onEnter = function(self)
        local playerData = Framework.Player

        if playerData.Job.Name == 'police' then
            TriggerEvent('police:enterStation')
            Framework.Notify('Welcome back, officer!', 'success')
        else
            TriggerEvent('civilian:enterPoliceStation')
            Framework.Notify('You are in a police station', 'info')
        end
    end,
    inside = function(self)
        local playerData = Framework.Player

        if playerData.Job.Name == 'police' then
            -- Police-specific actions
            DrawText3D(self.coords, '[E] Access Police Computer')

            if IsControlJustPressed(0, 38) then -- E key
                TriggerEvent('police:openComputer')
            end
        end
    end
})
```

### Zone Hierarchies

```lua
-- Nested zones
local ZoneManager = {}
ZoneManager.zones = {}

function ZoneManager.CreateHierarchy(parentZone, childZones)
    local hierarchy = {
        parent = parentZone,
        children = {}
    }

    for _, childData in pairs(childZones) do
        local childZone = Zone.CreateBox(childData.coords, childData.size, 0.0, {
            name = childData.name,
            parent = parentZone.name,
            onEnter = function(self)
                -- Check if parent is also active
                if ZoneManager.IsPlayerInZone(parentZone.name) then
                    childData.onEnter(self)
                end
            end
        })

        table.insert(hierarchy.children, childZone)
    end

    ZoneManager.zones[parentZone.name] = hierarchy
    return hierarchy
end

function ZoneManager.IsPlayerInZone(zoneName)
    local zone = ZoneManager.zones[zoneName]
    if zone and zone.parent then
        return zone.parent:isPointInside(GetEntityCoords(PlayerPedId()))
    end
    return false
end
```

## Zone Performance Optimization

### Dynamic Zone Loading

```lua
-- Performance-optimized zone management
local ZoneLoader = {}
ZoneLoader.activeZones = {}
ZoneLoader.zoneDefinitions = {} -- Load from config

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())

        -- Load nearby zones
        for zoneId, zoneDef in pairs(ZoneLoader.zoneDefinitions) do
            local distance = #(playerCoords - zoneDef.coords)

            if distance < 100.0 and not ZoneLoader.activeZones[zoneId] then
                ZoneLoader.LoadZone(zoneId, zoneDef)
            elseif distance > 150.0 and ZoneLoader.activeZones[zoneId] then
                ZoneLoader.UnloadZone(zoneId)
            end
        end

        Wait(5000) -- Check every 5 seconds
    end
end)

function ZoneLoader.LoadZone(zoneId, zoneDef)
    local zone = Zone.CreateBox(zoneDef.coords, zoneDef.size, zoneDef.rotation, zoneDef.options)
    ZoneLoader.activeZones[zoneId] = zone
    print('Loaded zone:', zoneId)
end

function ZoneLoader.UnloadZone(zoneId)
    local zone = ZoneLoader.activeZones[zoneId]
    if zone then
        Zone.Remove(zone)
        ZoneLoader.activeZones[zoneId] = nil
        print('Unloaded zone:', zoneId)
    end
end
```

### Zone Pooling

```lua
-- Zone object pooling for performance
local ZonePool = {}
ZonePool.available = {}
ZonePool.inUse = {}

function ZonePool.GetZone(zoneType)
    local pool = ZonePool.available[zoneType]

    if pool and #pool > 0 then
        local zone = table.remove(pool)
        ZonePool.inUse[zone.id] = zone
        return zone
    else
        -- Create new zone
        local zone = CreateNewZone(zoneType)
        ZonePool.inUse[zone.id] = zone
        return zone
    end
end

function ZonePool.ReturnZone(zone)
    if ZonePool.inUse[zone.id] then
        ZonePool.inUse[zone.id] = nil

        -- Reset zone properties
        zone:reset()

        -- Return to pool
        local zoneType = zone.type
        if not ZonePool.available[zoneType] then
            ZonePool.available[zoneType] = {}
        end

        table.insert(ZonePool.available[zoneType], zone)
    end
end
```

## Zone Integration Examples

### Business Zones

```lua
-- Business management with zones
local BusinessZones = {}

function BusinessZones.CreateBusiness(businessData)
    -- Main business zone
    local businessZone = Zone.CreateBox(businessData.coords, businessData.size, 0.0, {
        name = 'business_' .. businessData.id,
        onEnter = function(self)
            TriggerEvent('business:enter', businessData.id)

            if businessData.isOwner then
                Framework.Notify('Welcome to your business!', 'success')
            else
                Framework.Notify('Welcome to ' .. businessData.name, 'info')
            end
        end,
        onExit = function(self)
            TriggerEvent('business:exit', businessData.id)
        end,
        inside = function(self)
            -- Show business info
            DrawText3D(businessData.coords, businessData.name)

            if businessData.isOwner then
                DrawText3D(businessData.coords - vector3(0, 0, 0.5), '[E] Manage Business')

                if IsControlJustPressed(0, 38) then
                    TriggerEvent('business:openManagement', businessData.id)
                end
            end
        end
    })

    -- Employee zones
    for _, employeeArea in pairs(businessData.employeeAreas or {}) do
        Zone.CreateBox(employeeArea.coords, employeeArea.size, 0.0, {
            name = 'employee_' .. businessData.id .. '_' .. employeeArea.name,
            onEnter = function(self)
                local playerData = Framework.Player
                if playerData.Job.Name == businessData.jobName then
                    TriggerEvent('business:enterEmployeeArea', businessData.id, employeeArea.name)
                end
            end
        })
    end

    return businessZone
end
```

### Event Zones

```lua
-- Dynamic event zones
local EventZones = {}

function EventZones.CreateEventZone(eventData)
    local eventZone = Zone.CreateCircle(eventData.coords, eventData.radius, {
        name = 'event_' .. eventData.id,
        debug = eventData.debug or false,
        onEnter = function(self)
            TriggerServerEvent('events:playerEntered', eventData.id)
        end,
        onExit = function(self)
            TriggerServerEvent('events:playerExited', eventData.id)
        end,
        inside = function(self)
            -- Event-specific behavior
            if eventData.type == 'race' then
                HandleRaceZone(eventData)
            elseif eventData.type == 'deathmatch' then
                HandleDeathmatchZone(eventData)
            end
        end
    })

    -- Auto-remove after event duration
    if eventData.duration then
        SetTimeout(eventData.duration * 1000, function()
            Zone.Remove(eventZone)
            print('Event zone removed:', eventData.id)
        end)
    end

    return eventZone
end
```

## Troubleshooting Zone Issues

### Common Problems

1. **Zone not triggering**: Check coordinates and size
2. **Performance issues**: Reduce number of active zones
3. **Callback not firing**: Verify event registration
4. **Z-axis problems**: Check minZ/maxZ values for polygon zones

### Debug Tools

```lua
-- Debug zone information
RegisterCommand('debugzones', function()
    if Bridge.Zone == 'ox_lib' then
        for zoneName, zone in pairs(lib.zones) do
            print('Zone:', zoneName, 'Active:', zone.active)
        end
    end
end)

-- Visualize zones
RegisterCommand('showzones', function()
    ZoneManager.debugMode = not ZoneManager.debugMode
    print('Zone debug mode:', ZoneManager.debugMode)
end)
```