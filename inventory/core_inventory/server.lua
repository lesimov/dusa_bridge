module 'shared/debug'
module 'shared/resource'
module 'shared/table'

Version = resource.version(Bridge.InventoryName)
Bridge.Debug('Inventory', Bridge.InventoryName, Version)

if not rawget(_G, "lib") then include('ox_lib', 'init') end

local core_inventory = exports[Bridge.InventoryName]
Framework.OnReady(core_inventory, function()
    Framework.Items = {}
    for k, v in pairs(core_inventory:getItemsList()) do
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
end)

lib.callback.register(Bridge.Resource .. ':bridge:GetItems', function()
    return core_inventory:getItemsList()
end)

---Get Stash Items
---@return Item[]
local function GetStashItems(inventory)
    -- inventory = inventory:gsub("%-", "_")
    local items = {}

    local stashItems = core_inventory:getInventory(inventory)
    if not stashItems then return items end

    for _, item in pairs(stashItems) do
        local itemInfo = Framework.Items[item.name:lower()]
        if itemInfo then
            local slot = item.slot or item.slots[1]
            items[slot] = {
                name = itemInfo.name,
                count = tonumber(item.amount),
                label = itemInfo.label,
                description = itemInfo.description,
                metadata = item.info,
                stack = itemInfo.stack,
                weight = itemInfo.weight,
                close = itemInfo.close,
                image = itemInfo.image,
                type = itemInfo.type,
                slot = slot,
            }
        end
    end
    return items
end

---Add Item To Stash
---@param inventory string
---@param item string
---@param count number
---@param metadata? table
---@param slot? number
---@return boolean
local function AddStashItem(inventory, item, count, metadata, slot)
    -- inventory = inventory:gsub("%-", "_")
    count = tonumber(count) or 1
    core_inventory:addItem(inventory, item, count, metadata, 'stash')

    return true
end

---Remove Item From Stash
---@param inventory string
---@param item string
---@param count number
---@param metadata? table
---@param slot? number
---@return boolean
local function RemoveStashItem(inventory, item, count, metadata, slot)
    -- inventory = inventory:gsub("%-", "_")
    local removed = core_inventory:removeItem(inventory, item, count, 'stash')
    return removed
end

Framework.AddItem = function(inventory, item, count, metadata, slot)
    if type(inventory) == "string" then
        return AddStashItem(inventory, item, count, metadata, slot)
    elseif type(inventory) == "number" then
        if not core_inventory:canCarry(inventory, item, count) then return false end
        return core_inventory:addItem(inventory, item, count, metadata, 'content')
    end
    return false
end

Framework.RemoveItem = function(inventory, item, count, metadata, slot)
    if type(inventory) == "string" then
        return RemoveStashItem(inventory, item, count, metadata, slot)
    elseif type(inventory) == "number" then
        return core_inventory:removeItem(inventory, item, count, 'content')
    end
    return false
end

---@diagnostic disable-next-line: duplicate-set-field
Framework.GetItem = function(inventory, item, metadata, strict)
    local items = {}
    ---@cast items Item[]
    if type(inventory) == "string" then
        for k, v in pairs(GetStashItems(inventory)) do
            if v.name ~= item then goto skipLoop end
            if metadata and (strict and not table.matches(v.metadata, metadata) or not table.contains(v.metadata, metadata)) then goto skipLoop end
            items[#items + 1] = v
            ::skipLoop::
        end
    elseif type(inventory) == "number" then
        for k, v in pairs(core_inventory:getInventory(inventory)) do
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
                slot = v.slot or v.slots[1],
            }
            ::skipLoop::
        end
    end
    return items
end

Framework.GetItemCount = function(inventory, item, metadata, strict)
    local count = 0
    if type(inventory) == "string" then
        for k, v in pairs(GetStashItems(inventory)) do
            if v.name ~= item then goto skipLoop end
            if metadata and (strict and not table.matches(v.metadata, metadata) or not table.contains(v.metadata, metadata)) then
                goto skipLoop
            end
            count = count + tonumber(v.count)
            ::skipLoop::
        end
    elseif type(inventory) == "number" then
        for k, v in pairs(core_inventory:getInventory(inventory)) do
            if v.name ~= item then goto skipLoop end
            if metadata and (strict and not table.matches(v.info, metadata) or not table.contains(v.info, metadata)) then
                goto skipLoop
            end
            count = count + tonumber(v.amount)
            ::skipLoop::
        end
    end
    return count
end

---@diagnostic disable-next-line: duplicate-set-field
Framework.HasItem = function(inventory, items, count, metadata, strict)
    if type(items) == "string" then
        local counted = 0
        for _, v in pairs(Framework.GetItem(inventory, items, metadata, strict)) do
            counted += v.count
        end
        return counted >= (count or 1)
    elseif type(items) == "table" then
        if table.type(items) == 'hash' then
            for item, amount in pairs(items) do
                local counted = 0
                for _, v in pairs(Framework.GetItem(inventory, item, metadata, strict)) do
                    counted += v.count
                end
                if counted < amount then return false end
            end
            return true
        elseif table.type(items) == 'array' then
            local counted = 0
            for i = 1, #items do
                local item = items[i]
                for _, v in pairs(Framework.GetItem(inventory, item, metadata, strict)) do
                    counted += v.count
                end
                if counted < (count or 1) then return false end
            end
            return true
        end
    end
end

Framework.GetItemMetadata = function(inventory, slot)
    if type(inventory) == "string" then
        -- inventory = inventory:gsub("%-", "_")
        local stash = core_inventory:getInventory(inventory)
        for k, item in pairs(stash) do
            if item.slot == slot or item.slots?[1] == slot then
                return item.info
            end
        end
        return {}
    elseif type(inventory) == "number" then
        return core_inventory:getItemBySlot(inventory, slot)?.info
    end
    return {}
end

Framework.SetItemMetadata = function(inventory, slot, metadata)
    if type(inventory) == "string" then
        -- inventory = inventory:gsub("%-", "_")
        core_inventory:setMetadata(inventory, slot, metadata)
    elseif type(inventory) == "number" then
        -- local item = core_inventory:GetItemBySlot(inventory, slot)
        core_inventory:setMetadata(inventory, slot, metadata)
    end
end

Framework.GetInventory = function(inventory)
    local items = {}
    if type(inventory) == "string" then
        items = GetStashItems(inventory)
    elseif type(inventory) == "number" then
        for k, v in pairs(core_inventory:getInventory(inventory)) do
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
                slot = v.slot or v.slots[1],
            }
        end
    end
    return items
end

Framework.ClearInventory = function(inventory, keep)
    if type(inventory) == "string" then
        -- inventory = inventory:gsub("%-", "_")
        local stash = {}
        if keep then
            local stashItems = core_inventory:getInventory(inventory)
            if not next(stashItems) then return end

            local keepType = type(keep)
            if keepType == "string" then
                for k, v in pairs(stashItems) do
                    if v.name == keep then
                        stash[k] = v
                    end
                end
            elseif keepType == "table" and table.type(keep) == "array" then
                for k, v in pairs(stashItems) do
                    for i = 1, #keep do
                        if v.name == keep[i] then
                            stash[k] = v
                        end
                    end
                end
            end
        end

        core_inventory:clearInventory(inventory)
        for k, v in pairs(stash) do
            core_inventory:addItem(inventory, v.name, v.amount, v.info, 'stash')
        end
    elseif type(inventory) == "number" then
        core_inventory:clearInventory(inventory) -- no keep parameter
    end
end

local stashes = {}
Framework.RegisterStash = function(name, slots, weight, owner, groups)
    -- name = name:gsub("%-", "_")
    if not stashes[name] then
        stashes[name] = { slots = slots, weight = weight, owner = owner, groups = groups }
    end
end

Framework.CreateCallback(Bridge.Resource .. ':bridge:GetStash', function(source, cb, name)
    -- name = name:gsub("%-", "_")
    cb(stashes[name] and stashes[name] or nil)
end)

local shops = {}
Framework.RegisterShop = function(name, data)
    -- if shops[name] then return end
    -- shops[name] = data
    -- core_inventory:RegisterShop(name, data)
    print('^1[DUSA_BRIDGE] ^3 Shop register is not available for core inv ^0')
end

Framework.CreateCallback(Bridge.Resource .. ':bridge:OpenShop', function(source, cb, name)
    if not shops[name] then cb({}) end
    local isAllowed = false
    local Player = Framework.GetPlayer(source)
    if shops[name].groups and Framework.HasJob(shops[name].groups, Player) then isAllowed = true end
    if shops[name].groups and Framework.HasGang(shops[name].groups, Player) then isAllowed = true end
    if type(shops[name].groups) == "table" and (shops[name].groups and not isAllowed) then cb({}) end
    cb(shops[name])
end)

Framework.ConfiscateInventory = function(source)
    local src = source
    core_inventory:confiscatePlayerInventory(src)
end

Framework.ReturnInventory = function(source)
    local src = source
    core_inventory:returnPlayerInventory(src)
end

Framework.GetCurrentWeapon = function()
    return nil
end
