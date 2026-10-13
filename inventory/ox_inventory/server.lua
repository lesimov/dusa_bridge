module 'shared/debug'
module 'shared/resource'

Version = resource.version(Bridge.InventoryName)
Bridge.Debug('Inventory', Bridge.InventoryName, Version)

local ox_inventory = exports[Bridge.InventoryName]
local UsableItems = {}

-- ak47_inventory compatibility (ticket 1251) — see inventory/ox_inventory/client.lua.
-- QB builds of ak47 expose native exports only; fall back to them when FiveM reports
-- "No such export". Non-ak47 inventories keep their original direct calls.
-- Native API: https://docs.menanak47.com/qbcore/ak47_qb_inventory/exports/server
local IsAk47 = Bridge.InventoryName == 'ak47_inventory'

local function isMissingExport(err)
    return type(err) == 'string' and err:find('No such export', 1, true) ~= nil
end

local function ak47Call(label, attempts)
    for i = 1, #attempts do
        local ok, result = pcall(attempts[i])
        if ok then return true, result end
        if not isMissingExport(result) then error(result, 0) end
    end
    print(('^1[dusa_bridge] %s: %s does not provide a compatible export. Update %s or set a matching inventory in dusa_bridge override.^0')
        :format(label, Bridge.InventoryName, Bridge.InventoryName))
    return false, nil
end

local function itemCount(inventory, item, metadata, strict)
    if not IsAk47 then return ox_inventory:GetItemCount(inventory, item, metadata, strict) end
    local _, count = ak47Call('GetItemCount', {
        function() return ox_inventory:GetItemCount(inventory, item, metadata, strict) end,
        function() return ox_inventory:GetAmount(inventory, item, metadata, strict) end,
    })
    return tonumber(count) or 0
end

local function canCarry(inventory, item, count, metadata)
    if not IsAk47 then return ox_inventory:CanCarryItem(inventory, item, count, metadata) end
    local _, result = ak47Call('CanCarryItem', {
        function() return ox_inventory:CanCarryItem(inventory, item, count, metadata) end,
        function() return ox_inventory:CanAddItem(inventory, item, count) end,
    })
    return result
end
if not rawget(_G, "lib") then include(Bridge.ZoneName, 'init') end

Framework.OnReady(ox_inventory, function()
    Framework.Items = {}
    for k, v in pairs(ox_inventory:Items()) do
        local item = {}
        item.name = k
        item.label = v.label
        item.description = v.description
        item.stack = v.stack
        item.weight = v.weight or 0
        item.close = v.close
        if v.weapon then item.type = 'weapon' end
        Framework.Items[v.name] = item
    end
end)

Framework.AddItem = function(inventory, item, count, metadata, slot)
    if not canCarry(inventory, item, count, metadata) then return false end
    local success = ox_inventory:AddItem(inventory, item, count, metadata, slot)
    return success
end

Framework.RemoveItem = function(inventory, item, count, metadata, slot)
    local success = ox_inventory:RemoveItem(inventory, item, count, metadata, slot)
    return success
end

Framework.GetItem = function(inventory, item, metadata, strict)
    return ox_inventory:GetSlotsWithItem(inventory, item, metadata, strict)
end

Framework.GetItemCount = function(inventory, item, metadata, strict)
    return itemCount(inventory, item, metadata, strict)
end

Framework.HasItem = function(inventory, items, count, metadata, strict)
    if type(items) == "table" then
        if table.type(items) == 'hash' then
            for item, amount in pairs(items) do
                if itemCount(inventory, item, metadata, strict) < amount then
                    return false 
                end
            end
            return true
        elseif table.type(items) == 'array' then
            for i = 1, #items do
                local item = items[i]
                if itemCount(inventory, item, metadata, strict) < count then
                    return false 
                end
            end
            return true
        end
    else
        return itemCount(inventory, items, metadata, strict) >= count
    end
end

Framework.GetItemMetadata = function(inventory, slot)
    return ox_inventory:GetSlot(inventory, slot)?.metadata
end

Framework.SetItemMetadata = function(inventory, slot, metadata)
    ox_inventory:SetMetadata(inventory, slot, metadata)
end

Framework.GetInventory = function(inventory)
    return ox_inventory:GetInventoryItems(inventory, false)
end

Framework.CreateUseableItem = function(name, cb)
    UsableItems[name] = cb
end

AddEventHandler('ox_inventory:usedItem', function(playerId, name, slotId, metadata)
    if not UsableItems[name] then return end
    UsableItems[name](playerId, name, ox_inventory:GetSlot(playerId, slotId))
end)

Framework.ClearInventory = function(inventory, keep)
    ox_inventory:ClearInventory(inventory, keep)
end

local stashes = {}
Framework.RegisterStash = function(name, slots, weight, owner, groups)
    if not stashes[name] then
        stashes[name] = { slots = slots, weight = weight, owner = owner, groups = groups }
    end
    if not IsAk47 then return ox_inventory:RegisterStash(name, name, slots, weight, owner) end
    ak47Call('RegisterStash', {
        function() return ox_inventory:RegisterStash(name, name, slots, weight, owner) end,
        function()
            -- Native ak47 stashes are shared by identifier; owner-scoped stashes are
            -- refused on the client instead of exposing one shared inventory.
            if owner then return end
            return ox_inventory:CreateInventory(name, { label = name, slots = slots, maxWeight = weight, type = 'stash' })
        end,
    })
end

Framework.CreateCallback(Bridge.Resource .. ':bridge:GetStash', function(source, cb, name)
    cb(stashes[name] and stashes[name] or nil)
end)

local function ak47NativeShop(name, data)
    if data.groups then
        -- ox `groups` gates the whole shop; ak47 native shops gate per item and
        -- split jobs/gangs, so an exact translation is not possible. Fail loudly.
        print(('^1[dusa_bridge] RegisterShop: group-restricted shop %s is not supported by %s native exports.^0')
            :format(name, Bridge.InventoryName))
        return
    end
    local items = {}
    for i, item in ipairs(data.items or {}) do
        items[i] = { item = item.name, buyPrice = item.price, stock = item.count }
    end
    -- QB builds name the cash account 'cash'; the multi-framework build uses 'money'.
    local account = (Bridge.Framework == 'qb') and 'cash' or 'money'
    return ox_inventory:CreateShop(name, data.name or name, items, account)
end

Framework.RegisterShop = function(name, data)
    if not IsAk47 then
        return exports.ox_inventory:RegisterShop(name, {
            name = data.name,
            inventory = data.items,
            groups = data.groups
        })
    end
    ak47Call('RegisterShop', {
        function()
            return ox_inventory:RegisterShop(name, {
                name = data.name,
                inventory = data.items,
                groups = data.groups
            })
        end,
        function() return ak47NativeShop(name, data) end,
    })
end

Framework.ConfiscateInventory = function(source)
    ox_inventory:ConfiscateInventory(source)
end

Framework.ReturnInventory = function(source)
    ox_inventory:ReturnInventory(source)
end

Framework.GetCurrentWeapon = function (inventory)
    return ox_inventory:GetCurrentWeapon(inventory)
end

Framework.OpenInventory = function(source, target)
    if not IsAk47 then return ox_inventory:forceOpenInventory(source, 'player', target) end
    ak47Call('OpenInventory', {
        function() return ox_inventory:forceOpenInventory(source, 'player', target) end,
        function() return ox_inventory:OpenInventory(source, target) end,
    })
end
