module 'shared/debug'
module 'shared/resource'
module 'shared/table'

Version = resource.version(Bridge.InventoryName)
Bridge.Debug('Inventory', Bridge.InventoryName, Version)

local origen_inventory = exports[Bridge.InventoryName]

-- origen_inventory uses QBCore-style API (similar to tgiann-inventory, qb-inventory)
-- Falls back to ox_inventory-compatible exports when detected
local function isOxCompatible()
    return pcall(function() return origen_inventory:Items() end)
end

local IS_OX_STYLE = isOxCompatible()

Framework.OnReady(origen_inventory, function()
    Framework.Items = {}
    if IS_OX_STYLE then
        for k, v in pairs(origen_inventory:Items()) do
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
    else
        for k, v in pairs(origen_inventory:GetItemList()) do
            local item = {}
            if not v.name then v.name = k end
            item.name = v.name
            item.label = v.label
            item.description = v.description
            item.stack = not v.unique and true
            item.weight = v.weight or 0
            item.close = v.shouldClose == nil and true or v.shouldClose
            item.type = v.type
            Framework.Items[v.name] = item
        end
    end
end)

Framework.AddItem = function(inventory, item, count, metadata, slot)
    if IS_OX_STYLE then
        if not origen_inventory:CanCarryItem(inventory, item, count, metadata) then return false end
        return origen_inventory:AddItem(inventory, item, count, metadata, slot)
    else
        if type(inventory) == "string" then
            -- Stash: use direct DB (QBCore style)
            local stash = origen_inventory:GetStashItems(inventory)
            -- Fallback: use AddItem with stash name
            return origen_inventory:AddItem(inventory, item, count, slot, metadata)
        else
            return origen_inventory:AddItem(inventory, item, count, slot, metadata)
        end
    end
    return false
end

Framework.RemoveItem = function(inventory, item, count, metadata, slot)
    if IS_OX_STYLE then
        return origen_inventory:RemoveItem(inventory, item, count, metadata, slot)
    else
        return origen_inventory:RemoveItem(inventory, item, count, slot, metadata)
    end
end

Framework.GetItem = function(inventory, item, metadata, strict)
    if IS_OX_STYLE then
        return origen_inventory:GetSlotsWithItem(inventory, item, metadata, strict)
    else
        local items = {}
        if type(inventory) == "string" then
            local stashItems = origen_inventory:GetStashItems(inventory)
            for k, v in pairs(stashItems or {}) do
                if v.name ~= item then goto skipLoop end
                if metadata and (strict and not table.matches(v.metadata, metadata) or not table.contains(v.metadata, metadata)) then goto skipLoop end
                items[#items + 1] = v
                ::skipLoop::
            end
        else
            for k, v in pairs(origen_inventory:GetPlayerItems(inventory)) do
                if v.name ~= item then goto skipLoop end
                if metadata and (strict and not table.matches(v.info, metadata) or not table.contains(v.info, metadata)) then goto skipLoop end
                items[#items + 1] = {
                    name = v.name,
                    count = tonumber(v.amount),
                    label = v.label,
                    description = v.description,
                    metadata = v.info,
                    stack = not v.unique and true,
                    weight = v.weight or 0,
                    close = v.shouldClose == nil and true or v.shouldClose,
                    image = v.image,
                    type = v.type,
                    slot = v.slot,
                }
                ::skipLoop::
            end
        end
        return items
    end
end

Framework.GetItemCount = function(inventory, item, metadata, strict)
    if IS_OX_STYLE then
        return origen_inventory:GetItemCount(inventory, item, metadata, strict)
    else
        local count = 0
        local items = Framework.GetItem(inventory, item, metadata, strict)
        for _, v in pairs(items) do
            count = count + tonumber(v.count or v.amount or 0)
        end
        return count
    end
end

Framework.HasItem = function(inventory, items, count, metadata, strict)
    if IS_OX_STYLE then
        if type(items) == "table" then
            if table.type(items) == 'hash' then
                for item, amount in pairs(items) do
                    if origen_inventory:GetItemCount(inventory, item, metadata, strict) < amount then
                        return false
                    end
                end
                return true
            elseif table.type(items) == 'array' then
                for i = 1, #items do
                    if origen_inventory:GetItemCount(inventory, items[i], metadata, strict) < count then
                        return false
                    end
                end
                return true
            end
        else
            return origen_inventory:GetItemCount(inventory, items, metadata, strict) >= (count or 1)
        end
    else
        if type(items) == "string" then
            local counted = 0
            for _, v in pairs(Framework.GetItem(inventory, items, metadata, strict)) do
                counted = counted + tonumber(v.count or v.amount or 0)
            end
            return counted >= (count or 1)
        elseif type(items) == "table" then
            if table.type(items) == 'hash' then
                for item, amount in pairs(items) do
                    local counted = 0
                    for _, v in pairs(Framework.GetItem(inventory, item, metadata, strict)) do
                        counted = counted + tonumber(v.count or v.amount or 0)
                    end
                    if counted < amount then return false end
                end
                return true
            elseif table.type(items) == 'array' then
                local counted = 0
                for i = 1, #items do
                    for _, v in pairs(Framework.GetItem(inventory, items[i], metadata, strict)) do
                        counted = counted + tonumber(v.count or v.amount or 0)
                    end
                    if counted < (count or 1) then return false end
                end
                return true
            end
        end
    end
end

Framework.GetItemMetadata = function(inventory, slot)
    if IS_OX_STYLE then
        return origen_inventory:GetSlot(inventory, slot)?.metadata
    else
        local item = origen_inventory:GetItemBySlot(inventory, slot)
        return item?.info
    end
end

Framework.SetItemMetadata = function(inventory, slot, metadata)
    if IS_OX_STYLE then
        origen_inventory:SetMetadata(inventory, slot, metadata)
    else
        local item = origen_inventory:GetItemBySlot(inventory, slot)
        origen_inventory:UpdateItemMetadata(inventory, item, slot, metadata)
    end
end

Framework.GetInventory = function(inventory)
    if IS_OX_STYLE then
        return origen_inventory:GetInventoryItems(inventory, false)
    else
        local items = {}
        if type(inventory) == "string" then
            local stashItems = origen_inventory:GetStashItems(inventory)
            return stashItems or {}
        else
            for k, v in pairs(origen_inventory:GetPlayerItems(inventory)) do
                items[k] = {
                    name = v.name,
                    count = tonumber(v.amount),
                    label = v.label,
                    description = v.description,
                    metadata = v.info,
                    stack = not v.unique and true,
                    weight = v.weight or 0,
                    close = v.shouldClose == nil and true or v.shouldClose,
                    image = v.image,
                    type = v.type,
                    slot = v.slot,
                }
            end
        end
        return items
    end
end

Framework.CreateUseableItem = function(name, cb)
    if IS_OX_STYLE then
        local UsableItems = {}
        UsableItems[name] = cb
        AddEventHandler('ox_inventory:usedItem', function(playerId, usedName, slotId, metadata)
            if usedName ~= name then return end
            cb(playerId, usedName, origen_inventory:GetSlot(playerId, slotId))
        end)
    else
        origen_inventory:CreateUseableItem(name, cb)
    end
end

Framework.ClearInventory = function(inventory, keep)
    if IS_OX_STYLE then
        origen_inventory:ClearInventory(inventory, keep)
    else
        if type(inventory) == "string" then
            origen_inventory:ClearInventory(inventory)
        else
            origen_inventory:ClearInventory(inventory)
        end
    end
end

local stashes = {}
Framework.RegisterStash = function(name, slots, weight, owner, groups)
    if not stashes[name] then
        stashes[name] = { slots = slots, weight = weight, owner = owner, groups = groups }
    end
    if IS_OX_STYLE then
        origen_inventory:RegisterStash(name, name, slots, weight, owner)
    else
        -- QBCore style: stash registered via server event or export
        pcall(function()
            origen_inventory:RegisterStash(name, slots, weight, owner, groups)
        end)
    end
end

Framework.CreateCallback(Bridge.Resource .. ':bridge:GetStash', function(source, cb, name)
    cb(stashes[name] and stashes[name] or nil)
end)

Framework.RegisterShop = function(name, data)
    if IS_OX_STYLE then
        origen_inventory:RegisterShop(name, {
            name = data.name,
            inventory = data.items,
            groups = data.groups
        })
    else
        pcall(function()
            origen_inventory:RegisterShop(name, data)
        end)
    end
end

Framework.ConfiscateInventory = function(source)
    if IS_OX_STYLE then
        origen_inventory:ConfiscateInventory(source)
    else
        local inventory = origen_inventory:GetPlayerItems(source)
        Framework.ClearInventory(source)
        for i = 1, #inventory do
            local item = inventory[i]
            Framework.AddItem('Confiscated_' .. source, item.name, item.amount, item.info, item.slot)
        end
    end
end

Framework.ReturnInventory = function(source)
    if IS_OX_STYLE then
        origen_inventory:ReturnInventory(source)
    else
        for k, v in pairs(Framework.GetInventory('Confiscated_' .. source)) do
            Framework.AddItem(source, v.name, v.count, v.metadata, v.slot)
        end
        Framework.ClearInventory('Confiscated_' .. source)
    end
end

Framework.GetCurrentWeapon = function()
    if IS_OX_STYLE then
        return origen_inventory:GetCurrentWeapon(inventory)
    end
    return nil
end

Framework.OpenInventory = function(source, target)
    if IS_OX_STYLE then
        origen_inventory:forceOpenInventory(source, 'player', target)
    else
        pcall(function()
            origen_inventory:OpenInventoryById(source, target, true)
        end)
    end
end
