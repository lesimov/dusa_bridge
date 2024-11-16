module 'shared/debug'
module 'shared/resource'
module 'shared/table'

Version = resource.version(Bridge.InventoryName)
Bridge.Debug('Inventory', Bridge.InventoryName, Version)

local codem_inventory = exports[Bridge.InventoryName]

Framework.OnReady(codem_inventory, function()
    Framework.Items = {}
    for k, v in pairs(codem_inventory:GetItemList()) do
        local item = {}
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

    setmetatable(Framework.Items, {
        __index = function(table, key)
            print(('^9Error: Item \'%s\' Does Not Exist. Please Make Sure The Required Items Are Created.^0'):format(tostring(key)))
        end
    })
end)

Framework.OpenStash = function(name)
    name = name:gsub("%-", "_")
    Framework.TriggerCallback(Bridge.Resource .. ':bridge:GetStash', function(stash)
        if not stash then return end
        local isAllowed = false
        if stash.groups and Framework.HasJob(stash.groups, Framework.Player) then isAllowed = true end
        if stash.groups and Framework.HasGang(stash.groups, Framework.Player) then isAllowed = true end
        if stash.groups and not isAllowed then return end
        if stash.owner and type(stash.owner) == 'string' and Framework.Player.Identifier ~= stash.owner then return end
        if stash.owner and type(stash.owner) == 'boolean' then name = name .. Framework.Player.Identifier end
        TriggerServerEvent(('%s:server:openstash'):format(Bridge.InventoryName), name, stash.slots, stash.weight)
    end, name)
end

Framework.OpenShop = function(name)
    Framework.TriggerCallback(Bridge.Resource .. ':bridge:OpenShop', function(shopdata)
        if table.type(shopdata) ~= 'empty' then
            TriggerEvent("codem-inventory:openshop", name)
        end
    end, name)
end

Framework.CloseInventory = function()
    ExecuteCommand('closeinv')
end

Framework.GetItem = function(item, metadata, strict)
    local items = {}
    ---@cast items Item[]
    local PlayerInventory = codem_inventory:GetClientPlayerInventory()
    for k, v in pairs(PlayerInventory) do
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
            slot = tonumber(v.slot),
        }
        ::skipLoop::
    end
    return items
end

Framework.HasItem = function(items, count, metadata, strict)
    if type(items) == "string" then
        local counted = 0
        for _, v in pairs(Framework.GetItem(items, metadata, strict)) do
            counted += v.count
        end
        return counted >= (count or 1)
    elseif type(items) == "table" then
        if table.type(items) == 'hash' then
            for item, amount in pairs(items) do
                local counted = 0
                for _, v in pairs(Framework.GetItem(item, metadata, strict)) do
                    counted += v.count
                end
                if counted < amount then return false end
            end
            return true
        elseif table.type(items) == 'array' then
            local counted = 0
            for i = 1, #items do
                local item = items[i]
                for _, v in pairs(Framework.GetItem(item, metadata, strict)) do
                    counted += v.count
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
    TriggerEvent('codem-inventory:client:robplayer')
end

Framework.GetCurrentWeapon = function() -- codem does not providing current weapon data 
    -- local PlayerInventory = codem_inventory:GetClientPlayerInventory()
    -- for k, v in pairs(PlayerInventory) do
    --     if v.type == 'weapon' then
    --         return v
    --     end
    -- end
    return false
end

Framework.GetImagePath = function (item)
    local path = ('nui://%s/html/itemimages/%s.png'):format(Bridge.InventoryName, item)
    return path
end