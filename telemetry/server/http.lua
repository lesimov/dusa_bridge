--[[
    Debug Dashboard HTTP Server
    Serves the browser-based live debug monitor and its JSON API.

    Open in a browser at:  http://<server-ip>:30120/dusa_bridge/debug

    Routes (paths are resource-relative; FiveM strips the /dusa_bridge prefix):
      GET /debug                 -> dashboard.html
      GET /debug/api/logs        -> ?since=&level=&category=&diag=&side=&q=
      GET /debug/api/problems    -> catalog merged with live aggregation
      GET /debug/api/report      -> single export blob (active problems + recent diags)
      GET /debug/api/clear       -> wipe the in-memory buffer
      GET /debug/api/status      -> store + catalog status

    OPEN SOURCE - Part of dusa_bridge
    SERVER ONLY
]]

local Config = TelemetryConfig and TelemetryConfig.DebugMap or {}
local LogStore = TelemetryLogStore
local Catalog = TelemetryCatalog
local SELF = GetCurrentResourceName()

if Config.Enabled == false then return end

local CORS = {
    ['Access-Control-Allow-Origin'] = '*',
    ['Access-Control-Allow-Methods'] = 'GET, OPTIONS',
    ['Access-Control-Allow-Headers'] = 'Content-Type, X-Debug-Token',
}

local function sendJson(res, data, status)
    local headers = { ['Content-Type'] = 'application/json; charset=utf-8' }
    for k, v in pairs(CORS) do headers[k] = v end
    res.writeHead(status or 200, headers)
    res.send(json.encode(data))
end

local function getPath(url)
    local q = url:find('%?')
    return q and url:sub(1, q - 1) or url
end

local function parseQuery(url)
    local query = {}
    local q = url:find('%?')
    if q then
        for k, v in url:sub(q + 1):gmatch('([^&=]+)=([^&]*)') do
            query[k] = v
        end
    end
    return query
end

--- URL-decode a query value (handles %XX and +).
local function urldecode(s)
    if not s then return nil end
    s = s:gsub('+', ' '):gsub('%%(%x%x)', function(h)
        return string.char(tonumber(h, 16))
    end)
    return s
end

--- Token gate for /debug/api/* (no-op when Config.Token is empty).
local function authorized(req, query)
    local token = Config.Token
    if not token or token == '' then return true end
    local provided = query.token or (req.headers and (req.headers['X-Debug-Token'] or req.headers['x-debug-token']))
    return provided == token
end

--- Build the /debug/api/problems payload: catalog defs + live counts.
local function buildProblems()
    local registry, source = Catalog.get()
    local agg = LogStore.getAggregation()

    local problems = {}
    -- Catalogued codes first
    for code, def in pairs(registry) do
        local a = agg[code]
        problems[#problems + 1] = {
            code = code,
            category = def.category,
            severity = def.severity,
            title = def.title,
            causes = def.causes,
            remediation = def.remediation,
            tags = def.tags,
            count = a and a.count or 0,
            firstSeen = a and a.firstSeen,
            lastSeen = a and a.lastSeen,
            catalogued = true,
        }
    end
    -- Observed-but-uncatalogued codes
    for code, a in pairs(agg) do
        if not registry[code] then
            problems[#problems + 1] = {
                code = code,
                category = a.category,
                title = a.lastMessage or code,
                count = a.count,
                firstSeen = a.firstSeen,
                lastSeen = a.lastSeen,
                catalogued = false,
            }
        end
    end

    return { ok = true, source = source, problems = problems }
end

SetHttpHandler(function(req, res)
    local rawPath = req.path or '/'
    local path = getPath(rawPath)
    local query = parseQuery(rawPath)

    if req.method == 'OPTIONS' then
        res.writeHead(200, CORS)
        res.send('')
        return
    end

    -- Dashboard page
    if path == '/debug' or path == '/debug/' then
        local html = LoadResourceFile(SELF, 'telemetry/web/debug.html')
        if not html then
            res.writeHead(404, { ['Content-Type'] = 'text/plain' })
            res.send('debug.html not found')
            return
        end
        res.writeHead(200, { ['Content-Type'] = 'text/html; charset=utf-8' })
        res.send(html)
        return
    end

    -- Everything under /debug/api/* is token-gated (when a token is configured)
    if path:sub(1, 11) == '/debug/api/' then
        if not authorized(req, query) then
            sendJson(res, { ok = false, error = 'unauthorized' }, 401)
            return
        end
    end

    if path == '/debug/api/logs' then
        local filters = {}
        if query.level then filters.level = tonumber(query.level) end
        if query.category and query.category ~= '' then filters.category = urldecode(query.category):upper() end
        if query.diag and query.diag ~= '' then filters.diag = urldecode(query.diag) end
        if query.side and query.side ~= '' then filters.side = urldecode(query.side) end
        if query.q and query.q ~= '' then filters.q = string.lower(urldecode(query.q)) end

        local result = LogStore.since(tonumber(query.since) or 0, filters)
        result.ok = true
        sendJson(res, result)
        return
    end

    if path == '/debug/api/problems' then
        sendJson(res, buildProblems())
        return
    end

    if path == '/debug/api/report' then
        local problems = buildProblems()
        local report = {
            ok = true,
            generatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            server = {
                resourceVersion = GetResourceMetadata(SELF, 'version', 0),
                fxVersion = GetConvar('version', 'unknown'),
            },
            status = LogStore.getStatus(),
            problems = problems.problems,
            catalogSource = problems.source,
            recentDiagnostics = LogStore.recentDiagnostics(Config.ReportEntries or 200),
        }
        sendJson(res, report)
        return
    end

    if path == '/debug/api/clear' then
        LogStore.clear()
        sendJson(res, { ok = true })
        return
    end

    if path == '/debug/api/status' then
        local _, source = Catalog.get()
        local status = LogStore.getStatus()
        status.ok = true
        status.catalogSource = source
        sendJson(res, status)
        return
    end

    sendJson(res, { ok = false, error = 'not_found', path = path }, 404)
end)

if not (TelemetryConfig and TelemetryConfig.Features and TelemetryConfig.Features.SilentMode) then
    print('^2[Telemetry]^7 Debug dashboard ready -> http://<ip>:30120/' .. SELF .. '/debug')
end
