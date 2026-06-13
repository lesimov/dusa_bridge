--[[
    Telemetry Log Store
    In-memory ring buffer for the live debug dashboard. Ingests structured log
    entries forwarded by ecosystem resources (e.g. dusa_mechanic) and keeps a
    bounded history plus a per-diagnostic-code aggregation for the
    "Active Problems" panel.

    OPEN SOURCE - Part of dusa_bridge
    SERVER ONLY

    Design notes:
      - Fixed-size array, O(1) push (overwrites the oldest entry when full).
      - `seq` is a monotonic counter that NEVER resets while the resource runs;
        dashboards poll `?since=<seq>` to fetch only new entries.
      - Independent of Sentry / Telemetry.isEnabled — this is a local dev tool.
]]

local Config = TelemetryConfig and TelemetryConfig.DebugMap or {}

TelemetryLogStore = TelemetryLogStore or {}
local LogStore = TelemetryLogStore

local CAP = math.max(100, tonumber(Config.BufferSize) or 5000)
local PAGE_LIMIT = math.max(50, tonumber(Config.PageLimit) or 1000)

-- Ring buffer state
local entries = {}      -- dense array of size up to CAP
local head = 0          -- index of the most-recently written slot (1..CAP)
local count = 0         -- number of slots currently used
local seq = 0           -- monotonic, never resets
local gen = 0           -- generation; bumped on every clear so dashboards drop stale rows

-- Per-diagCode aggregation: { [code] = { count, firstSeen, lastSeen, lastSeq, lastMessage, category, side } }
local agg = {}

-- Resources we've received logs from. Used to detect a producer (re)start and
-- wipe the previous session so the dashboard only shows the CURRENT session.
local seenResources = {}

--- Server-side receive timestamp string (HH:MM:SS).
local function nowStamp()
    local d = os.date('*t')
    return string.format('%02d:%02d:%02d', d.hour, d.min, d.sec)
end

--- Push a normalized entry into the ring buffer.
--- @param entry table
function LogStore.push(entry)
    if type(entry) ~= 'table' then return end

    seq = seq + 1
    entry.seq = seq
    entry.recvTime = os.time()
    entry.recvStamp = nowStamp()
    entry.resource = entry.resource or 'unknown'

    seenResources[entry.resource] = true

    head = (head % CAP) + 1
    entries[head] = entry
    if count < CAP then count = count + 1 end

    -- Aggregate diagnostic codes for the Active Problems panel
    local code = entry.diagCode
    if code then
        local a = agg[code]
        if not a then
            a = { count = 0, firstSeen = entry.recvStamp, category = entry.category, side = entry.side }
            agg[code] = a
        end
        a.count = a.count + 1
        a.lastSeen = entry.recvStamp
        a.lastSeq = seq
        a.lastMessage = entry.message
        a.category = entry.category or a.category
        a.side = entry.side or a.side
    end
end

--- Physical slot index for logical position `i` (1 = oldest .. count = newest).
local function slotAt(i)
    local start = ((head - count) % CAP) -- 0-based index of the oldest slot
    return ((start + (i - 1)) % CAP) + 1
end

--- Lowercased contains helper for free-text search.
local function matches(entry, filters)
    if filters.level and (tonumber(entry.level) or 0) < filters.level then return false end
    if filters.category and tostring(entry.category or ''):upper() ~= filters.category then return false end
    if filters.diag and tostring(entry.diagCode or '') ~= filters.diag then return false end
    if filters.side and tostring(entry.side or '') ~= filters.side then return false end
    if filters.q then
        local hay = string.lower(
            tostring(entry.message or '') .. ' ' ..
            tostring(entry.data or '') .. ' ' ..
            tostring(entry.diagCode or '') .. ' ' ..
            tostring(entry.category or '')
        )
        if not hay:find(filters.q, 1, true) then return false end
    end
    return true
end

--- Return entries with seq greater than `sinceSeq`, applying filters, capped at PAGE_LIMIT.
--- @param sinceSeq number
--- @param filters table|nil { level(number), category(UPPER), diag, side, q(lowercased) }
--- @return table { logs = {...}, seq = <latest seq>, total = <buffer count> }
function LogStore.since(sinceSeq, filters)
    sinceSeq = tonumber(sinceSeq) or 0
    filters = filters or {}

    local out = {}
    -- Iterate oldest -> newest so the dashboard receives entries in order.
    for i = 1, count do
        local e = entries[slotAt(i)]
        if e and e.seq > sinceSeq and matches(e, filters) then
            out[#out + 1] = e
            if #out >= PAGE_LIMIT then break end
        end
    end

    return { logs = out, seq = seq, total = count, gen = gen }
end

--- Snapshot of the diagnostic-code aggregation.
--- @return table
function LogStore.getAggregation()
    local copy = {}
    for code, a in pairs(agg) do
        copy[code] = {
            code = code,
            count = a.count,
            firstSeen = a.firstSeen,
            lastSeen = a.lastSeen,
            lastSeq = a.lastSeq,
            lastMessage = a.lastMessage,
            category = a.category,
            side = a.side,
        }
    end
    return copy
end

--- Most recent N entries that carry a diagCode (for the export report).
--- @param limit number
--- @return table
function LogStore.recentDiagnostics(limit)
    limit = math.max(1, tonumber(limit) or 200)
    local out = {}
    -- Newest -> oldest.
    for i = count, 1, -1 do
        local e = entries[slotAt(i)]
        if e and e.diagCode then
            out[#out + 1] = e
            if #out >= limit then break end
        end
    end
    return out
end

--- Clear the buffer. `seq` is intentionally NOT reset so polling clients stay
--- consistent; `gen` is bumped so open dashboards drop their stale rows.
function LogStore.clear()
    entries = {}
    head = 0
    count = 0
    agg = {}
    seenResources = {}
    gen = gen + 1
end

--- Status for /debug/api/status.
--- @return table
function LogStore.getStatus()
    local codes = 0
    for _ in pairs(agg) do codes = codes + 1 end
    return {
        count = count,
        cap = CAP,
        seq = seq,
        gen = gen,
        diagCodes = codes,
    }
end

-------------------------------------------
-- Export: ecosystem resources forward log entries here
-------------------------------------------

exports('ingestLog', function(entry)
    if Config.Enabled == false then return end
    -- Never throw back into the caller's logging path.
    pcall(LogStore.push, entry)
end)

-------------------------------------------
-- Session scoping: wipe the buffer when a producing resource (re)starts, so the
-- dashboard only ever shows the CURRENT script session. The new session's logs
-- are emitted slightly after onResourceStart fires, so they survive the clear.
-------------------------------------------

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end
    -- Only react to resources we've actually received logs from before.
    if seenResources[resourceName] then
        LogStore.clear()
    end
end)
