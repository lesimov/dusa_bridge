--[[
    https://github.com/Sleepless-Development/sleepless_interact

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 DemiAutomatic <https://github.com/DemiAutomatic>
]]

local store = {}
store.cooldownEndTime = 0

store.nearby = {}

store.coords = {}
store.coordIds = {}

store.localEntities = {}
store.entities = {}

store.offsets = {
    localEntities = {},
    entities = {},
    models = {},
    peds = {},
    objects = {},
    vehicles = {},
    players = {},
}

store.bones = {
    localEntities = {},
    entities = {},
    models = {},
    peds = {},
    objects = {},
    vehicles = {},
    players = {},
}

store.peds = {}
store.objects = {}
store.vehicles = {}
store.players = {}
store.models = {}

store.current = {}

return store
