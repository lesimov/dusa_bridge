# Examples and Use Cases

## Basic Resource Integration

### Simple Shop Resource

```lua
-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Your Name'
description 'Simple Shop'
version '1.0.0'

-- Bridge dependency
dependency 'dusa_bridge'
bridge 'dusa_bridge'

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}
```

```lua
-- client.lua
local shopItems = {
    {name = 'bread', price = 5, label = 'Bread'},
    {name = 'water', price = 3, label = 'Water'},
    {name = 'sandwich', price = 8, label = 'Sandwich'}
}

-- Create shop target zone
CreateThread(function()
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
end)

-- Handle shop menu
RegisterNetEvent('shop:openMenu', function()
    local menuItems = {}

    for _, item in pairs(shopItems) do
        table.insert(menuItems, {
            title = item.label,
            description = 'Price: $' .. item.price,
            event = 'shop:buyItem',
            args = {item = item.name, price = item.price}
        })
    end

    Menu.Show({
        title = 'General Store',
        items = menuItems
    })
end)

-- Handle item purchase
RegisterNetEvent('shop:buyItem', function(data)
    TriggerServerEvent('shop:purchaseItem', data.item, data.price)
end)
```

```lua
-- server.lua

-- Handle item purchase
RegisterNetEvent('shop:purchaseItem', function(itemName, price)
    local source = source
    local player = Framework.GetPlayer(source)

    if not player then return end

    -- Check if player has enough money
    local playerMoney = Framework.GetMoney(source, 'cash')

    if playerMoney >= price then
        -- Remove money and add item
        Framework.RemoveMoney(source, 'cash', price)
        Inventory.AddItem(source, itemName, 1)

        Framework.Notify(source, 'You purchased ' .. itemName .. ' for $' .. price, 'success')
    else
        Framework.Notify(source, 'You don\'t have enough money', 'error')
    end
end)
```


## Vehicle Management System

### Multi-Inventory Vehicle System

```lua
-- client/vehicles.lua

local VehicleSystem = {}

-- Spawn personal vehicle
function VehicleSystem.SpawnVehicle(vehicleData)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    -- Find spawn location
    local spawnCoords = GetSpawnLocation(coords)

    Framework.TriggerCallback('vehicles:spawnVehicle', function(success)
        if success then
            -- Create vehicle
            local hash = GetHashKey(vehicleData.model)
            RequestModel(hash)

            while not HasModelLoaded(hash) do
                Wait(10)
            end

            local vehicle = CreateVehicle(hash, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, true, false)

            -- Set vehicle properties
            SetVehicleProperties(vehicle, vehicleData.props or {})

            -- Give keys (framework dependent)
            GiveVehicleKeys(vehicle, vehicleData.plate)

            Framework.Notify('Vehicle spawned successfully', 'success')
        else
            Framework.Notify('Failed to spawn vehicle', 'error')
        end
    end, vehicleData.plate)
end

-- Vehicle interaction menu
function VehicleSystem.ShowVehicleMenu(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)

    Framework.TriggerCallback('vehicles:getVehicleData', function(vehicleData)
        if not vehicleData then
            Framework.Notify('You don\'t own this vehicle', 'error')
            return
        end

        local menuItems = {
            {
                title = 'Lock/Unlock',
                description = 'Toggle vehicle lock',
                event = 'vehicles:toggleLock',
                args = {vehicle = vehicle}
            },
            {
                title = 'Engine',
                description = 'Toggle engine',
                event = 'vehicles:toggleEngine',
                args = {vehicle = vehicle}
            }
        }

        -- Add trunk option if supported by inventory
        if Bridge.Inventory == 'ox_inventory' or Bridge.Inventory == 'qb-inventory' then
            table.insert(menuItems, {
                title = 'Trunk',
                description = 'Open vehicle trunk',
                event = 'vehicles:openTrunk',
                args = {vehicle = vehicle, plate = plate}
            })
        end

        Menu.Show({
            title = 'Vehicle - ' .. plate,
            items = menuItems
        })
    end, plate)
end

-- Vehicle targeting
CreateThread(function()
    Target.AddGlobalVehicle({
        options = {
            {
                type = 'client',
                event = 'vehicles:showMenu',
                icon = 'fas fa-car',
                label = 'Vehicle Options'
            }
        },
        distance = 2.0
    })
end)

-- Events
RegisterNetEvent('vehicles:showMenu', function(data)
    VehicleSystem.ShowVehicleMenu(data.entity)
end)

RegisterNetEvent('vehicles:toggleLock', function(data)
    local vehicle = data.vehicle
    local locked = GetVehicleDoorLockStatus(vehicle) == 2

    SetVehicleDoorsLocked(vehicle, locked and 1 or 2)
    Framework.Notify(locked and 'Vehicle unlocked' or 'Vehicle locked', 'info')
end)

RegisterNetEvent('vehicles:toggleEngine', function(data)
    local vehicle = data.vehicle
    local engine = GetIsVehicleEngineRunning(vehicle)

    SetVehicleEngineOn(vehicle, not engine, false, true)
    Framework.Notify(engine and 'Engine turned off' or 'Engine started', 'info')
end)

RegisterNetEvent('vehicles:openTrunk', function(data)
    local vehicle = data.vehicle
    local plate = data.plate

    if Bridge.Inventory == 'ox_inventory' then
        exports.ox_inventory:openInventory('trunk', plate)
    elseif Bridge.Inventory == 'qb-inventory' then
        TriggerEvent('inventory:client:SetCurrentStash', plate)
        TriggerServerEvent('inventory:server:OpenInventory', 'trunk', plate)
    end
end)

-- Utility functions
function GetSpawnLocation(coords)
    for i = 1, 10 do
        local spawnCoords = coords + vector3(math.random(-10, 10), math.random(-10, 10), 0)
        if IsSpawnLocationClear(spawnCoords) then
            return spawnCoords
        end
    end
    return coords
end

function IsSpawnLocationClear(coords)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 3.0, 0, 71)
    return vehicle == 0
end

function GiveVehicleKeys(vehicle, plate)
    if Bridge.Framework == 'esx' then
        -- ESX key system
        TriggerEvent('esx_vehiclelock:giveKeys', plate)
    elseif Bridge.Framework == 'qb' or Bridge.Framework == 'qbox' then
        -- QBCore key system
        TriggerEvent('qb-vehiclekeys:client:AddKeys', plate)
    end
end

function SetVehicleProperties(vehicle, props)
    -- Universal vehicle property setter
    if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
    if props.color1 then SetVehicleColours(vehicle, props.color1, props.color2 or props.color1) end
    if props.mods then
        for modType, modIndex in pairs(props.mods) do
            SetVehicleMod(vehicle, tonumber(modType), modIndex, false)
        end
    end
end
```

## Job System Integration

### Police Job Example

```lua
-- jobs/police.lua

local PoliceJob = {}

-- Police menu
function PoliceJob.OpenPoliceMenu()
    local playerData = Framework.Player

    if playerData.Job.Name ~= 'police' then
        Framework.Notify('You are not a police officer', 'error')
        return
    end

    local menuItems = {
        {
            title = 'Check ID',
            description = 'Check nearby player ID',
            event = 'police:checkID'
        },
        {
            title = 'Cuff Player',
            description = 'Cuff nearby player',
            event = 'police:cuffPlayer'
        },
        {
            title = 'Search Player',
            description = 'Search nearby player',
            event = 'police:searchPlayer'
        }
    }

    -- Add supervisor options
    if playerData.Job.Grade.Level >= 3 then
        table.insert(menuItems, {
            title = 'Manage Officers',
            description = 'Manage police officers',
            event = 'police:manageOfficers'
        })
    end

    Menu.Show({
        title = 'Police Menu',
        items = menuItems
    })
end

-- Police station zones
CreateThread(function()
    -- Police station
    Target.AddBoxZone('police_station', vector3(441.0, -975.0, 30.0), 5.0, 5.0, {
        name = 'police_station',
        heading = 0,
        debugPoly = false
    }, {
        options = {
            {
                type = 'client',
                event = 'police:clockIn',
                icon = 'fas fa-clock',
                label = 'Clock In/Out',
                job = 'police'
            },
            {
                type = 'client',
                event = 'police:openArmory',
                icon = 'fas fa-gun',
                label = 'Armory',
                job = 'police',
                grade = 1
            }
        },
        distance = 2.0
    })

    -- Evidence locker
    Target.AddBoxZone('evidence_locker', vector3(475.0, -996.0, 30.0), 2.0, 2.0, {
        name = 'evidence_locker'
    }, {
        options = {
            {
                type = 'client',
                event = 'police:evidenceLocker',
                icon = 'fas fa-box',
                label = 'Evidence Locker',
                job = 'police'
            }
        },
        distance = 1.5
    })
end)

-- Events
RegisterNetEvent('police:checkID', function()
    local target = GetNearestPlayer()
    if target then
        TriggerServerEvent('police:requestID', GetPlayerServerId(target))
    else
        Framework.Notify('No player nearby', 'error')
    end
end)

RegisterNetEvent('police:showID', function(targetData)
    local playerData = Framework.Player

    if playerData.Job.Name == 'police' then
        Menu.Show({
            title = 'Player ID',
            items = {
                {
                    title = 'Name',
                    description = targetData.name
                },
                {
                    title = 'ID',
                    description = targetData.Identifier or targetData.identifier
                },
                {
                    title = 'Job',
                    description = targetData.job
                }
            }
        })
    end
end)

-- Utility functions
function GetNearestPlayer()
    local players = GetActivePlayers()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local nearestPlayer = nil
    local nearestDistance = 3.0

    for _, player in pairs(players) do
        local targetPed = GetPlayerPed(player)
        if targetPed ~= ped then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(coords - targetCoords)

            if distance < nearestDistance then
                nearestDistance = distance
                nearestPlayer = player
            end
        end
    end

    return nearestPlayer
end
```

## Real Estate System

### Property Management

```lua
-- properties/client.lua

local PropertySystem = {}
local ownedProperties = {}

-- Initialize property system
CreateThread(function()
    Framework.TriggerCallback('properties:getOwnedProperties', function(properties)
        ownedProperties = properties

        for _, property in pairs(properties) do
            CreatePropertyZone(property)
        end
    end)
end)

-- Create property interaction zone
function CreatePropertyZone(property)
    Target.AddBoxZone('property_' .. property.id, property.coords, 2.0, 2.0, {
        name = 'property_' .. property.id,
        heading = property.heading or 0,
        debugPoly = false
    }, {
        options = {
            {
                type = 'client',
                event = 'properties:enterProperty',
                icon = 'fas fa-home',
                label = 'Enter Property',
                args = {propertyId = property.id}
            },
            {
                type = 'client',
                event = 'properties:manageProperty',
                icon = 'fas fa-cog',
                label = 'Manage Property',
                args = {propertyId = property.id}
            }
        },
        distance = 2.0
    })
end

-- Property management menu
RegisterNetEvent('properties:manageProperty', function(data)
    local property = GetPropertyById(data.propertyId)

    if not property then return end

    local menuItems = {
        {
            title = 'Enter Property',
            description = 'Enter your property',
            event = 'properties:enterProperty',
            args = {propertyId = property.id}
        },
        {
            title = 'Property Storage',
            description = 'Access property storage',
            event = 'properties:openStorage',
            args = {propertyId = property.id}
        }
    }

    -- Add management options for owner
    if property.owner == Framework.Player.Identifier then
        table.insert(menuItems, {
            title = 'Give Keys',
            description = 'Give keys to nearby player',
            event = 'properties:giveKeys',
            args = {propertyId = property.id}
        })

        table.insert(menuItems, {
            title = 'Sell Property',
            description = 'Sell this property',
            event = 'properties:sellProperty',
            args = {propertyId = property.id}
        })
    end

    Menu.Show({
        title = property.name,
        items = menuItems
    })
end)

-- Property storage
RegisterNetEvent('properties:openStorage', function(data)
    local property = GetPropertyById(data.propertyId)

    if not property then return end

    local storageId = 'property_' .. property.id

    if Bridge.Inventory == 'ox_inventory' then
        exports.ox_inventory:openInventory('stash', storageId)
    elseif Bridge.Inventory == 'qb-inventory' then
        TriggerEvent('inventory:client:SetCurrentStash', storageId)
        TriggerServerEvent('inventory:server:OpenInventory', 'stash', storageId, {
            maxweight = property.storage_weight or 50000,
            slots = property.storage_slots or 50
        })
    end
end)

-- Utility functions
function GetPropertyById(propertyId)
    for _, property in pairs(ownedProperties) do
        if property.id == propertyId then
            return property
        end
    end
    return nil
end
```

These examples demonstrate how to use Dusa Bridge to create cross-framework compatible resources with consistent APIs across different systems.