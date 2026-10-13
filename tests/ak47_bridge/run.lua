--[[
    Ticket 1251 regression harness: ak47 inventory/banking bridge contracts.

    Runs the REAL dusa_bridge sources outside FiveM with a minimal stub of the
    FiveM export proxy. A missing export raises the same "No such export X in
    resource Y" error FiveM raises (see ticket console log).

    Export sets come from the vendor documentation (docs.menanak47.com):
      * ak47_qb_inventory (QB build, exports registered under 'ak47_inventory'):
        native exports only -> no ox alias `openInventory`.
      * ak47_inventory (multi-framework build): native + ox aliases.
      * ox_inventory: ox exports only (regression guard: unchanged behaviour).
      * ak47_banking: GetAccountBalance / AddMoney / RemoveMoney (name-keyed).

    Usage (repo root):  lua5.4 tests/ak47_bridge/run.lua [repo_root]
    Exit code 0 = all pass, 1 = failures.
]]

local ROOT = arg and arg[1] or '.'
local results = { pass = 0, fail = 0 }

local function check(name, cond, detail)
    if cond then
        results.pass = results.pass + 1
        print(('PASS  %s'):format(name))
    else
        results.fail = results.fail + 1
        print(('FAIL  %s%s'):format(name, detail and ('  -> ' .. tostring(detail)) or ''))
    end
end

local function readFile(path)
    local f = assert(io.open(ROOT .. '/' .. path, 'r'))
    local s = f:read('a'); f:close()
    -- CfX Lua 5.4 extensions used by the bridge: safe navigation and compound ops.
    s = s:gsub('%?%.', '.')
    return s
end

-- ---------------------------------------------------------------- fake exports
local calls
local function makeResource(resName, exportNames, impl)
    local set = {}
    for _, n in ipairs(exportNames) do set[n] = true end
    return setmetatable({}, {
        __index = function(_, key)
            return function(_, ...)
                if not set[key] then
                    error(('No such export %s in resource %s'):format(key, resName), 0)
                end
                calls[#calls + 1] = { res = resName, fn = key, args = { ... } }
                if impl and impl[key] then return impl[key](...) end
                return true
            end
        end,
    })
end

local INV = {
    -- QB build: https://docs.menanak47.com/qbcore/ak47_qb_inventory/exports/client|server
    ak47_qb = {
        client = { 'Ready', 'OpenInventory', 'OpenNearbyInventory', 'CloseInventory', 'Items', 'GetItem',
            'GetFirstItem', 'GetItemLabel', 'HasItems', 'Search', 'GetAmount', 'GetPlayerItems',
            'GetPlayerWeight', 'GetPlayerMaxWeight', 'GetSlotWithItem', 'GetSlotIdWithItem',
            'GetSlotsWithItem', 'GetSlotIdsWithItem', 'SetInventoryBusy', 'UnEquipeWeapon' },
        server = { 'Items', 'AddItem', 'RemoveItem', 'GetItem', 'GetFirstItem', 'CanAddItem', 'CanCarryAmount',
            'CanCarryWeight', 'SetMaxWeight', 'CanSwapItem', 'GetAmount', 'GetSlot', 'GetSlotForItem',
            'GetSlotIdWithItem', 'GetSlotIdsWithItem', 'GetSlotsWithItem', 'GetEmptySlot',
            'GetContainerFromSlot', 'SetSlotCount', 'GetInventory', 'GetInventoryItems', 'SetInvItems',
            'ConfiscateInventory', 'ReturnInventory', 'ClearInventory', 'ClearClothing', 'Search',
            'CreateInventory', 'OpenInventory', 'LoadInventory', 'UnloadInventory', 'CreateShop',
            'SetWhitelistedItemsForContainer', 'SetBlacklistedItemsForContainer', 'GetCurrentWeapon',
            'SetQuality', 'SetItemInfo', 'RemoveQuality', 'SaveInventory', 'DeleteInventory',
            'SaveAllInventory', 'OnChangeVehiclePlate' },
    },
    -- Multi-framework build adds ox aliases:
    -- https://docs.menanak47.com/multi-framework/ak47_inventory/guides/compatibility-and-aliases
    ak47_multi = {
        client = { 'Ready', 'OpenInventory', 'OpenNearbyInventory', 'CloseInventory', 'Items', 'GetAmount',
            'GetSlotsWithItem', 'openInventory', 'openNearbyInventory', 'closeInventory', 'GetItemCount',
            'GetPlayerItems', 'getCurrentWeapon' },
        server = { 'Items', 'AddItem', 'RemoveItem', 'CanAddItem', 'GetAmount', 'GetSlot', 'GetSlotsWithItem',
            'GetInventoryItems', 'OpenInventory', 'CreateShop', 'RegisterShop', 'RegisterStash',
            'GetItemCount', 'CanCarryItem', 'SetMetadata', 'ClearInventory', 'ConfiscateInventory',
            'ReturnInventory', 'GetCurrentWeapon' },
    },
    ox = {
        client = { 'Items', 'openInventory', 'closeInventory', 'GetSlotsWithItem', 'GetItemCount',
            'openNearbyInventory', 'getCurrentWeapon' },
        server = { 'Items', 'AddItem', 'RemoveItem', 'GetSlotsWithItem', 'GetItemCount', 'GetSlot', 'SetMetadata',
            'GetInventoryItems', 'ClearInventory', 'RegisterStash', 'RegisterShop', 'ConfiscateInventory',
            'ReturnInventory', 'GetCurrentWeapon', 'forceOpenInventory', 'CanCarryItem' },
    },
}

-- ---------------------------------------------------------------- environment
local function baseEnv(opts)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local started = opts.started or {}
    env.GetResourceState = function(name) return started[name] and 'started' or 'missing' end
    env.GetCurrentResourceName = function() return 'dusa_mechanic' end
    env.GetResourceMetadata = function(_, key) if key == 'bridge' then return 'dusa_bridge' end return '1.0.0' end
    env.GetNumResourceMetadata = function() return 0 end
    env.IsDuplicityVersion = function() return opts.context == 'server' end
    env.LoadResourceFile = function() return nil end
    env.override = opts.override or {}
    env.printed = {}
    env.print = function(...) env.printed[#env.printed + 1] = table.concat({ ... }, ' ') end
    env.promise = { new = function() return {} end }
    env.Citizen = { Await = function() return nil end, CreateThreadNow = function(fn) fn() end }
    env.table = setmetatable({
        type = function(t)
            if type(t) ~= 'table' then return false end
            if next(t) == nil then return 'empty' end
            return (#t > 0) and 'array' or 'hash'
        end,
    }, { __index = table })
    env.exports = setmetatable({}, { __index = function(_, k) return opts.exports[k] end })
    return env
end

local function loadInventoryAdapter(context, invName, framework, exportsMap, started)
    local env = baseEnv({ context = context, exports = exportsMap, started = started })
    env.Bridge = { Name = 'dusa_bridge', Resource = 'dusa_mechanic', InventoryName = invName,
        Framework = framework, ZoneName = 'ox_lib', Context = context, Debug = function() end }
    env.resource = { version = function() return 'test' end }
    env.module = function() end
    env.include = function() end
    env.lib = {}
    env.LocalPlayer = { state = { set = function() end } }
    env.AddEventHandler = function() end
    env.Framework = {
        OnReady = function() end,
        TriggerCallback = function(_, cb) cb({ name = 'stash' }) end,
        CreateCallback = function() end,
        HasJob = function() return true end,
        HasGang = function() return false end,
    }
    local chunk = assert(load(readFile(('inventory/ox_inventory/%s.lua'):format(context)),
        '@inventory/ox_inventory/' .. context .. '.lua', 't', env))
    chunk()
    return env
end

local function lastCall(res)
    for i = #calls, 1, -1 do if calls[i].res == res then return calls[i] end end
end

-- ---------------------------------------------------------------- inventory: ak47_qb_inventory (ticket)
local function invCase(label, build, framework)
    local spec = INV[build]
    calls = {}
    local cEnv = loadInventoryAdapter('client', 'ak47_inventory', framework, {
        ak47_inventory = makeResource('ak47_inventory', spec.client,
            { GetAmount = function() return 3 end, GetItemCount = function() return 3 end }),
    }, { ak47_inventory = true })

    local ok, err = pcall(cEnv.Framework.OpenShop, 'mechanic_shop_1')
    check(label .. ': client OpenShop does not raise', ok, err)
    local c = lastCall('ak47_inventory')
    check(label .. ': client OpenShop reaches an ak47 open export',
        c and (c.fn == 'openInventory' or (c.fn == 'OpenInventory' and c.args[1] == 'mechanic_shop_1')),
        c and c.fn)

    calls = {}
    ok, err = pcall(cEnv.Framework.CloseInventory)
    local cc = lastCall('ak47_inventory')
    check(label .. ': client CloseInventory works', ok and cc ~= nil, err)

    ok, err = pcall(cEnv.Framework.HasItem, 'water', 2)
    check(label .. ': client HasItem counts via available export', ok and err == true, err)

    calls = {}
    local sEnv = loadInventoryAdapter('server', 'ak47_inventory', framework, {
        ak47_inventory = makeResource('ak47_inventory', spec.server,
            { GetAmount = function() return 5 end, GetItemCount = function() return 5 end,
              CanAddItem = function() return true end, CanCarryItem = function() return true end }),
        ox_inventory = makeResource('ox_inventory', {}),
    }, { ak47_inventory = true })

    ok, err = pcall(sEnv.Framework.RegisterShop, 'mechanic_shop_1',
        { name = 'Mechanic Shop', items = { { name = 'water', price = 10 } } })
    check(label .. ': server RegisterShop does not raise', ok, err)
    local reg = lastCall('ak47_inventory')
    check(label .. ': server RegisterShop registers in ak47_inventory', reg and (reg.fn == 'RegisterShop' or reg.fn == 'CreateShop'),
        reg and reg.fn or 'no ak47 call (went to exports.ox_inventory?)')
    if reg and reg.fn == 'CreateShop' then
        local items = reg.args[3]
        check(label .. ': CreateShop item mapping', reg.args[1] == 'mechanic_shop_1' and items[1].item == 'water'
            and items[1].buyPrice == 10 and reg.args[4] == (framework == 'qb' and 'cash' or 'money'),
            reg.args[4])
    end

    calls = {}
    ok, err = pcall(sEnv.Framework.RegisterStash, 'mechanic_stash_1', 50, 100000, nil, nil)
    local st = lastCall('ak47_inventory')
    check(label .. ': server RegisterStash registers in ak47_inventory', ok and st and
        (st.fn == 'RegisterStash' or (st.fn == 'CreateInventory' and st.args[2].type == 'stash' and st.args[2].slots == 50)),
        err or (st and st.fn))

    ok, err = pcall(sEnv.Framework.GetItemCount, 1, 'water')
    check(label .. ': server GetItemCount', ok and err == 5, err)
    ok, err = pcall(sEnv.Framework.AddItem, 1, 'water', 1)
    check(label .. ': server AddItem carry check', ok and err == true, err)

    calls = {}
    local gEnv = loadInventoryAdapter('server', 'ak47_inventory', framework, {
        ak47_inventory = makeResource('ak47_inventory', spec.server),
        ox_inventory = makeResource('ox_inventory', {}),
    }, { ak47_inventory = true })
    ok, err = pcall(gEnv.Framework.RegisterShop, 'restricted', { name = 'R', items = {}, groups = { mechanic = 0 } })
    local gc = lastCall('ak47_inventory')
    if build == 'ak47_qb' then
        check(label .. ': group-restricted native shop is refused with a clear message, not opened publicly',
            ok and gc == nil and #gEnv.printed > 0, err)
    end
end

invCase('ak47_qb_inventory (QB)', 'ak47_qb', 'qb')
invCase('ak47_inventory multi-framework (QB)', 'ak47_multi', 'qb')

-- clear error when no supported open export exists
calls = {}
local none = loadInventoryAdapter('client', 'ak47_inventory', 'qb', {
    ak47_inventory = makeResource('ak47_inventory', { 'Items' }),
}, { ak47_inventory = true })
local okNone, errNone = pcall(none.Framework.OpenShop, 'x')
check('ak47 without any open export: no script error + readable message',
    okNone and #none.printed > 0 and none.printed[#none.printed]:find('compatible export') ~= nil, errNone)

-- non-"missing export" errors must still surface (not swallowed)
local boom = loadInventoryAdapter('client', 'ak47_inventory', 'qb', {
    ak47_inventory = setmetatable({}, { __index = function() return function() error('real failure', 0) end end }),
}, { ak47_inventory = true })
local okBoom, errBoom = pcall(boom.Framework.OpenShop, 'x')
check('ak47: unrelated runtime errors are re-raised', not okBoom and tostring(errBoom):find('real failure') ~= nil, errBoom)

-- ---------------------------------------------------------------- regression: ox_inventory unchanged
calls = {}
local ox = loadInventoryAdapter('client', 'ox_inventory', 'qbox', {
    ox_inventory = makeResource('ox_inventory', INV.ox.client, { GetItemCount = function() return 1 end }),
}, { ox_inventory = true })
ox.Framework.OpenShop('s1')
local oc = lastCall('ox_inventory')
check('ox_inventory: OpenShop -> openInventory(shop, {type,id})',
    oc and oc.fn == 'openInventory' and oc.args[1] == 'shop' and oc.args[2].type == 's1' and oc.args[2].id == 1)
local oxs = loadInventoryAdapter('server', 'ox_inventory', 'qbox', {
    ox_inventory = makeResource('ox_inventory', INV.ox.server),
}, { ox_inventory = true })
calls = {}
oxs.Framework.RegisterShop('s1', { name = 'S', items = { { name = 'water', price = 1 } }, groups = { mechanic = 0 } })
local os_ = lastCall('ox_inventory')
check('ox_inventory: RegisterShop passes groups to ox RegisterShop',
    os_ and os_.fn == 'RegisterShop' and os_.args[2].groups.mechanic == 0)

-- ---------------------------------------------------------------- banking
local function bankingEnv(started, bankImpl)
    started.dusa_bridge = true
    started.ox_lib = true
    local env = baseEnv({
        context = 'server', started = started,
        exports = { ak47_banking = makeResource('ak47_banking', { 'GetAccountBalance', 'AddMoney', 'RemoveMoney' }, bankImpl) },
    })
    local chunk = assert(load(readFile('bridge.lua'), '@bridge.lua', 't', env))
    local ok, err = pcall(chunk) -- stops at module loader (no LoadResourceFile in harness); banking is defined before
    env.loadError = (not ok) and err or nil
    return env
end

local bal = 1000
calls = {}
local bank = bankingEnv({ oxmysql = true, ['qb-core'] = true, ak47_banking = true }, {
    GetAccountBalance = function(name) return name == 'mechanic' and bal or 0 end,
    AddMoney = function(_, amount) bal = bal + amount; return true end,
    RemoveMoney = function(_, amount) bal = bal - amount; return true end,
})
check('banking: ak47_banking auto-detected on QB', bank.Bridge and bank.Bridge.SocietyBanking == 'ak47_banking',
    bank.Bridge and bank.Bridge.SocietyBanking or bank.loadError)
check('banking: GetMoney reads ak47 GetAccountBalance',
    bank.Bridge.SocietyBankingGetMoney and bank.Bridge.SocietyBankingGetMoney('mechanic', 'job') == 1000)
check('banking: AddMoney deposits to ak47 account',
    bank.Bridge.SocietyBankingAddMoney and bank.Bridge.SocietyBankingAddMoney('mechanic', 'job', 250) == true and bal == 1250, bal)
local addCall = lastCall('ak47_banking')
check('banking: AddMoney uses (accountName, amount, reason)',
    addCall and addCall.fn == 'AddMoney' and addCall.args[1] == 'mechanic' and addCall.args[2] == 250 and type(addCall.args[3]) == 'string')
check('banking: RemoveMoney withdraws when funds suffice',
    bank.Bridge.SocietyBankingRemoveMoney and bank.Bridge.SocietyBankingRemoveMoney('mechanic', 'job', 200) == true and bal == 1050, bal)
check('banking: RemoveMoney refuses overdraft',
    bank.Bridge.SocietyBankingRemoveMoney and bank.Bridge.SocietyBankingRemoveMoney('mechanic', 'job', 99999) == false and bal == 1050, bal)

local qbOnly = bankingEnv({ oxmysql = true, ['qb-core'] = true, ['qb-banking'] = true }, {})
check('banking regression: qb-banking still selected when ak47_banking absent', qbOnly.Bridge.SocietyBanking == 'qb-banking',
    qbOnly.Bridge.SocietyBanking)
local renewed = bankingEnv({ oxmysql = true, ['qb-core'] = true, ['Renewed-Banking'] = true, ak47_banking = true }, {})
check('banking regression: existing earlier candidate keeps priority', renewed.Bridge.SocietyBanking == 'Renewed-Banking',
    renewed.Bridge.SocietyBanking)

print(('\n%d passed, %d failed'):format(results.pass, results.fail))
os.exit(results.fail == 0 and 0 or 1)
