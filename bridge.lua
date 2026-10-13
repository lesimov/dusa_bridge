---@class Bridge
Bridge = {}
Bridge.Resource = GetCurrentResourceName()
Bridge.Name = GetResourceMetadata(Bridge.Resource, 'bridge', 0)
Bridge.Version = GetResourceMetadata(Bridge.Name, 'version', 0)
Bridge.Context = IsDuplicityVersion() and 'server' or 'client'
-- Bridge.DebugMode = GetConvar('bridge:debug', 'false') == 'true' and true or false
Bridge.DebugMode = override?.debug and true or false
Bridge.Locale = override?.locale or 'en'
Bridge.Disabled = {}
Bridge.Framework = nil
Bridge.FrameworkName = nil
Bridge.FrameworkEvent = nil
Bridge.FrameworkPrefix = nil
Bridge.Inventory = nil
Bridge.InventoryDisabled = false
Bridge.InventoryName = nil
Bridge.InventoryImagePath = nil
Bridge.Target = nil
Bridge.TargetName = nil
Bridge.Zone = nil
Bridge.ZoneName = nil
Bridge.Database = nil
Bridge.DatabaseName = nil
Bridge.SocietyBanking = nil
Bridge.Menu = nil
lib = lib

---@class Framework
Framework = {}

---@class Target
Target = {}

---@class Zone
Zone = {}

---@class Database
Database = {}

---@class Sprite
Sprites = {}

---@class Menu
Menu = {}

if not Bridge.Name then
    print('[^1BRIDGE ERROR^0]')
    print(('^3%s^0'):format("Bridge Not Found, Bridge Tag Must Be Included In Resource Manifest."))
    return
end

if not _VERSION:find('5.4') then
    print('[^1BRIDGE ERROR^0]')
    print(('^3%s^0'):format("Lua 5.4 Must Be Enabled In The Resource Manifest."))
    return
end

if GetResourceState(Bridge.Name) ~= 'started' then
    print('[^1BRIDGE ERROR^0]')
    print(('^3%s %s^0'):format(Bridge.Name, "Must Be Started Before This Resource."))
    return
end

-- ❗ FRAMEWORK VERSION ❗
if Bridge.DebugMode then
    print(('[^2BRIDGE^0] ^1Version^0 %s'):format(Bridge.Version))
end

-- ❗ MODULE DISABLE ❗
for i = 1, GetNumResourceMetadata(Bridge.Resource, 'bridge_disable') do
    local name = GetResourceMetadata(Bridge.Resource, 'bridge_disable', i - 1)
    Bridge.Disabled[name] = true
    if Bridge.DebugMode then print(('[^2BRIDGE^0] ^1Module Disabled^0 %s'):format(name)) end
end

-- ❗ DATABASE DETECTION ❗

-- ❕ OVERRIDE DATABASE ❕
if override?.database then
    Bridge.Database = override?.database
end

-- ❕ OVERRIDE DATABASE NAME ❕
if override?.databasename then
    Bridge.DatabaseName = override?.databasename
end

-- ❕ OXMYSQL ❕
if not Bridge.Database and GetResourceState('oxmysql') == 'started' then
    if not Bridge.DatabaseName then Bridge.DatabaseName = 'oxmysql' end
    Bridge.Database = 'oxmysql'
end

-- ❕ CUSTOM DATABASE ❕
-- if not Bridge.Database and GetResourceState('custom') ~= 'missing' then
--     if not Bridge.DatabaseName then Bridge.DatabaseName = 'custom' end
--     Bridge.Database = 'custom'
-- end

if not Bridge.Disabled['database'] and not Bridge.Database then
    print('[^1BRIDGE ERROR^0]')
    print(('^3%s^0'):format(
        "No Compatible Database Resource Found. Please ensure you're using a supported database and that it's running before the bridge."))
    return
end

-- ❗ FRAMEWORK DETECTION ❗

-- ❕ OVERRIDE FRAMEWORK ❕
if override?.framework then
    Bridge.Framework = override?.framework
end

-- ❕ OVERRIDE FRAMEWORK NAME ❕
if override?.frameworkname then
    Bridge.FrameworkName = override?.frameworkname
end

-- ❕ OVERRIDE FRAMEWORK EVENT ❕
if override?.frameworkevent then
    Bridge.FrameworkEvent = override?.frameworkevent
end

-- ❕ OVERRIDE FRAMEWORK PREFIX ❕
if override?.frameworkprefix then
    Bridge.FrameworkPrefix = override?.frameworkprefix
end

-- ❕ ESX ❕
if not Bridge.Framework and GetResourceState('es_extended') == 'started' then
    if not Bridge.FrameworkName then Bridge.FrameworkName = 'es_extended' end
    if not Bridge.FrameworkEvent then Bridge.FrameworkEvent = 'esx:getSharedObject' end
    if not Bridge.FrameworkPrefix then Bridge.FrameworkPrefix = 'esx' end
    Bridge.Framework = 'esx'
end

-- ❕ QBox ❕
if not Bridge.Framework and GetResourceState('qbx_core') == 'started' then
    if not Bridge.FrameworkName then Bridge.FrameworkName = 'qbx_core' end
    if not Bridge.FrameworkPrefix then Bridge.FrameworkPrefix = 'QBCore' end
    Bridge.Framework = 'qbox'
end

-- ❕ QBCore ❕
if not Bridge.Framework and GetResourceState('qb-core') == 'started' then
    if not Bridge.FrameworkName then Bridge.FrameworkName = 'qb-core' end
    if not Bridge.FrameworkEvent then Bridge.FrameworkEvent = 'QBCore:GetObject' end
    if not Bridge.FrameworkPrefix then Bridge.FrameworkPrefix = 'QBCore' end
    Bridge.Framework = 'qb'
end

-- ❕ OX Core ❕
if not Bridge.Framework and GetResourceState('ox_core') == 'started' then
    if not Bridge.FrameworkName then Bridge.FrameworkName = 'ox_core' end
    if not Bridge.FrameworkPrefix then Bridge.FrameworkPrefix = 'ox' end
    Bridge.Framework = 'ox'
end

-- ❕ vRP ❕
if not Bridge.Framework and GetResourceState('vrp') == 'started' then
    Bridge.Framework = 'vrp'
end

-- ❕ NDCore ❕
if not Bridge.Framework and GetResourceState('ND_Core') == 'started' then
    if not Bridge.FrameworkName then Bridge.FrameworkName = 'ND_Core' end
    if not Bridge.FrameworkPrefix then Bridge.FrameworkPrefix = 'ND' end
    Bridge.Framework = 'ndcore'
end

-- ❕ CUSTOM FRAMEWORK ❕
-- if not Bridge.Framework and GetResourceState('custom') ~= 'missing' then
--     if not Bridge.FrameworkName then Bridge.FrameworkName = 'custom' end
--     Bridge.Framework = 'custom'
-- end

if not Bridge.Disabled['framework'] and not Bridge.Framework then
    print('[^1BRIDGE ERROR^0]')
    print(('^3%s^0'):format(
        "No Compatible Framework Resource Found. Please ensure you're using a supported framework and that it's running before the bridge."))
    return
end

-- ❗ SOCIETY BANKING DETECTION ❗
local societyBanking = override?.societybanking or 'auto'

if societyBanking == 'auto' then
    local candidates = {
        'okokBanking',
        'fd_banking',
        'tgg-banking',
        'wasabi_banking',
        'snipe-banking',
        'Renewed-Banking',
        'ak47_banking',
        'qb-banking'
    }

    if Bridge.Framework == 'qb' then
        candidates[#candidates + 1] = 'qb-management'
    elseif Bridge.Framework == 'qbox' then
        candidates[#candidates + 1] = 'qbx_management'
    elseif Bridge.Framework == 'esx' then
        candidates[#candidates + 1] = 'esx_addonaccount'
    end

    for i = 1, #candidates do
        if GetResourceState(candidates[i]) == 'started' then
            societyBanking = candidates[i]
            break
        end
    end
end

if societyBanking ~= 'auto' then
    Bridge.SocietyBanking = societyBanking
end

if Bridge.Context == 'server' then
    local function moneyValue(value)
        if type(value) == 'table' then
            value = value.account_balance or value.balance or value.money or value.amount
        end

        if type(value) ~= 'number' and type(value) ~= 'string' then return 0 end
        value = tonumber(value)
        if not value or value ~= value or value == math.huge or value == -math.huge then return 0 end
        return value
    end

    local function validAmount(amount)
        if type(amount) ~= 'number' and type(amount) ~= 'string' then return nil end
        amount = tonumber(amount)
        if not amount or amount <= 0 or amount ~= amount or amount == math.huge then return nil end
        return amount
    end

    local function addonAccount(name)
        local accountName = ('society_%s'):format(name)
        local ok, account = pcall(function()
            return exports['esx_addonaccount']:GetSharedAccount(accountName)
        end)
        if ok and account then return account end

        local p = promise.new()
        TriggerEvent('esx_addonaccount:getSharedAccount', accountName, function(value)
            p:resolve(value or false)
        end)
        return Citizen.Await(p)
    end

    local function providerGetMoney(name, accountType)
        local banking = Bridge.SocietyBanking

        if banking == 'okokBanking' then
            return exports['okokBanking']:GetAccount(name)
        elseif banking == 'fd_banking' then
            if accountType == 'gang' then return exports['fd_banking']:GetGangAccount(name) end
            return exports['fd_banking']:GetAccount(name)
        elseif banking == 'tgg-banking' then
            return exports['tgg-banking']:GetSocietyAccountMoney(name)
        elseif banking == 'wasabi_banking' then
            return exports['wasabi_banking']:GetAccountBalance(name, 'society')
        elseif banking == 'snipe-banking' then
            return exports['snipe-banking']:GetAccountBalance(name)
        elseif banking == 'Renewed-Banking' then
            return exports['Renewed-Banking']:getAccountMoney(name)
        elseif banking == 'ak47_banking' then
            -- Job, gang and shared accounts share one name-keyed API.
            -- https://docs.menanak47.com/multi-framework/ak47_banking/exports/server
            return exports['ak47_banking']:GetAccountBalance(name)
        elseif banking == 'qb-banking' then
            return exports['qb-banking']:GetAccountBalance(name)
        elseif banking == 'qb-management' or banking == 'qbx_management' then
            if accountType == 'gang' then return exports[banking]:GetGangAccount(name) end
            return exports[banking]:GetAccount(name)
        elseif banking == 'esx_addonaccount' then
            return addonAccount(name)?.money
        end

        return false
    end

    local function providerMutate(action, name, accountType, amount)
        local banking = Bridge.SocietyBanking

        if banking == 'okokBanking' then
            if action == 'add' then return exports['okokBanking']:AddMoney(name, amount) end
            return exports['okokBanking']:RemoveMoney(name, amount)
        elseif banking == 'fd_banking' then
            if accountType == 'gang' then
                if action == 'add' then return exports['fd_banking']:AddGangMoney(name, amount) end
                return exports['fd_banking']:RemoveGangMoney(name, amount)
            end
            if action == 'add' then return exports['fd_banking']:AddMoney(name, amount) end
            return exports['fd_banking']:RemoveMoney(name, amount)
        elseif banking == 'tgg-banking' then
            if action == 'add' then return exports['tgg-banking']:AddSocietyMoney(name, amount) end
            return exports['tgg-banking']:RemoveSocietyMoney(name, amount)
        elseif banking == 'wasabi_banking' then
            if action == 'add' then return exports['wasabi_banking']:AddMoney('society', name, amount) end
            return exports['wasabi_banking']:RemoveMoney('society', name, amount)
        elseif banking == 'snipe-banking' then
            if action == 'add' then return exports['snipe-banking']:AddMoneyToAccount(name, amount) end
            return exports['snipe-banking']:RemoveMoneyFromAccount(name, amount)
        elseif banking == 'Renewed-Banking' then
            if action == 'add' then return exports['Renewed-Banking']:addAccountMoney(name, amount) end
            return exports['Renewed-Banking']:removeAccountMoney(name, amount)
        elseif banking == 'ak47_banking' then
            if action == 'add' then return exports['ak47_banking']:AddMoney(name, amount, 'dusa_bridge') end
            return exports['ak47_banking']:RemoveMoney(name, amount, 'dusa_bridge')
        elseif banking == 'qb-banking' then
            if action == 'add' then return exports['qb-banking']:AddMoney(name, amount) end
            return exports['qb-banking']:RemoveMoney(name, amount)
        elseif banking == 'qb-management' or banking == 'qbx_management' then
            if accountType == 'gang' then
                if action == 'add' then return exports[banking]:AddGangMoney(name, amount) end
                return exports[banking]:RemoveGangMoney(name, amount)
            end
            if action == 'add' then
                exports[banking]:AddMoney(name, amount)
                return true
            end
            return exports[banking]:RemoveMoney(name, amount)
        elseif banking == 'esx_addonaccount' then
            local account = addonAccount(name)
            if not account then return false end
            if action == 'add' then account.addMoney(amount) else account.removeMoney(amount) end
            return true
        end

        return false
    end

    Bridge.SocietyBankingGetMoney = function(name, accountType)
        local banking = Bridge.SocietyBanking
        if type(name) ~= 'string' or name == '' or not banking or GetResourceState(banking) ~= 'started' then return 0 end

        local ok, value = pcall(providerGetMoney, name, accountType)
        return ok and moneyValue(value) or 0
    end

    Bridge.SocietyBankingAddMoney = function(name, accountType, amount)
        amount = validAmount(amount)
        if not amount or type(name) ~= 'string' or name == '' then return false end
        local banking = Bridge.SocietyBanking
        if not banking or GetResourceState(banking) ~= 'started' then return false end

        local ok, result = pcall(providerMutate, 'add', name, accountType, amount)
        return ok and result ~= false
    end

    Bridge.SocietyBankingRemoveMoney = function(name, accountType, amount)
        amount = validAmount(amount)
        if not amount or type(name) ~= 'string' or name == '' then return false end
        local banking = Bridge.SocietyBanking
        if not banking or GetResourceState(banking) ~= 'started' then return false end
        if Bridge.SocietyBankingGetMoney(name, accountType) < amount then return false end

        local ok, result = pcall(providerMutate, 'remove', name, accountType, amount)
        return ok and result ~= false
    end
end
 
-- ❗ INVENTORY DETECTION ❗
 
-- ❕ OVERRIDE INVENTORY ❕
if override?.inventory then
    Bridge.Inventory = override?.inventory
end
 
-- ❕ OVERRIDE INVENTORY NAME ❕
if override?.inventoryname then
    Bridge.InventoryName = override?.inventoryname
end
 
-- ❕ OVERRIDE INVENTORY PATH ❕
if override?.imagepath then
    Bridge.InventoryImagePath = override?.imagepath
end


-- ❕ OX_INVENTORY ❕
if not Bridge.Inventory and (GetResourceState('ox_inventory') == 'started' or GetResourceState('ak47_inventory') == 'started' or GetResourceState('jaksam_inventory') == 'started') then
    if not Bridge.InventoryName then
        if GetResourceState('ox_inventory') == 'started' then Bridge.InventoryName = 'ox_inventory' end
        if GetResourceState('ak47_inventory') == 'started' then Bridge.InventoryName = 'ak47_inventory' end
        if GetResourceState('jaksam_inventory') == 'started' then Bridge.InventoryName = 'jaksam_inventory' end
    end

    Bridge.InventoryImagePath = ('%s/web/images/'):format(Bridge.InventoryName)

    if GetResourceState('ak47_inventory') == 'started' then
        Bridge.InventoryImagePath = ('%s/web/build/images/'):format(
            Bridge.InventoryName)
    end
    Bridge.Inventory = 'ox_inventory'
end

-- ❕ ORIGEN_INVENTORY ❕
if not Bridge.Inventory and GetResourceState('origen_inventory') == 'started' then
    if not Bridge.InventoryName then Bridge.InventoryName = 'origen_inventory' end
    Bridge.InventoryImagePath = ('%s/web/images/'):format(Bridge.InventoryName)
    Bridge.Inventory = 'origen_inventory'
end

-- ❕ QB-INVENTORY | LJ-INVENTORY | AJ-INVENTORY | AX-INVENTORY | PS-INVENTORY | ak47_qb_inventory | CODEM-INVENTORY | JPR-INVENTORY | TXS-INVENTORY ❕
if not Bridge.Inventory and Bridge.Framework == 'qb' and (GetResourceState('qb-inventory') == 'started' or GetResourceState('lj-inventory') == 'started' or GetResourceState('aj-inventory') == 'started' or GetResourceState('ax-inventory') == 'started' or GetResourceState('ps-inventory') == 'started' or GetResourceState('ak47_qb_inventory') == 'started' or GetResourceState('codem-inventory') == 'started' or GetResourceState('l2s-inventory') == 'started' or GetResourceState('jpr-inventory') == 'started' or GetResourceState('txs-inventory') == 'started') then
    if not Bridge.InventoryName then
        if GetResourceState('qb-inventory') == 'started' then Bridge.InventoryName = 'qb-inventory' end
        if GetResourceState('lj-inventory') == 'started' then Bridge.InventoryName = 'lj-inventory' end
        if GetResourceState('aj-inventory') == 'started' then Bridge.InventoryName = 'aj-inventory' end
        if GetResourceState('ax-inventory') == 'started' then Bridge.InventoryName = 'ax-inventory' end
        if GetResourceState('ps-inventory') == 'started' then Bridge.InventoryName = 'ps-inventory' end
        if GetResourceState('ak47_qb_inventory') == 'started' then Bridge.InventoryName = 'ak47_qb_inventory' end
        if GetResourceState('codem-inventory') == 'started' then Bridge.InventoryName = 'codem-inventory' end
        if GetResourceState('l2s-inventory') == 'started' then Bridge.InventoryName = 'l2s-inventory' end
        if GetResourceState('jpr-inventory') == 'started' then Bridge.InventoryName = 'jpr-inventory' end
        if GetResourceState('txs-inventory') == 'started' then Bridge.InventoryName = 'txs-inventory' end
    end
    Bridge.InventoryImagePath = ('%s/html/images/'):format(Bridge.InventoryName)

    -- Override Inventory Image Path for Codem
    if GetResourceState('codem-inventory') == 'started' then
        Bridge.InventoryImagePath = ('%s/html/itemimages/'):format(
            Bridge.InventoryName)
    end
    if GetResourceState('ak47_qb_inventory') == 'started' then
        Bridge.InventoryImagePath = ('%s/web/build/images/')
            :format(Bridge.InventoryName)
    end

    Bridge.Inventory = 'qb-inventory'
end

-- ❕ QS-INVENTORY ❕
if not Bridge.Inventory and GetResourceState('qs-inventory') == 'started' then
    if not Bridge.InventoryName then Bridge.InventoryName = 'qs-inventory' end
    Bridge.InventoryImagePath = ('%s/html/images/'):format(Bridge.InventoryName)
    Bridge.Inventory = 'qs-inventory'
end

-- ❕ TGIANN-INVENTORY ❕
if not Bridge.Inventory and GetResourceState('tgiann-inventory') == 'started' then
    if not Bridge.InventoryName then Bridge.InventoryName = 'tgiann-inventory' end
    Bridge.InventoryImagePath = 'inventory_images/images/'
    Bridge.Inventory = 'tgiann-inventory'
end

-- ❕ CORE_INVENTORY ❕
if not Bridge.Inventory and GetResourceState('core_inventory') == 'started' then
    if not Bridge.InventoryName then Bridge.InventoryName = 'core_inventory' end
    Bridge.InventoryImagePath = ('%s/html/img/'):format(Bridge.InventoryName)
    Bridge.Inventory = 'core_inventory'
end

-- ❕ CUSTOM INVENTORY ❕
-- if not Bridge.Inventory and GetResourceState('inventory') ~= 'missing' then
--     if not Bridge.InventoryName then Bridge.InventoryName = 'inventory' end
--     Bridge.Inventory = 'inventory'
-- end

if not Bridge.Disabled['inventory'] and not Bridge.Inventory then
    print('[^1BRIDGE ERROR^0]')
    print(('^3%s^0'):format(
        "No Compatible Inventory Resource Found. Please ensure you're using a supported inventory and that it's running before the bridge."))
    return
end

-- ❗ TARGET DETECTION ❗
local targetConfigured = override?.target ~= nil or override?.targetname ~= nil

-- ❕ OVERRIDE TARGET ❕
if override?.target then
    Bridge.Target = override?.target
    if not Bridge.TargetName then Bridge.TargetName = override?.target end
end

-- ❕ OVERRIDE TARGET NAME ❕
if override?.targetname then
    Bridge.TargetName = override?.targetname
end

-- ❕ OX_TARGET ❕
if not Bridge.Target and GetResourceState('ox_target') ~= 'missing' then
    if not Bridge.TargetName then Bridge.TargetName = 'ox_target' end
    Bridge.Target = 'ox_target'
end

-- ❕ META_TARGET ❕
if not Bridge.Target and GetResourceState('meta_target') ~= 'missing' then
    if not Bridge.TargetName then Bridge.TargetName = 'meta_target' end
    Bridge.Target = 'meta_target'
end

-- ❕ QB-TARGET ❕
if not Bridge.Target and GetResourceState('qb-target') ~= 'missing' then
    if not Bridge.TargetName then Bridge.TargetName = 'qb-target' end
    Bridge.Target = 'qb-target'
end

-- ❕ QTARGET ❕
if not Bridge.Target and GetResourceState('qtarget') ~= 'missing' then
    if not Bridge.TargetName then Bridge.TargetName = 'qtarget' end
    Bridge.Target = 'qtarget'
end

-- ❕ CUSTOM TARGET ❕
-- if not Bridge.Target and GetResourceState('target') ~= 'missing' then
--     if not Bridge.TargetName then Bridge.TargetName = 'target' end
--     Bridge.Target = 'target'
-- end

if not Bridge.Disabled['target'] and targetConfigured
    and (not Bridge.Target or not Bridge.TargetName or GetResourceState(Bridge.TargetName) == 'missing') then
    print('[^1BRIDGE ERROR^0]')
    print(('^3%s^0'):format(
        "The Configured Target Resource Is Missing. Please check override.target and override.targetname."))
    return
end

if not Bridge.Disabled['target'] and not Bridge.Target then
    Bridge.Disabled['target'] = true
end
-- ❗ ZONES DETECTION ❗

-- ❕ OVERRIDE ZONE ❕
if override?.zone then
    Bridge.Zone = override?.zone
end

-- ❕ OVERRIDE ZONE NAME ❕
if override?.zonename then
    Bridge.ZoneName = override?.zonename
end

-- ❕ OX_LIB ❕
if not Bridge.Zone and GetResourceState('ox_lib') ~= 'missing' then
    if not Bridge.ZoneName then Bridge.ZoneName = 'ox_lib' end
    Bridge.Zone = 'ox_lib'
end

-- ❕ PolyZone ❕
if not Bridge.Zone and GetResourceState('PolyZone') ~= 'missing' then
    if not Bridge.ZoneName then Bridge.ZoneName = 'PolyZone' end
    Bridge.Zone = 'polyzone'
end

-- ❕ CUSTOM ZONE ❕
-- if not Bridge.Zone and GetResourceState('zone') ~= 'missing' then
--     if not Bridge.ZoneName then Bridge.ZoneName = 'zone' end
--     Bridge.Zone = 'zone'
-- end

if not Bridge.Disabled['zone'] and not Bridge.ZoneName then
    print('[^1BRIDGE ERROR^0]')
    print(('^3%s^0'):format(
        "No Compatible Zone Resource Found. Please ensure you're using a supported zone resource and that it's running before the bridge."))
    return
end

-- ❕ OX_LIB ❕
if not Bridge.Menu and GetResourceState('ox_lib') ~= 'missing' then
    if not Bridge.Menu then Bridge.Menu = 'ox_lib' end
    Bridge.Menu = 'ox_lib'
end
-- ❕ OX_LIB ❕
if not Bridge.Menu and GetResourceState('qb-menu') ~= 'missing' then
    if not Bridge.Menu then Bridge.Menu = 'qb-menu' end
    Bridge.Menu = 'qb-menu'
end

-- ❕ OVERRIDE MENU ❕
if override?.menu then
    Bridge.Menu = override?.menu
end


-- ❗ LOADERS ❗

-- ❕ LOAD MODULE LOADER ❕
local resource = LoadResourceFile(Bridge.Name, 'shared/loader.lua')
if not resource then return error('Unable To Load Module Loader') end
local moduleloader, err = load(resource, ('@@%s/%s'):format(Bridge.Name, 'shared/loader.lua'))
if not moduleloader or err then return error(err) end
moduleloader()

-- ❕ LOAD OVERRIDER ❕
module('override')

-- ❕ LOAD CACHE ❕
module('shared/cache')

-- ❕ LOAD VERSION CHECKER ❕
module('version')

-- ❕ LOAD UTILS ❕
module(('utils/%s'):format(Bridge.Context))
module('utils/shared')

-- ❕ LOAD HOOKS ❕
if Bridge.Context == 'server' then
    module('modules/hooks')
end

-- ❕ LOAD DATABASE ❕
if not Bridge.Disabled['database'] then
    module(('database/%s/%s'):format(Bridge.Database, Bridge.Context))
end

-- ❕ LOAD FRAMEWORK ❕
if not Bridge.Disabled['framework'] then
    module(('framework/%s/%s'):format(Bridge.Framework, Bridge.Context))
end

-- ❕ LOAD INVENTORY ❕
if not Bridge.Disabled['inventory'] then
    module(('inventory/%s/%s'):format(Bridge.Inventory, Bridge.Context))
end

-- ❕ LOAD TARGET ❕
if not Bridge.Disabled['target'] then
    module(('target/%s/%s'):format(Bridge.Target, Bridge.Context))
end

-- ❕ LOAD ZONE ❕
if not Bridge.Disabled['zone'] then
    module(('zone/%s/%s'):format(Bridge.Zone, Bridge.Context))
end

-- ❕ LOAD LOCALE ❕
if not Bridge.Disabled['locale'] then
    module('shared/locale')
end

-- ❕ LOAD SPRITES ❕
if not Bridge.Disabled['sprites'] and Bridge.Context == 'client' then
    module('sprites/init')
end

-- ❕ LOAD MENUS ❕
if not Bridge.Disabled['menu'] then
    module(('menu/%s/%s'):format(Bridge.Menu, Bridge.Context))
end

-- ❕ TEXTUI ❕
-- NOTE: TextUI is now loaded directly via fxmanifest.lua (client_scripts)
-- This ensures exports are registered before other resources try to use them
-- Other resources should use exports: exports.dusa_bridge:ShowTextUI(), exports.dusa_bridge:HideTextUI(), etc.

-- ❕ TELEMETRY ❕
-- NOTE: Telemetry is now loaded directly via fxmanifest.lua (shared_scripts, server_scripts, client_scripts)
-- This ensures proper loading order and avoids issues with module() in external resource contexts
-- The telemetry system is only available within dusa_bridge itself
-- Other resources should use exports: exports.dusa_bridge:registerTelemetry(), exports.dusa_bridge:reportError(), etc.

-- -- ❕ LOAD INTERACTION ❕
-- if not Bridge.Disabled['interaction'] and Bridge.Context == 'client' then
--     print('[^2BRIDGE^0] ^1Interaction^0 Loading')
--     print(1)
--     module('interaction/init')
--     print(2)
--     module(('interaction/%s/api'):format(Bridge.Context))
--     print(3)
--     module(('interaction/%s/defaults'):format(Bridge.Context))
--     print(4)
--     module(('interaction/%s/main'):format(Bridge.Context))
--     print(5)

--     print('[^2BRIDGE^0] ^1Interaction^0 Loaded')
-- end
