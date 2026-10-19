local modules = {}

-- Override standard Lua module
module = module

---Module Loader
---@param path string
module = function(path)
    if path == nil then return end
    local module = modules[path]
    if not module then
        local resource = LoadResourceFile(Bridge.Name, ('%s.lua'):format(path))
        if resource then
            local module, err = load(resource, ('@@%s/%s'):format(Bridge.Name, ('%s'):format(path)))
            if not module or err then
                modules[path] = nil
                return error(err)
            end
            if Bridge.DebugMode then print(('[^2MODULE^0] ^5Loaded^0 %s'):format(path)) end
            modules[path] = module(path)
            return modules[path]
        end
    end
    return module
end

---Module Loader From Other Resources
---The chunk is named '@@<resource>/<path>.lua' like FiveM's own loader; ox_lib >= 3.40.1
---derives its resource name from this (debug.getinfo(1, 'S').source).
---@param resourceName string
---@param path string
include = function(resourceName, path)
    if resourceName == nil or path == nil then return end
    local key = ('%s:%s'):format(resourceName, path)
    local module = modules[key]
    if not module then
        local file = LoadResourceFile(resourceName, ('%s.lua'):format(path))
        if file then
            local chunk, err = load(file, ('@@%s/%s.lua'):format(resourceName, path))
            if not chunk or err then
                modules[key] = nil
                return error(err)
            end
            if Bridge.DebugMode then print(('[^2IMPORT^0] ^5Loaded^0 %s/%s'):format(resourceName, path)) end
            modules[key] = chunk(path)
            return modules[key]
        end
    end
    return module
end

local OnReady = function(obj, cb)
    while not obj do
        Wait(50)
    end
    return cb and cb() or true
end

---@private
Framework.OnReady = setmetatable({
    await = OnReady
}, {
    __call = function(_, obj, cb)
        Citizen.CreateThreadNow(function() OnReady(obj, cb) end)
    end,
})