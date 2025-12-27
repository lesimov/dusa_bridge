--[[
    Server Context Collection
    Gathers enhanced server information for Sentry tags

    OPEN SOURCE - Part of dusa_bridge
    SERVER ONLY
]]

local Config = TelemetryConfig

-- Global context manager
TelemetryContext = TelemetryContext or {}
local Context = TelemetryContext

-- Registered resources using telemetry
local registeredResources = {}

-- Cached server info (refreshed periodically)
local cachedServerInfo = nil
local lastCacheTime = 0
local CACHE_TTL = 60  -- Refresh every 60 seconds

-- Flag to track if Bridge was found
local bridgeChecked = false
local bridgeAvailable = false

-------------------------------------------
-- Bridge Detection
-------------------------------------------

-- Check if Bridge global is available (set by other resources using @dusa_bridge/bridge.lua)
local function checkBridgeAvailability()
    if bridgeChecked then
        return bridgeAvailable
    end

    -- Bridge is set by resources that use @dusa_bridge/bridge.lua in their shared_scripts
    -- Since telemetry loads within dusa_bridge itself, Bridge may not be set yet
    -- We need to detect the framework/inventory/etc. directly

    bridgeChecked = true
    bridgeAvailable = Bridge ~= nil and Bridge.Framework ~= nil
    return bridgeAvailable
end

-- Detect framework directly (fallback when Bridge isn't available)
local function detectFramework()
    if GetResourceState('qbx_core') ~= 'missing' then
        return 'qbox', 'qbx_core'
    elseif GetResourceState('qb-core') ~= 'missing' then
        return 'qb', 'qb-core'
    elseif GetResourceState('es_extended') ~= 'missing' then
        return 'esx', 'es_extended'
    elseif GetResourceState('ox_core') ~= 'missing' then
        return 'ox', 'ox_core'
    elseif GetResourceState('ND_Core') ~= 'missing' then
        return 'ndcore', 'ND_Core'
    end
    return 'unknown', nil
end

-- Detect inventory directly
local function detectInventory()
    if GetResourceState('ox_inventory') ~= 'missing' then
        return 'ox_inventory', 'ox_inventory'
    elseif GetResourceState('qb-inventory') ~= 'missing' then
        return 'qb-inventory', 'qb-inventory'
    elseif GetResourceState('qs-inventory') ~= 'missing' then
        return 'qs-inventory', 'qs-inventory'
    elseif GetResourceState('ps-inventory') ~= 'missing' then
        return 'qb-inventory', 'ps-inventory'
    elseif GetResourceState('lj-inventory') ~= 'missing' then
        return 'qb-inventory', 'lj-inventory'
    elseif GetResourceState('codem-inventory') ~= 'missing' then
        return 'qb-inventory', 'codem-inventory'
    elseif GetResourceState('tgiann-inventory') ~= 'missing' then
        return 'tgiann-inventory', 'tgiann-inventory'
    elseif GetResourceState('core_inventory') ~= 'missing' then
        return 'core_inventory', 'core_inventory'
    end
    return 'none', nil
end

-- Detect target directly
local function detectTarget()
    if GetResourceState('ox_target') ~= 'missing' then
        return 'ox_target', 'ox_target'
    elseif GetResourceState('qb-target') ~= 'missing' then
        return 'qb-target', 'qb-target'
    elseif GetResourceState('qtarget') ~= 'missing' then
        return 'qtarget', 'qtarget'
    elseif GetResourceState('meta_target') ~= 'missing' then
        return 'meta_target', 'meta_target'
    end
    return 'none', nil
end

-- Detect zone system directly
local function detectZone()
    if GetResourceState('ox_lib') ~= 'missing' then
        return 'ox_lib', 'ox_lib'
    elseif GetResourceState('PolyZone') ~= 'missing' then
        return 'polyzone', 'PolyZone'
    end
    return 'none', nil
end

-- Detect database directly
local function detectDatabase()
    if GetResourceState('oxmysql') ~= 'missing' then
        return 'oxmysql', 'oxmysql'
    end
    return 'none', nil
end

-------------------------------------------
-- Helper Functions
-------------------------------------------

-- Parse artifact version from FiveM version string
-- Example: "FXServer-master SERVER v1.0.0.7290 win32"
local function parseArtifactVersion(versionString)
    if not versionString then return 'unknown' end

    -- Try to extract version number
    local version = versionString:match('v?(%d+%.%d+%.%d+%.%d+)')
    if version then return version end

    -- Try to extract build number
    local build = versionString:match('(%d%d%d%d+)')
    if build then return 'build-' .. build end

    return 'unknown'
end

-- Sanitize server name (remove IPs, limit length)
local function sanitizeServerName(name)
    if not name then return 'Unknown Server' end

    -- Remove IP addresses
    name = name:gsub('%d+%.%d+%.%d+%.%d+', '[IP]')

    -- Remove port numbers
    name = name:gsub(':%d+', '')

    -- Limit length
    if #name > Config.Privacy.MaxServerNameLength then
        name = name:sub(1, Config.Privacy.MaxServerNameLength) .. '...'
    end

    return name
end

-- Get resource version safely
local function getResourceVersion(resourceName)
    if not resourceName then return nil end
    if GetResourceState(resourceName) == 'missing' then return nil end

    local version = GetResourceMetadata(resourceName, 'version', 0)
    return version or 'unknown'
end

-------------------------------------------
-- Public API
-------------------------------------------

--- Get enhanced server information
--- @return table serverInfo
function Context.getServerInfo()
    local now = os.time()

    -- Return cached if fresh
    if cachedServerInfo and (now - lastCacheTime) < CACHE_TTL then
        return cachedServerInfo
    end

    local rawVersion = GetConvar('version', 'unknown')
    local rawServerName = GetConvar('sv_hostname', 'Unknown Server')

    -- Check if Bridge global is available (set by resources using @dusa_bridge/bridge.lua)
    local hasBridge = checkBridgeAvailability()

    -- Get framework info (from Bridge if available, otherwise detect directly)
    local frameworkType, frameworkName
    if hasBridge and Bridge.Framework then
        frameworkType = Bridge.Framework
        frameworkName = Bridge.FrameworkName
    else
        frameworkType, frameworkName = detectFramework()
    end

    -- Get inventory info
    local inventoryType, inventoryName
    if hasBridge and Bridge.Inventory then
        inventoryType = Bridge.Inventory
        inventoryName = Bridge.InventoryName
    else
        inventoryType, inventoryName = detectInventory()
    end

    -- Get target info
    local targetType, targetName
    if hasBridge and Bridge.Target then
        targetType = Bridge.Target
        targetName = Bridge.TargetName
    else
        targetType, targetName = detectTarget()
    end

    -- Get zone info
    local zoneType, zoneName
    if hasBridge and Bridge.Zone then
        zoneType = Bridge.Zone
        zoneName = Bridge.ZoneName
    else
        zoneType, zoneName = detectZone()
    end

    -- Get database info
    local databaseType, databaseName
    if hasBridge and Bridge.Database then
        databaseType = Bridge.Database
        databaseName = Bridge.DatabaseName
    else
        databaseType, databaseName = detectDatabase()
    end

    cachedServerInfo = {
        -- Basic info
        serverName = sanitizeServerName(rawServerName),
        fxVersion = rawVersion,
        artifactVersion = parseArtifactVersion(rawVersion),

        -- Framework
        frameworkName = frameworkName or 'unknown',
        frameworkType = frameworkType or 'unknown',
        frameworkVersion = frameworkName and getResourceVersion(frameworkName) or 'unknown',

        -- Inventory
        inventoryName = inventoryName or 'none',
        inventoryType = inventoryType or 'none',

        -- Target
        targetName = targetName or 'none',
        targetType = targetType or 'none',

        -- Zone
        zoneName = zoneName or 'none',
        zoneType = zoneType or 'none',

        -- Database
        databaseName = databaseName or 'none',
        databaseType = databaseType or 'none',

        -- ox_lib version (commonly used)
        oxLibVersion = getResourceVersion('ox_lib'),

        -- Bridge version
        bridgeVersion = hasBridge and Bridge.Version or getResourceVersion('dusa_bridge') or 'unknown',

        -- Registered telemetry resources
        registeredResources = Context.getRegisteredResourceNames(),
    }

    lastCacheTime = now
    return cachedServerInfo
end

--- Get server info formatted as Sentry tags
--- @return table tags
function Context.getServerTags()
    local info = Context.getServerInfo()

    return {
        ['server.name'] = info.serverName,
        ['server.artifact'] = info.artifactVersion,
        ['bridge.framework'] = info.frameworkType,
        ['bridge.inventory'] = info.inventoryType,
        ['bridge.target'] = info.targetType,
        ['bridge.zone'] = info.zoneType,
        ['bridge.database'] = info.databaseType,
        ['bridge.version'] = info.bridgeVersion,
    }
end

--- Register a resource for telemetry
--- @param resourceName string
--- @param options table|nil
function Context.registerResource(resourceName, options)
    registeredResources[resourceName] = {
        name = resourceName,
        version = getResourceVersion(resourceName),
        registeredAt = os.time(),
        options = options or {},
    }

    -- Invalidate cache
    cachedServerInfo = nil
end

--- Unregister a resource
--- @param resourceName string
function Context.unregisterResource(resourceName)
    registeredResources[resourceName] = nil
    cachedServerInfo = nil
end

--- Check if a resource is registered
--- @param resourceName string
--- @return boolean
function Context.isResourceRegistered(resourceName)
    return registeredResources[resourceName] ~= nil
end

--- Get registered resource info
--- @param resourceName string
--- @return table|nil
function Context.getResourceInfo(resourceName)
    return registeredResources[resourceName]
end

--- Get list of registered resource names
--- @return string[]
function Context.getRegisteredResourceNames()
    local names = {}
    for name, _ in pairs(registeredResources) do
        table.insert(names, name)
    end
    return names
end

--- Get all registered resources
--- @return table
function Context.getRegisteredResources()
    return registeredResources
end

--- Invalidate the server info cache (call after Bridge changes)
function Context.invalidateCache()
    cachedServerInfo = nil
    lastCacheTime = 0
end

return Context
