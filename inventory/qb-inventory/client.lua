module 'shared/debug'
module 'shared/resource'
module 'shared/table'

Version = resource.version(Bridge.InventoryName)
Bridge.Debug('Inventory', Bridge.InventoryName, Version)

Framework.OnReady(QBCore, function()
    Framework.Items = {}
    for k, v in pairs(QBCore.Shared.Items) do
        local item = {}
        if type(v) == 'string' then return end
        if not v.name then v.name = k end
        item.name = v.name
        item.label = v.label
        item.description = v.description
        item.stack = not v.unique and true
        item.weight = v.weight or 0
        item.close = v.shouldClose == nil and true or v.shouldClose
        item.image = v.image
        item.type = v.type
        Framework.Items[v.name] = item
    end
end)

-- This event is no longer needed for qb-inventory as we call OpenInventory export directly on server

Framework.OpenStash = function(name)
    name = name:gsub("%-", "_")
    Framework.TriggerCallback(Bridge.Resource .. ':bridge:OpenStash', function(success)
        -- Stash is opened server-side via qb-inventory's OpenInventory export
    end, name)
end

Framework.OpenShop = function(name)
    Framework.TriggerCallback(Bridge.Resource .. ':bridge:OpenShop', function(success)
        -- Shop is opened server-side via qb-inventory's OpenShop export
    end, name)
end

Framework.CloseInventory = function()
    ExecuteCommand('closeinv')
end

---@diagnostic disable-next-line: duplicate-set-field
Framework.GetItem = function(item, metadata, strict)
    local items = {}
    ---@cast items Item[]
    local PlayerData = QBCore.Functions.GetPlayerData()
    for k, v in pairs(PlayerData.items) do
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
    return items
end

---@diagnostic disable-next-line: duplicate-set-field
Framework.HasItem = function(items, count, metadata, strict)
    if type(items) == "string" then
        local counted = 0
        for _, v in pairs(Framework.GetItem(items, metadata, strict)) do
            counted+=v.count
        end
        return counted >= (count or 1)
    elseif type(items) == "table" then
        if table.type(items) == 'hash' then
            for item, amount in pairs(items) do
                local counted = 0
                for _, v in pairs(Framework.GetItem(item, metadata, strict)) do
                    counted+=v.count
                end
                if counted < amount then return false end
            end
            return true
        elseif table.type(items) == 'array' then
            local counted = 0
            for i = 1, #items do
                local item = items[i]
                for _, v in pairs(Framework.GetItem(item, metadata, strict)) do
                    counted+=v.count
                end
                if counted < (count or 1) then return false end
            end
            return true
        end
    end
end

Framework.LockInventory = function()
    LocalPlayer.state:set('inv_busy', true, true)
end

Framework.UnlockInventory = function()
    LocalPlayer.state:set('inv_busy', false, true)
end

Framework.OpenNearbyInventory = function(playerId)
    TriggerServerEvent("inventory:server:OpenInventory", "otherplayer", playerId)
end

Framework.GetCurrentWeapon = function() -- qb does not providing current weapon data 
    return false
end
