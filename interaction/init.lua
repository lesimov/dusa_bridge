local export = exports.dusa_bridge

local function call(self, index, ...)
    local function method(...)
        return export[index](nil, ...)
    end

    if not ... then
        self[index] = method
    end

    return method
end

local interact = setmetatable({
    name = 'dusa_bridge',
}, {
    __index = call,
    __newindex = function(self, key, fn)
        rawset(self, key, fn)

        if debug.getinfo(2, 'S').short_src:find('@dusa_bridge/interaction/client/api.lua') then
            exports(key, fn)
        end
    end
})

_ENV.interact = interact