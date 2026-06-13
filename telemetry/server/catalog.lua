--[[
    Diagnostic Catalog Provider
    Supplies the problem catalog (diagnostic code -> title / causes / remediation)
    that powers the dashboard's "Active Problems" panel.

    Source of truth lives in the producing resource (e.g. dusa_mechanic) so codes
    stay in sync with the runtime diag() calls. We prefer a LIVE pull from that
    resource's export, and fall back to a bundled JSON snapshot when it isn't
    started.

    OPEN SOURCE - Part of dusa_bridge
    SERVER ONLY
]]

TelemetryCatalog = TelemetryCatalog or {}
local Catalog = TelemetryCatalog

-- Resources that expose `getDiagnosticsCatalog` returning a { [code] = def } table.
local PRODUCERS = {
    { resource = 'dusa_mechanic', export = 'getDiagnosticsCatalog' },
}

local SELF = GetCurrentResourceName()

--- Try a live pull from each registered producer resource.
--- @return table merged { [code] = def }, table sources { [code] = resource }
local function pullLive()
    local merged, sources = {}, {}
    for _, p in ipairs(PRODUCERS) do
        if GetResourceState(p.resource) == 'started' then
            local ok, reg = pcall(function()
                return exports[p.resource][p.export]()
            end)
            if ok and type(reg) == 'table' then
                for code, def in pairs(reg) do
                    merged[code] = def
                    sources[code] = p.resource
                end
            end
        end
    end
    return merged, sources
end

--- Fallback: bundled snapshot shipped with dusa_bridge.
--- @return table { [code] = def }
local function loadBundled()
    local raw = LoadResourceFile(SELF, 'telemetry/catalog/diagnostics.json')
    if not raw or raw == '' then return {} end
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then
        -- Snapshot may be either { [code]=def } or { registry = { [code]=def } }
        return decoded.registry or decoded
    end
    return {}
end

--- Merged catalog: live producers win, bundled fills gaps.
--- @return table registry { [code] = def }, string source ('live'|'bundled'|'merged'|'empty')
function Catalog.get()
    local live, _ = pullLive()
    local hasLive = next(live) ~= nil

    local bundled = loadBundled()
    local hasBundled = next(bundled) ~= nil

    if not hasLive and not hasBundled then
        return {}, 'empty'
    end

    local merged = {}
    for code, def in pairs(bundled) do merged[code] = def end
    for code, def in pairs(live) do merged[code] = def end

    local source = hasLive and (hasBundled and 'merged' or 'live') or 'bundled'
    return merged, source
end
