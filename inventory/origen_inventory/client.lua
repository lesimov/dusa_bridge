module 'shared/debug'
module 'shared/resource'
module 'shared/table'

Version = resource.version(Bridge.InventoryName)
Bridge.Debug('Inventory', Bridge.InventoryName, Version)

local origen_inventory = exports[Bridge.InventoryName]

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
            item.image = k .. '.png'
            if v.client and v.client.image then
                item.image = (v.client.image):gsub(('nui://%s/web/images/'):format(Bridge.InventoryName), "")
            end
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
            item.image = v.image
            item.type = v.type
            Framework.Items[v.name] = item
        end
    end
end)

Framework.OpenStash = function(name)
    Framework.TriggerCallback(Bridge.Resource .. ':bridge:GetStash', function(stash)
        if not stash then return end
        local isAllowed = false
        if stash.groups and Framework.HasJob(stash.groups, Framework.Player) then isAllowed = true end
        if stash.groups and Framework.HasGang(stash.groups, Framework.Player) then isAllowed = true end
        if stash.groups and not isAllowed then return end
        if stash.owner and type(stash.owner) == 'string' and Framework.Player.Identifier ~= stash.owner then return end
        if stash.owner and type(stash.owner) == 'boolean' then name = name .. Framework.Player.Identifier end
        if IS_OX_STYLE then
            origen_inventory:openInventory('stash', name)
        else
            TriggerServerEvent('inventory:server:OpenInventory', 'stash', name, {
                maxweight = stash.weight,
                slots = stash.slots,
            })
            TriggerEvent('inventory:client:SetCurrentStash', name)
        end
    end, name)
end

Framework.OpenShop = function(name)
    if IS_OX_STYLE then
        origen_inventory:openInventory('shop', { type = name, id = 1 })
    else
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
                        type = Framework.Items[shopdata.items[i].name]?.type or 'item',
                        slot = i
                    }
                end
                TriggerServerEvent('inventory:server:OpenInventory', 'shop', shopdata.name, Shop)
            end
        end, name)
    end
end

Framework.CloseInventory = function()
    origen_inventory:CloseInventory()
end

Framework.GetItem = function(item, metadata, strict)
    if IS_OX_STYLE then
        return origen_inventory:GetSlotsWithItem(item, metadata, strict)
    else
        local items = {}
        for k, v in pairs(origen_inventory:GetPlayerItems()) do
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
end

Framework.HasItem = function(items, count, metadata, strict)
    if IS_OX_STYLE then
        if table.type(items) == 'hash' then
            for item, amount in pairs(items) do
                if origen_inventory:GetItemCount(item, metadata, strict) < amount then return false end
            end
            return true
        else
            return origen_inventory:GetItemCount(items, metadata, strict) >= (count or 1)
        end
    else
        if type(items) == "string" then
            local counted = 0
            for _, v in pairs(Framework.GetItem(items, metadata, strict)) do
                counted = counted + tonumber(v.count or v.amount or 0)
            end
            return counted >= (count or 1)
        elseif type(items) == "table" then
            if table.type(items) == 'hash' then
                for item, amount in pairs(items) do
                    local counted = 0
                    for _, v in pairs(Framework.GetItem(item, metadata, strict)) do
                        counted = counted + tonumber(v.count or v.amount or 0)
                    end
                    if counted < amount then return false end
                end
                return true
            elseif table.type(items) == 'array' then
                for i = 1, #items do
                    local counted = 0
                    local item = items[i]
                    for _, v in pairs(Framework.GetItem(item, metadata, strict)) do
                        counted = counted + tonumber(v.count or v.amount or 0)
                    end
                    if counted < (count or 1) then return false end
                end
                return true
            end
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
    if IS_OX_STYLE then
        exports.origen_inventory:openNearbyInventory()
    else
        TriggerServerEvent('inventory:server:OpenInventory', 'otherplayer', playerId, nil, { showClothe = false })
    end
end

Framework.GetWeaponList = function()
    if QBShared?.Weapons then
        return QBShared.Weapons
    end
    return {}
end

Framework.GetCurrentWeapon = function()
    local weapon = origen_inventory:GetCurrentWeapon()
    if weapon and weapon.info and weapon.info ~= '' then
        return weapon.info
    end
    return nil
end
