--[[
    Ticket 1273 regression harness: include('ox_lib', 'init') against real ox_lib init.lua.

    ox_lib >= 3.40.1 derives its own resource name from the chunk name
    (debug.getinfo(1, 'S').source:match('^@@([^/]+)/.+')). dusa_bridge 0.9.7's include()
    named the chunk '@@' .. <file contents>, so the name came out as garbage,
    GetResourceState() returned 'missing' and init.lua raised
    "ox_lib must be started before this resource." on every start.

    Runs the REAL shared/loader.lua and the REAL ox_lib init.lua (fixtures, v3.39.0 and
    v3.40.3, taken unmodified from github.com/overextended/ox_lib tags) with stubbed FiveM
    natives. Every `include(...)` call site that loads ox_lib/init in this repo (and in any
    extra directory given on the command line, e.g. product resources) is executed in a fresh
    environment and must leave a working `lib` behind.

    Usage (repo root):
        lua5.4 tests/oxlib_include/run.lua [repo_root] [--loader <file>] [scan_dir ...]
        python tests/oxlib_include/run_lupa.py [same args]      (Windows, no lua5.4)
    --loader runs the checks against another loader.lua, e.g.
        tests/oxlib_include/fixtures/legacy/loader-0.9.7.lua (expected to FAIL on v3.40.3).
    Exit code 0 = all pass, 1 = failures.
]]

local argv = arg or {}
local ROOT = '.'
local LOADER = 'shared/loader.lua'
local SCAN = {}
do
    local i, first = 1, true
    while argv[i] do
        local a = argv[i]
        if a == '--loader' then
            LOADER = argv[i + 1]; i = i + 1
        elseif first then
            ROOT = a; first = false
        else
            SCAN[#SCAN + 1] = a
        end
        i = i + 1
    end
end
local FIXTURES = ROOT .. '/tests/oxlib_include/fixtures'
local VERSIONS = { 'v3.39.0', 'v3.40.3' }
local PRODUCT = 'dusa_mechanic'

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

local function readRaw(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local s = f:read('a'); f:close()
    return s
end

-- CfX Lua 5.4 extensions used by ox_lib, rewritten to stock Lua without changing line numbers:
--   X?.y  ->  (X or {}).y        a += 1  ->  a = a + 1
local function cfx(src)
    src = src:gsub('([%w_%.]+)%s*%+=', '%1 = %1 +')
    local out, pos = {}, 1
    while true do
        local s = src:find('?.', pos, true)
        if not s then break end
        -- only `name?.x` / `call()?.x`; leaves string templates such as './?.lua' alone
        if not src:sub(s - 1, s - 1):match('[%w_%)]') then
            out[#out + 1] = src:sub(pos, s + 1)
            pos = s + 2
            goto continue
        end
        local e = s - 1
        if src:sub(e, e) == ')' then
            local depth = 0
            repeat
                local c = src:sub(e, e)
                if c == ')' then depth = depth + 1 elseif c == '(' then depth = depth - 1 end
                e = e - 1
            until depth == 0
        end
        while e > 0 and src:sub(e, e):match('[%w_%.]') do e = e - 1 end
        local exprStart = e + 1
        assert(exprStart >= pos, 'overlapping ?. rewrite')
        out[#out + 1] = src:sub(pos, exprStart - 1)
        out[#out + 1] = ('(%s or {}).'):format(src:sub(exprStart, s - 1))
        pos = s + 2
        ::continue::
    end
    out[#out + 1] = src:sub(pos)
    return table.concat(out)
end

-- ------------------------------------------------------------------ virtual resources
local function resourceDirs(oxVersion)
    return {
        ox_lib = FIXTURES .. '/ox_lib-' .. oxVersion,
        dusa_bridge = ROOT,
        res_a = FIXTURES .. '/res_a',
        res_b = FIXTURES .. '/res_b',
    }
end

local function newEnv(oxVersion)
    local dirs = resourceDirs(oxVersion)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.lib, env.cache, env.require = nil, nil, nil
    env.chunkNames = {}

    env.load = function(chunk, name, mode, e)
        env.chunkNames[#env.chunkNames + 1] = name
        return load(chunk, name, mode or 't', e or env)
    end
    env.LoadResourceFile = function(res, file)
        local dir = dirs[res]
        if not dir then return nil end
        local s = readRaw(dir .. '/' .. file)
        return s and cfx(s) or nil
    end
    env.GetCurrentResourceName = function() return PRODUCT end
    env.GetResourceState = function(res) return res == 'ox_lib' and 'started' or 'missing' end
    env.IsDuplicityVersion = function() return true end
    env.GetGameName = function() return 'fxserver' end
    env.GetNumResourceMetadata = function() return 0 end
    env.GetResourceMetadata = function() return nil end
    env.AddEventHandler = function() end
    env.RegisterNetEvent = function() end
    env.TriggerClientEvent = function() end
    env.Wait = function() end
    env.SetTimeout = function() end
    env.Citizen = { CreateThreadNow = function(fn) fn(0) end, CreateThread = function(fn) fn() end }
    env.msgpack = { setoption = function() end }
    env.json = { encode = tostring, decode = function() return {} end }
    env.exports = setmetatable({}, {
        __index = function(_, res)
            if res ~= 'ox_lib' then error(('No such export in resource %s'):format(tostring(res)), 0) end
            return setmetatable({ hasLoaded = function() return true end }, {
                __index = function() return function() return nil end end,
            })
        end,
    })
    local tbl = setmetatable({}, { __index = table })
    tbl.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    tbl.create = function() return {} end
    env.table = tbl

    env.Framework = {}
    env.Bridge = {
        Name = 'dusa_bridge', Resource = PRODUCT, DebugMode = false, Context = 'server',
        ZoneName = 'ox_lib', FrameworkName = 'qbx_core', DatabaseName = 'oxmysql',
    }

    local src = assert(readRaw(ROOT .. '/' .. LOADER), 'loader not found: ' .. LOADER)
    assert(load(src, ('@@dusa_bridge/%s'):format(LOADER), 't', env))()
    return env
end

-- ------------------------------------------------------------------ call sites
local prefix = {}
local function listLua(dir)
    local cmd
    if package.config:sub(1, 1) == '\\' then
        local win = dir:gsub('/', '\\')
        local p = assert(io.popen(('cd /d "%s" && cd'):format(win)))
        prefix[dir] = (p:read('l') or dir):gsub('\\', '/')
        p:close()
        cmd = ('dir /s /b "%s\\*.lua" 2>nul'):format(win)
    else
        prefix[dir] = dir
        cmd = ('find "%s" -name "*.lua" -type f 2>/dev/null'):format(dir)
    end
    local p = assert(io.popen(cmd))
    local files = {}
    for line in p:lines() do
        line = line:gsub('\\', '/')
        if not line:find('/tests/', 1, true) and not line:find('/node_modules/', 1, true) then
            files[#files + 1] = line
        end
    end
    p:close()
    table.sort(files)
    return files
end

local function findCallSites(dir)
    local sites = {}
    for _, file in ipairs(listLua(dir)) do
        local n = 0
        for line in (readRaw(file) or ''):gmatch('([^\n]*)\n?') do
            n = n + 1
            local call = line:match("include%(%s*['\"]ox_lib['\"]%s*,%s*['\"]init['\"]%s*%)")
                or line:match('include%(%s*Bridge%.ZoneName%s*,%s*[\'"]init[\'"]%s*%)')
            if call and not line:match('^%s*%-%-') then
                sites[#sites + 1] = { file = file, line = n, code = line:gsub('\r$', ''):gsub('^%s+', '') }
            end
        end
    end
    return sites
end

local function runSite(oxVersion, code, label)
    local env = newEnv(oxVersion)
    local fn, cerr = load(code, ('=%s'):format(label), 't', env)
    if not fn then return false, cerr, env end
    local ok, err = pcall(fn)
    return ok, err, env
end

local function libOk(env, oxVersion)
    local lib = rawget(env, 'lib')
    if type(lib) ~= 'table' then return false, 'lib is ' .. type(lib) end
    if lib.name ~= 'ox_lib' then return false, 'lib.name = ' .. tostring(lib.name) end
    local cache = rawget(env, 'cache')
    if type(cache) ~= 'table' or rawget(cache, 'resource') ~= PRODUCT then
        return false, 'cache.resource = ' .. tostring(cache and rawget(cache, 'resource'))
    end
    if oxVersion ~= 'v3.39.0' and type(rawget(lib, 'require')) ~= 'function' then
        return false, 'lib.require missing'
    end
    return true
end

local function chunkNamed(env)
    for _, n in ipairs(env.chunkNames) do if n == '@@ox_lib/init.lua' then return true end end
    return false, ('init.lua chunk name: %q'):format(tostring(env.chunkNames[1]):sub(1, 24))
end

local function short(dir, file)
    local p = prefix[dir] or dir
    return file:sub(1, #p):lower() == p:lower() and file:sub(#p + 2) or file
end

print(('loader: %s'):format(LOADER))
local roots = { ROOT }
for _, d in ipairs(SCAN) do roots[#roots + 1] = d end

for _, oxVersion in ipairs(VERSIONS) do
    print(('\n== ox_lib %s =='):format(oxVersion))
    for _, dir in ipairs(roots) do
        local sites = findCallSites(dir)
        if dir == ROOT then check(('%s: bridge has include(ox_lib, init) call sites'):format(oxVersion), #sites > 0, #sites) end
        for _, site in ipairs(sites) do
            local label = ('%s:%d'):format(short(dir, site.file), site.line)
            local ok, err, env = runSite(oxVersion, site.code, label)
            local good, why = false, err
            if ok then good, why = libOk(env, oxVersion) end
            check(('%s  lib loads    %s  [%s]'):format(oxVersion, label, site.code), good, why)
            check(('%s  chunk name   %s'):format(oxVersion, label), chunkNamed(env))
        end
    end

    -- second include with lib already present is a no-op, not a reload error
    do
        local env = newEnv(oxVersion)
        local ok1, e1 = pcall(env.include, 'ox_lib', 'init')
        local first = rawget(env, 'lib')
        local ok2, e2 = pcall(function()
            if not rawget(env, 'lib') then env.include('ox_lib', 'init') end
        end)
        check(('%s  guarded second include keeps the same lib'):format(oxVersion),
            ok1 and ok2 and first ~= nil and rawget(env, 'lib') == first, e1 or e2)
    end
end

print('\n== include cache key ==')
do
    local env = newEnv('v3.40.3')
    local a = env.include('res_a', 'x')
    local b = env.include('res_b', 'x')
    check('same path from two resources returns each resource\'s module', a == 'A' and b == 'B',
        ('res_a/x -> %s, res_b/x -> %s'):format(tostring(a), tostring(b)))
    local names = table.concat(env.chunkNames, ', ')
    check('chunk names are @@<resource>/<path>.lua',
        names:find('@@res_a/x.lua', 1, true) and names:find('@@res_b/x.lua', 1, true), names)
end

print(('\n%d passed, %d failed'):format(results.pass, results.fail))
local code = results.fail == 0 and 0 or 1
if HARNESS_NO_EXIT then return code end
os.exit(code)
