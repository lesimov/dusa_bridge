local store = require 'interaction.client.modules.store'
local config = require 'interaction.client.modules.config'
local GetActualScreenResolution = GetActualScreenResolution

local dui = {}
local screenW, screenH = GetActualScreenResolution()
local controlsRunning = false

function dui.register()
    if dui.instance then
        dui.instance:remove()
    end

    dui.loaded = false -- Explicitly set loaded to false before creating new instance
    dui.instance = lib.dui:new(
        {
            url = "nui://dusa_bridge/interaction/web/index.html",
            width = screenW,
            height = screenH,
        }
    )

    local timeout = 0
    while not dui.loaded and timeout < 50 do 
        Wait(100)
        timeout = timeout + 1
    end
    
    print('Dui load', dui.loaded)
    print('Dui instance', dui.instance, dui.instance.duiObject, dui.instance.url)
    if not dui.loaded then
        print('DUI yüklenemedi!')
        return
    end

    print('DUI yüklendi!')
    dui.sendMessage('visible', true)
    dui.sendMessage('setColor', config.themeColor)
end

RegisterNuiCallback('load', function(_, cb)
    dui.loaded = true
    Wait(1000)
    cb(1)
end)

RegisterNUICallback('currentOption', function(data, cb)
    store.current.index = data[1]
    cb(1)
end)

function dui.sendMessage(action, value)
    dui.instance:sendMessage({
        action = action,
        value = value
    })

    if action == 'setOptions' and not controlsRunning then
        if controlsRunning then return end
        controlsRunning = true
        CreateThread(function()
            while next(store.current) do
                dui.handleDuiControls()
                Wait(0)
            end
            controlsRunning = false
        end)
    end
end

local IsControlJustPressed = IsControlJustPressed
local SendDuiMouseWheel = SendDuiMouseWheel

dui.handleDuiControls = function()
    if not dui.instance or not dui.instance.duiObject then return end

    local input = false

    if (IsControlJustPressed(3, 180)) then -- SCROLL DOWN
        SendDuiMouseWheel(dui.instance.duiObject, -50, 0.0)
        input = true
    end

    if (IsControlJustPressed(3, 181)) then -- SCROLL UP
        SendDuiMouseWheel(dui.instance.duiObject, 50, 0.0)
        input = true
    end

    if (IsControlJustPressed(3, 173)) then -- ARROW DOWN
        SendDuiMouseWheel(dui.instance.duiObject, -50, 0.0)
        input = true
    end

    if (IsControlJustPressed(3, 172)) then -- ARROW UP
        SendDuiMouseWheel(dui.instance.duiObject, 50, 0.0)
        input = true
    end

    if (IsControlJustPressed(3, 25)) then -- MOUSE RIGHT CLICK
        RemoveInteraction()
        input = false
    end

    if input then
        Wait(200)
    end
end

dui.register() --- on load and on resource start?
return dui
