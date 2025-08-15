module 'shared/debug'
module 'shared/resource'
module 'shared/table'

Version = resource.version(Bridge.InventoryName)
Bridge.Debug('Inventory', Bridge.InventoryName, Version)

local tgiann_inventory = exports[Bridge.InventoryName]
Framework.OnReady(tgiann_inventory, function()
    Framework.Items = {}
    for k, v in pairs(tgiann_inventory:GetItemList()) do
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

---Get Stash Items
---@return Item[]
local function GetStashItems(inventory)
    inventory = inventory:gsub("%-", "_")
    local items = {}
	local result = Database.scalar('SELECT items FROM tgiann_inventory_stashitems WHERE stash = ?', {inventory})
	if not result then return items end

	local stashItems = json.decode(result)
	if not stashItems then return items end

	for _, item in pairs(stashItems) do
		local itemInfo = Framework.Items[item.name:lower()]
		if itemInfo then
            items[item.slot] = {
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
                slot = item.slot,
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
    inventory = inventory:gsub("%-", "_")
    count = tonumber(count) or 1
    local stash = {}
    local result = Database.scalar('SELECT items FROM tgiann_inventory_stashitems WHERE stash = ?', {inventory})
    if result then stash = json.decode(result) end
	local itemInfo = tgiann_inventory:GetItemList()[item:lower()]
    metadata = metadata or {}
    metadata.created = metadata.created or os.time()
    metadata.quality = metadata.quality or 100
    if itemInfo['type'] == 'weapon' then
        metadata.serie = metadata.serie or tostring(Framework.RandomInteger(2) .. Framework.RandomString(3) .. Framework.RandomInteger(1) .. Framework.RandomString(2) .. Framework.RandomInteger(3) .. Framework.RandomString(4))
    end
	if not itemInfo.unique then
        if type(slot) == "number" and stash[slot] and stash[slot].name == item and table.matches(metadata, stash[slot].info) then
            stash[slot].amount = stash[slot].amount + count
        else
            slot = #stash + 1
            stash[slot] = {
                name = itemInfo["name"],
				amount = count,
				info = metadata or {},
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = slot,
            }
        end
	else
        slot = #stash + 1
        stash[slot] = {
            name = itemInfo["name"],
			amount = count,
			info = metadata or {},
			label = itemInfo["label"],
			description = itemInfo["description"] or "",
			weight = itemInfo["weight"],
			type = itemInfo["type"],
			unique = itemInfo["unique"],
			useable = itemInfo["useable"],
			image = itemInfo["image"],
			slot = slot,
        }
    end
    Database.insert('INSERT INTO tgiann_inventory_stashitems (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
		['stash'] = inventory,
		['items'] = json.encode(stash)
	})
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
    inventory = inventory:gsub("%-", "_")
    local stash = {}
    local result = Database.scalar('SELECT items FROM tgiann_inventory_stashitems WHERE stash = ?', {inventory})
    if result then stash = json.decode(result) else return false end
    count = tonumber(count) or 1
	if type(slot) == "number" and stash[slot] and stash[slot].name == item then
        if metadata and not table.matches(metadata, stash[slot].info) then return false end
        if stash[slot].amount > count then
            stash[slot].amount = stash[slot].amount - count
        else
            stash[slot] = nil
        end
        Database.insert('INSERT INTO tgiann_inventory_stashitems (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
            ['stash'] = inventory,
            ['items'] = json.encode(stash)
        })
        return true
	else
        local removed = count
        local newstash = stash
        for _, v in pairs(stash) do
            if v.name == item then
                if metadata and table.matches(metadata, v.info) then 
                    if removed >= v.amount then
                        newstash[v.slot] = nil
                        removed = removed - v.amount
                    else
                        newstash[v.slot].amount = newstash[v.slot].amount - removed
                        removed = removed - removed
                    end
                elseif not metadata then
                    if removed >= v.amount then
                        newstash[v.slot] = nil
                        removed = removed - v.amount
                    else
                        newstash[v.slot].amount = newstash[v.slot].amount - removed
                        removed = removed - removed
                    end
                end
            end
            
            if removed == 0 then
                break
            end
        end

        if removed == 0 then
            Database.insert('INSERT INTO tgiann_inventory_stashitems (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
                ['stash'] = inventory,
                ['items'] = json.encode(newstash)
            })
            return true
        else
            return false
        end
	end
end

Framework.AddItem = function(inventory, item, count, metadata, slot)
    if type(inventory) == "string" then
        return AddStashItem(inventory, item, count, metadata, slot)
    elseif type(inventory) == "number" then
        -- if not tgiann_inventory:CanCarryItem(inventory, item, count) then return false end
        return tgiann_inventory:AddItem(inventory, item, count, slot, metadata)
    end
    return false
end

Framework.RemoveItem = function(inventory, item, count, metadata, slot)
    if type(inventory) == "string" then
        return RemoveStashItem(inventory, item, count, metadata, slot)
    elseif type(inventory) == "number" then
        return tgiann_inventory:RemoveItem(inventory, item, count, slot, metadata)
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
        for k, v in pairs(tgiann_inventory:GetPlayerItems(inventory)) do
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
        for k, v in pairs(tgiann_inventory:GetPlayerItems(inventory)) do
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
            counted+=v.count
        end
        return counted >= (count or 1)
    elseif type(items) == "table" then
        if table.type(items) == 'hash' then
            for item, amount in pairs(items) do
                local counted = 0
                for _, v in pairs(Framework.GetItem(inventory, item, metadata, strict)) do
                    counted+=v.count
                end
                if counted < amount then return false end
            end
            return true
        elseif table.type(items) == 'array' then
            local counted = 0
            for i = 1, #items do
                local item = items[i]
                for _, v in pairs(Framework.GetItem(inventory, item, metadata, strict)) do
                    counted+=v.count
                end
                if counted < (count or 1) then return false end
            end
            return true
        end
    end
end

Framework.GetItemMetadata = function(inventory, slot)
    if type(inventory) == "string" then
        inventory = inventory:gsub("%-", "_")
        local result = Database.scalar('SELECT items FROM tgiann_inventory_stashitems WHERE stash = ?', {inventory})
        if not result then return nil end
        local stash = json.decode(result)
        for k, item in pairs(stash) do
            if item.slot == slot then
                return item.info
            end
        end
        return {}
    elseif type(inventory) == "number" then
        return tgiann_inventory:GetItemBySlot(inventory, slot)?.info
    end
    return {}
end

Framework.SetItemMetadata = function(inventory, slot, metadata)
    if type(inventory) == "string" then
        inventory = inventory:gsub("%-", "_")
        local result = Database.scalar('SELECT items FROM tgiann_inventory_stashitems WHERE stash = ?', {inventory})
        if not result then return end
        local stash = json.decode(result)
        for k, item in pairs(stash) do
            if item.slot == slot then
                stash[k].info = metadata
                break
            end
        end
        if not next(stash) then return end
        Database.insert('INSERT INTO tgiann_inventory_stashitems (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
            ['stash'] = inventory,
            ['items'] = json.encode(stash)
        })
    elseif type(inventory) == "number" then
        local item = tgiann_inventory:GetItemBySlot(inventory, slot)
        tgiann_inventory:UpdateItemMetadata(inventory, item, slot, metadata)
    end
end

Framework.GetInventory = function(inventory)
    local items = {}
    if type(inventory) == "string" then
        items = GetStashItems(inventory)
    elseif type(inventory) == "number" then
        for k, v in pairs(tgiann_inventory:GetPlayerItems(inventory)) do
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

Framework.ClearInventory = function(inventory, keep)
    if type(inventory) == "string" then
        inventory = inventory:gsub("%-", "_")
        local stash = {}
        if keep then
            local result = Database.scalar('SELECT items FROM tgiann_inventory_stashitems WHERE stash = ?', { inventory })
            if not result then return end
            
            local stashItems = json.decode(result)
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

        Database.insert('INSERT INTO tgiann_inventory_stashitems (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
            ['stash'] = inventory,
            ['items'] = json.encode(stash)
        })
    elseif type(inventory) == "number" then
        tgiann_inventory:ClearInventory(inventory) -- no keep parameter
    end
end

local stashes = {}
Framework.RegisterStash = function(name, slots, weight, owner, groups)
    name = name:gsub("%-", "_")
    if not stashes[name] then
        stashes[name] = { slots = slots, weight = weight, owner = owner, groups = groups }
    end
end

Framework.CreateCallback(Bridge.Resource .. ':bridge:GetStash', function(source, cb, name)
    name = name:gsub("%-", "_")
    cb(stashes[name] and stashes[name] or nil)
end)

Framework.OpenStash = function(src, name)
    name = name:gsub("%-", "_")
    local stash = stashes[name]
    if stash then
        local Player = Framework.GetPlayer(src)
        if not Player then return end
    
        local isAllowed = false
        if stash.groups and Framework.HasJob(stash.groups, Player) then isAllowed = true end
        if stash.groups and Framework.HasGang(stash.groups, Player) then isAllowed = true end
        if type(stash.groups) == "table" and (stash.groups and not isAllowed) then return end
        if stash.owner and type(stash.owner) == 'string' and Player.Identifier ~= stash.owner then return end
        if stash.owner and type(stash.owner) == 'boolean' then name = name .. Player.Identifier end
        
        tgiann_inventory:OpenInventory(src, "stash", name, {
            maxweight = stash.weight,
            slots = stash.slots,
        })
    end
end

local shops = {}
Framework.RegisterShop = function(name, data)
    if shops[name] then return end
    shops[name] = data
    tgiann_inventory:RegisterShop(name, data)
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
    local inventory = tgiann_inventory:GetPlayerItems(src)
    Framework.RegisterStash('Confiscated_' .. Player.Identifier, 41, 120000, true)
    Framework.ClearInventory('Confiscated_' .. Player.Identifier)
    for i = 1, #inventory do
        local item = inventory[i]
        Framework.AddItem('Confiscated_' .. Player.Identifier, item.name, item.amount, item.info, item.slot)
    end
    Framework.ClearInventory(src)
end

Framework.ReturnInventory = function(source)
    local src = source
    local Player = Framework.GetPlayer(src)
    local confiscated = Framework.GetInventory('Confiscated_' .. Player.Identifier)
    for i = 1, #confiscated do
        local item = confiscated[i]
        Framework.AddItem(src, item.name, item.amount, item.info, item.slot)
    end
    Framework.ClearInventory('Confiscated_' .. Player.Identifier)
end

Framework.GetCurrentWeapon = function ()
    return nil
end