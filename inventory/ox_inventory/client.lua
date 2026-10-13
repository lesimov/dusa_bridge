module 'shared/debug'
module 'shared/resource'

Version = resource.version(Bridge.InventoryName)
Bridge.Debug('Inventory', Bridge.InventoryName, Version)

local ox_inventory = exports[Bridge.InventoryName]

-- ak47_inventory compatibility (ticket 1251)
-- `ak47_inventory` (and `ak47_qb_inventory` >= 12.5, which registers its exports under
-- the `ak47_inventory` name) is routed through this ox adapter. The multi-framework
-- build exposes ox-style aliases (openInventory, GetItemCount, ...), but the QB build
-- only exposes its native exports (OpenInventory, GetAmount, CloseInventory, ...).
-- For ak47 we try the ox alias first and fall back to the documented native export
-- when FiveM reports "No such export". Every other inventory keeps the direct call.
-- Native API: https://docs.menanak47.com/qbcore/ak47_qb_inventory/exports/client
local IsAk47 = Bridge.InventoryName == 'ak47_inventory'

local function isMissingExport(err)
    return type(err) == 'string' and err:find('No such export', 1, true) ~= nil
end

---Run ox call, then ak47 native fallbacks, skipping only missing exports.
---@return boolean ok, any result
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

local function itemCount(item, metadata, strict)
    if not IsAk47 then return ox_inventory:GetItemCount(item, metadata, strict) end
    local _, count = ak47Call('GetItemCount', {
        function() return ox_inventory:GetItemCount(item, metadata, strict) end,
        function() return ox_inventory:GetAmount(item, metadata, strict) end,
    })
    return tonumber(count) or 0
end
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
        item.image = k .. '.png'
        if v.client and v.client.image then 
            item.image = (v.client.image):gsub(('nui://%s/web/images/'):format(Bridge.InventoryName), "")
        end
        if v.weapon then item.type = 'weapon' end
        Framework.Items[v.name] = item
    end
end)

Framework.OpenStash = function(name)
    Framework.TriggerCallback(Bridge.Resource .. ':bridge:GetStash', function(stash)
        if not stash then return end
        local isAllowed = false
        if stash.groups and Framework.HasJob(stash.groups, Framework.Player) then isAllowed = true end
        if stash.groups and Framework.HasGang(stash.groups, Framework.Player) then isAllowed = true end
        if stash.groups and not isAllowed then return end
        if not IsAk47 then return ox_inventory:openInventory('stash', name) end
        ak47Call('OpenStash', {
            function() return ox_inventory:openInventory('stash', name) end,
            function()
                -- Native ak47 stashes are shared by identifier; refuse instead of
                -- silently opening one shared stash for an owner-scoped stash.
                if stash.owner then
                    print(('^1[dusa_bridge] OpenStash: owner-scoped stash %s is not supported by %s native exports.^0')
                        :format(name, Bridge.InventoryName))
                    return
                end
                return ox_inventory:OpenInventory(name)
            end,
        })
    end, name)
end

Framework.OpenShop = function(name)
    if not IsAk47 then return ox_inventory:openInventory('shop', { type = name, id = 1 }) end
    ak47Call('OpenShop', {
        function() return ox_inventory:openInventory('shop', { type = name, id = 1 }) end,
        -- ak47 native shops are opened by their CreateShop identifier.
        function() return ox_inventory:OpenInventory(name) end,
    })
end

Framework.CloseInventory = function()
    if not IsAk47 then return ox_inventory:closeInventory() end
    ak47Call('CloseInventory', {
        function() return ox_inventory:closeInventory() end,
        function() return ox_inventory:CloseInventory() end,
    })
end

Framework.GetItem = function(item, metadata, strict)
    return ox_inventory:GetSlotsWithItem(item, metadata, strict)
end

Framework.HasItem = function(items, count, metadata, strict)
    if table.type(items) == 'hash' then
        for item, amount in pairs(items) do
            if itemCount(item, metadata, strict) < amount then return false end
        end
        return true
    else
        return itemCount(items, metadata, strict) >= (count or 1)
    end
end

Framework.LockInventory = function()
    LocalPlayer.state:set('invBusy', true, false)
end

Framework.UnlockInventory = function()
    LocalPlayer.state:set('invBusy', false, false)
end

Framework.GetWeaponList = function ()
    local weapons = require '@ox_inventory.data.weapons'
    weapons = weapons.Weapons

    return weapons
end

Framework.OpenNearbyInventory = function()
    if not IsAk47 then return exports.ox_inventory:openNearbyInventory() end
    local _, result = ak47Call('OpenNearbyInventory', {
        function() return ox_inventory:openNearbyInventory() end,
        function() return ox_inventory:OpenNearbyInventory() end,
    })
    return result
end

Framework.GetCurrentWeapon = function ()
    return exports.ox_inventory:getCurrentWeapon()
end