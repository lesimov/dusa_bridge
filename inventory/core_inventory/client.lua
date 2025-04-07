module 'shared/debug'
module 'shared/resource'
module 'shared/table'

Version = resource.version(Bridge.InventoryName)
Bridge.Debug('Inventory', Bridge.InventoryName, Version)

if not rawget(_G, "lib") then include('ox_lib', 'init') end

local core_inventory = exports[Bridge.InventoryName]
Framework.OnReady(core_inventory, function()
    Framework.Items = {}
    local items = lib.callback.await(Bridge.Resource .. ':bridge:GetItems', false)
    for k, v in pairs(items) do
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
end)

Framework.OpenStash = function(name)
    -- name = name:gsub("%-", "_")
    Framework.TriggerCallback(Bridge.Resource .. ':bridge:GetStash', function(stash)
        if not stash then return end
        local isAllowed = false
        if stash.groups and Framework.HasJob(stash.groups, Framework.Player) then isAllowed = true end
        if stash.groups and Framework.HasGang(stash.groups, Framework.Player) then isAllowed = true end
        if stash.groups and not isAllowed then return end
        if stash.owner and type(stash.owner) == 'string' and Framework.Player.Identifier ~= stash.owner then return end
        if stash.owner and type(stash.owner) == 'boolean' then
            if Framework.Player.Identifier:sub(1, 4) == "char" then
                name = name .. Framework.Player.Identifier:sub(7)
            end
        end

        TriggerServerEvent('core_inventory:server:openInventory', name, 'stash')
    end, name)
end

Framework.OpenShop = function(name)
    Framework.TriggerCallback(Bridge.Resource .. ':bridge:OpenShop', function(shopdata)
        if table.type(shopdata) ~= 'empty' then
            local Shop = {}
            Shop.label = shopdata.name
            Shop.items = {}
            for i = 1, #shopdata.items do
                Shop.items[i] = {
                    name = shopdata.items[i].name,
                    price = shopdata.items[i].price,
                    amount = shopdata.items[i].count or 1,
                    info = shopdata.items[i].metadata or {},
                    type = Framework.Items[shopdata.items[i].name].type,
                    slot = i
                }
            end
            TriggerServerEvent("inventory:server:OpenInventory", "shop", shopdata.name, Shop)
        end
    end, name)
end

Framework.CloseInventory = function()
    core_inventory:closeInventory()
end

---@diagnostic disable-next-line: duplicate-set-field
Framework.GetItem = function(item, metadata, strict)
    local items = {}
    ---@cast items Item[]
    for k, v in pairs(core_inventory:getInventory()) do
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
    return items
end

---@diagnostic disable-next-line: duplicate-set-field
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
    core_inventory:lockInventory()
end

Framework.UnlockInventory = function()
    core_inventory:unlockInventory()
end

Framework.OpenNearbyInventory = function(playerId)
    TriggerServerEvent('core_inventory:server:openInventory', playerId, 'otherplayer', nil, nil, false)
end

Framework.GetWeaponList = function()
    return nil
end

local currentWeapon = nil
RegisterNetEvent('core_inventory:client:handleWeapon', function(weaponName, weaponData, _weaponInventoryamountAdded)
    if not weaponName then
        currentWeapon = nil
        return
    end

    currentWeapon = {
        name = weaponName,
        data = weaponData
    }
end)

Framework.GetCurrentWeapon = function()
    if currentWeapon and currentWeapon.data.metadata and currentWeapon.data.metadata ~= '' then
        return currentWeapon.data.metadata
    end
    return nil
end
