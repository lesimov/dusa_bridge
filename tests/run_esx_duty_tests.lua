--[[
    Ticket 1228 regression harness: ESX job duty (on/off) propagation.

    Loads the REAL production files through the REAL module loader
    (shared/loader.lua -> module('framework/esx/<context>')) inside a minimal
    FiveM/ESX simulation:
      * Events: RegisterNetEvent marks an event network-safe (and optionally
        adds a handler); AddEventHandler only adds a local handler. Events sent
        across the network (TriggerServerEvent / TriggerClientEvent) are dropped
        unless the receiving side registered them with RegisterNetEvent, which
        is what FiveM does ("event ... was not safe for net").
      * `source` is set as a global while a server handler runs.
      * Threads (Citizen.CreateThreadNow) are coroutines; Wait yields.
      * ESX: shared object with GetPlayerData/SetPlayerData (client) and
        GetPlayerFromId + xPlayer get/set/triggerEvent (server).

    Usage (repo root):  lua5.4 tests/run_esx_duty_tests.lua [repo_root]
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
        print(('FAIL  %s%s'):format(name, detail ~= nil and ('  -> ' .. tostring(detail)) or ''))
    end
end

local function readFile(path)
    local f = io.open(ROOT .. '/' .. path, 'r')
    if not f then return nil end
    local s = f:read('a'); f:close()
    -- CfX Lua 5.4 extensions used by the bridge: safe navigation and compound `+=`.
    s = s:gsub('%?%.', '.')
    s = s:gsub('([%w_%.%[%]]+)%s*%+=%s*', '%1 = %1 + ')
    return s
end

local SRC = 1 -- server id of the simulated player

-- ---------------------------------------------------------------- FiveM side (one per context)
local function newSide(context, bridge, opts)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local side = { env = env, handlers = {}, net = {}, dropped = {}, requested = {} }

    local function addHandler(name, fn)
        side.handlers[name] = side.handlers[name] or {}
        table.insert(side.handlers[name], fn)
    end

    local function dispatch(name, src, ...)
        local list = side.handlers[name]
        if not list then return end
        for _, fn in ipairs(list) do
            local prev = env.source
            env.source = src
            local ok, err = pcall(fn, ...)
            env.source = prev
            if not ok then error(('handler %s failed: %s'):format(name, tostring(err)), 0) end
        end
    end

    -- Network delivery: FiveM drops events the receiver did not RegisterNetEvent.
    function side.receiveNet(name, src, ...)
        if not side.net[name] then
            side.dropped[#side.dropped + 1] = name
            return false
        end
        dispatch(name, src, ...)
        return true
    end

    env.RegisterNetEvent = function(name, fn)
        side.net[name] = true
        if fn then addHandler(name, fn) end
    end
    env.AddEventHandler = function(name, fn) addHandler(name, fn) end
    env.TriggerEvent = function(name, ...) dispatch(name, env.source, ...) end

    env.IsDuplicityVersion = function() return context == 'server' end
    env.GetCurrentResourceName = function() return bridge.Resource end
    env.GetResourceMetadata = function(_, key) if key == 'bridge' then return bridge.Name end return '1.0.0' end
    env.GetNumResourceMetadata = function() return 0 end
    env.GetResourceState = function(name) return (opts.started or {})[name] and 'started' or 'missing' end
    env.LoadResourceFile = function(res, path)
        side.requested[#side.requested + 1] = path
        if res ~= bridge.Name then return nil end
        if opts.onlyLoader and path ~= 'shared/loader.lua' then return nil end
        return readFile(path)
    end
    env.load = function(chunk, name, mode, e) return load(chunk, name, mode or 't', e or env) end
    env.print = function() end
    env.Wait = function() coroutine.yield() end
    env.Citizen = {
        CreateThreadNow = function(fn)
            local co = coroutine.create(fn)
            local ok, err = coroutine.resume(co)
            if not ok then error(err, 0) end
        end,
        Await = function() return nil end,
    }
    env.promise = { new = function() return { resolve = function() end } end }
    env.table = setmetatable({
        clone = function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end,
    }, { __index = table })
    env.json = { encode = function() return '{}' end, decode = function() return {} end }
    env.lib = {}
    env.override = {}
    env.PlayerId = function() return 0 end
    env.GetPlayerServerId = function() return SRC end
    env.GetPlayerName = function() return 'Tester' end
    env.AddStateBagChangeHandler = function() end
    env.exports = setmetatable({}, { __index = function(_, k) return (opts.exports or {})[k] end })
    env.Bridge = bridge
    env.Framework = {}
    return side
end

local function bridgeFor(context, framework, prefix, frameworkName)
    return {
        Name = 'dusa_bridge', Resource = 'dusa_mechanic', Context = context, DebugMode = false,
        Framework = framework, FrameworkName = frameworkName, FrameworkPrefix = prefix,
        FrameworkEvent = framework == 'esx' and 'esx:getSharedObject' or 'QBCore:GetObject',
    }
end

-- Load real loader then a real production module through module(), as bridge.lua does.
local function loadModule(side, path)
    local loader = assert(side.env.load(readFile('shared/loader.lua'), '@@dusa_bridge/shared/loader.lua'))
    loader()
    side.env.module(path)
end

local function addHooks(side)
    local h = { duty = 0, job = 0, loaded = 0 }
    side.env.Framework.OnJobDutyUpdate = function() h.duty = h.duty + 1 end
    side.env.Framework.OnJobUpdate = function() h.job = h.job + 1 end
    side.env.Framework.OnPlayerLoaded = function() h.loaded = h.loaded + 1 end
    return h
end

-- ---------------------------------------------------------------- ESX world (server + client)
local function esxWorld(initialClientJob)
    local world = {}
    local serverPlayerData = { duty = nil }

    local xPlayer = {
        source = SRC,
        get = function(k) return serverPlayerData[k] end,
        set = function(k, v) serverPlayerData[k] = v end,
        getIdentifier = function() return 'char1:abc' end,
        getMeta = function() return {} end,
        getJob = function() return { name = 'police', label = 'Police', grade = 1, grade_name = 'officer', grade_label = 'Officer' } end,
    }
    local serverESX = { GetPlayerFromId = function(id) if id == SRC then return xPlayer end end }
    local clientESX = { PlayerData = { identifier = 'char1:abc', job = initialClientJob } }
    clientESX.GetPlayerData = function() return clientESX.PlayerData end
    clientESX.SetPlayerData = function(k, v) clientESX.PlayerData[k] = v end
    clientESX.RegisterClientCallback = function() end

    local server = newSide('server', bridgeFor('server', 'esx', 'esx', 'es_extended'),
        { exports = { es_extended = { getSharedObject = function() return serverESX end } } })
    local client = newSide('client', bridgeFor('client', 'esx', 'esx', 'es_extended'),
        { exports = { es_extended = { getSharedObject = function() return clientESX end } } })

    server.env.Database = {
        prepare = function() return nil end,
        query = function() return {} end,
        scalar = function(q) if q:find('gang') then error('no gang tables', 0) end return nil end,
    }
    server.env.TriggerClientEvent = function(name, target, ...)
        if target == SRC or target == -1 then client.receiveNet(name, SRC, ...) end
    end
    xPlayer.triggerEvent = function(name, ...) server.env.TriggerClientEvent(name, xPlayer.source, ...) end
    client.env.TriggerServerEvent = function(name, ...) server.receiveNet(name, SRC, ...) end

    world.server, world.client = server, client
    world.xPlayer, world.serverData, world.clientESX = xPlayer, serverPlayerData, clientESX
    world.serverHooks = addHooks(server)
    world.clientHooks = addHooks(client)
    loadModule(server, 'framework/esx/server')
    loadModule(client, 'framework/esx/client')
    world.clientDuty = function() return client.env.Framework.Player.Job.Duty end
    return world
end

local function job(onDuty)
    return { name = 'police', label = 'Police', grade = 1, grade_name = 'officer', grade_label = 'Officer', onDuty = onDuty }
end

local CASES = { { label = 'nil', value = nil, expect = true }, { label = 'false', value = false, expect = false },
    { label = 'true', value = true, expect = true } }

-- A section that raises is reported as a failure instead of aborting the run.
local function section(name, fn)
    local ok, err = pcall(fn)
    check(name .. ' (completed without script error)', ok, err)
end

-- es_extended's own client handler stores the payload in ESX.PlayerData; the
-- bridge resource then receives the same network event.
local function esxClientLogin(w, playerData)
    w.clientESX.PlayerData = playerData
    w.client.receiveNet('esx:playerLoaded', SRC, playerData)
end

-- ---------------------------------------------------------------- server: setDuty is a network event
section('server setDuty', function()
    local w = esxWorld(job(nil))
    check('server: esx:setDuty registered with RegisterNetEvent (network safe)', w.server.net['esx:setDuty'] == true)
end)

for _, dir in ipairs({ { from = false, to = true }, { from = true, to = false } }) do
    section(('server setDuty %s -> %s'):format(tostring(dir.from), tostring(dir.to)), function()
        local w = esxWorld(job(dir.from))
        w.serverData.duty = dir.from
        local delivered = w.server.receiveNet('esx:setDuty', SRC, dir.to)
        check(('server: client-sent esx:setDuty(%s) is accepted by FiveM routing'):format(tostring(dir.to)),
            delivered == true, 'dropped: ' .. table.concat(w.server.dropped, ','))
        check(('server: setDuty(%s) from client sets xPlayer duty'):format(tostring(dir.to)),
            w.serverData.duty == dir.to, tostring(w.serverData.duty))
        check(('server: setDuty(%s) propagates to client Framework.Player.Job.Duty'):format(tostring(dir.to)),
            w.clientDuty() == dir.to, tostring(w.clientDuty()))
        check(('server: setDuty(%s) fires server OnJobDutyUpdate once'):format(tostring(dir.to)),
            w.serverHooks.duty == 1, w.serverHooks.duty)
        w.server.receiveNet('esx:setDuty', SRC, dir.to)
        check(('server: repeated setDuty(%s) short-circuits (no extra OnJobDutyUpdate)'):format(tostring(dir.to)),
            w.serverHooks.duty == 1, w.serverHooks.duty)
    end)
end

-- ---------------------------------------------------------------- client: init path (Framework.OnReady -> SetPlayerData)
for _, c in ipairs(CASES) do
    section('client init ' .. c.label, function()
        local w = esxWorld(job(c.value))
        check(('client init: job.onDuty=%s -> Duty %s'):format(c.label, tostring(c.expect)), w.clientDuty() == c.expect,
            tostring(w.clientDuty()))
    end)
end

-- ---------------------------------------------------------------- client: player-load path (esx:playerLoaded)
for _, c in ipairs(CASES) do
    section('client playerLoaded ' .. c.label, function()
        local w = esxWorld(nil)
        esxClientLogin(w, { identifier = 'char1:abc', job = job(c.value) })
        check(('client playerLoaded: job.onDuty=%s -> Duty %s'):format(c.label, tostring(c.expect)),
            w.clientDuty() == c.expect, tostring(w.clientDuty()))
    end)
end

-- ---------------------------------------------------------------- client: job update path (esx:setJob)
for _, c in ipairs(CASES) do
    section('client setJob ' .. c.label, function()
        local w = esxWorld(job(nil))
        w.client.receiveNet('esx:setJob', SRC, job(c.value))
        check(('client setJob: job.onDuty=%s -> Duty %s'):format(c.label, tostring(c.expect)),
            w.clientDuty() == c.expect, tostring(w.clientDuty()))
    end)
end

-- ---------------------------------------------------------------- client: setDuty event
for _, c in ipairs(CASES) do
    section('client setDuty ' .. c.label, function()
        -- Start from the opposite ESX state so the handler's own short-circuit does not trigger.
        local w = esxWorld(job(c.value ~= true))
        w.client.receiveNet('esx:setDuty', SRC, c.value)
        check(('client setDuty(%s) -> Duty %s'):format(c.label, tostring(c.expect)), w.clientDuty() == c.expect,
            tostring(w.clientDuty()))
        check(('client setDuty(%s) mirrors ESX job.onDuty'):format(c.label), w.clientESX.PlayerData.job.onDuty == c.value,
            tostring(w.clientESX.PlayerData.job.onDuty))
        check(('client setDuty(%s) fires OnJobDutyUpdate'):format(c.label), w.clientHooks.duty == 1, w.clientHooks.duty)
    end)
end

section('client setDuty unchanged', function()
    local w = esxWorld(job(false))
    w.client.receiveNet('esx:setDuty', SRC, false)
    check('client setDuty(false) while ESX already off duty short-circuits', w.clientHooks.duty == 0, w.clientHooks.duty)
end)

-- ---------------------------------------------------------------- full cycle: login -> on -> off -> on
section('full duty cycle', function()
    local w = esxWorld(nil)
    -- ESX client login: job without onDuty (default applies).
    esxClientLogin(w, { identifier = 'char1:abc', job = job(nil) })
    check('cycle: ESX login without onDuty uses default Duty true', w.clientDuty() == true, tostring(w.clientDuty()))
    -- Bridge server login handler forces off duty and pushes it to the client.
    w.server.env.TriggerEvent('esx:playerLoaded', SRC, w.xPlayer)
    check('cycle: server playerLoaded sets xPlayer duty false', w.serverData.duty == false, tostring(w.serverData.duty))
    check('cycle: server playerLoaded pushes off duty to client', w.clientDuty() == false, tostring(w.clientDuty()))

    local expected = { true, false, true }
    for i, want in ipairs(expected) do
        local before = w.clientHooks.duty
        w.client.env.Framework.ToggleDuty()
        check(('cycle toggle %d: server duty %s'):format(i, tostring(want)), w.serverData.duty == want,
            tostring(w.serverData.duty))
        check(('cycle toggle %d: client Duty %s'):format(i, tostring(want)), w.clientDuty() == want,
            tostring(w.clientDuty()))
        check(('cycle toggle %d: client OnJobDutyUpdate fired'):format(i), w.clientHooks.duty == before + 1,
            w.clientHooks.duty - before)
        local player = w.server.env.Framework.GetPlayer(SRC)
        check(('cycle toggle %d: Framework.GetPlayer Job.Duty %s'):format(i, tostring(want)),
            player and player.Job.Duty == want, player and tostring(player.Job.Duty))
    end
    check('cycle: no client->server duty event dropped', #w.server.dropped == 0, table.concat(w.server.dropped, ','))
end)

-- ---------------------------------------------------------------- non-ESX: bridge.lua routes to own framework
local function bridgeRoute(frameworkResource)
    local started = { dusa_bridge = true, oxmysql = true, ox_inventory = true, ox_lib = true, [frameworkResource] = true }
    local side = newSide('client', { Name = 'dusa_bridge', Resource = 'dusa_mechanic' },
        { started = started, onlyLoader = true })
    side.env.Bridge = nil
    side.env.Framework = nil
    local chunk = assert(load(readFile('bridge.lua'), '@bridge.lua', 't', side.env))
    local ok, err = pcall(chunk)
    local frameworks = {}
    for _, p in ipairs(side.requested) do
        local m = p:match('^framework/([^/]+)/client%.lua$')
        if m then frameworks[#frameworks + 1] = m end
    end
    return frameworks, ok, err
end

for _, r in ipairs({ { 'es_extended', 'esx' }, { 'qb-core', 'qb' }, { 'qbx_core', 'qbox' } }) do
    section('bridge route ' .. r[1], function()
        local fws, ok, err = bridgeRoute(r[1])
        check(('bridge.lua: %s started -> loads framework/%s only'):format(r[1], r[2]),
            ok and #fws == 1 and fws[1] == r[2], ok and table.concat(fws, ',') or err)
    end)
end

-- ---------------------------------------------------------------- non-ESX: QB / Qbox duty unchanged
local function qbClient(framework, frameworkName)
    local playerData = { job = { name = 'police', label = 'Police', onduty = false, isboss = false, grade = { name = 'Officer', level = 1 } } }
    local qbObject = { Functions = { GetPlayerData = function() return playerData end }, Shared = { Items = {} } }
    local side = newSide('client', bridgeFor('client', framework, 'QBCore', frameworkName),
        { exports = { [frameworkName] = { GetCoreObject = function() return qbObject end } } })
    local sent = {}
    side.env.TriggerServerEvent = function(name) sent[#sent + 1] = name end
    side.env.QBX = nil
    loadModule(side, ('framework/%s/client'):format(framework))
    return side, sent
end

for _, fwk in ipairs({ { 'qb', 'qb-core' }, { 'qbox', 'qbx_core' } }) do
    section(fwk[1] .. ' duty unchanged', function()
        local side, sent = qbClient(fwk[1], fwk[2])
        check(('%s: no esx:setDuty handler registered'):format(fwk[1]), side.handlers['esx:setDuty'] == nil)
        side.env.Framework.Player.Job = side.env.Framework.Player.Job or {}
        side.receiveNet('QBCore:Client:SetDuty', SRC, false)
        check(('%s: Client:SetDuty(false) keeps false'):format(fwk[1]), side.env.Framework.Player.Job.Duty == false,
            tostring(side.env.Framework.Player.Job.Duty))
        side.receiveNet('QBCore:Client:SetDuty', SRC, true)
        check(('%s: Client:SetDuty(true) keeps true'):format(fwk[1]), side.env.Framework.Player.Job.Duty == true,
            tostring(side.env.Framework.Player.Job.Duty))
        side.env.Framework.ToggleDuty()
        check(('%s: ToggleDuty still sends QBCore:ToggleDuty'):format(fwk[1]), sent[#sent] == 'QBCore:ToggleDuty',
            sent[#sent])
    end)
end

print(('\n%d passed, %d failed'):format(results.pass, results.fail))
os.exit(results.fail == 0 and 0 or 1)
