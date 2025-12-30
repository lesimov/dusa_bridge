---@class TextUI
TextUI = {}

local textUIShown = false
local currentPromptData = nil

---Show text UI with custom styling
---@param text string The text to display
---@param options? table Optional configuration { key: string, position: string, active: boolean, visible: boolean }
function TextUI.Show(text, options)
    if textUIShown then return end

    options = options or {}
    local promptText = text or 'Interact'
    local promptKey = options.key or 'E'
    local position = options.position or 'left-center'
    local active = options.active or false
    local visible = options.visible or true

    -- Use custom InteractionPrompt component via NUI
    SendNUIMessage({
        action = 'showInteractionPrompt',
        data = {
            text = promptText,
            key = promptKey,
            active = active,
            visible = visible,
            position = position
        }
    })

    textUIShown = true
    currentPromptData = {
        text = promptText,
        key = promptKey,
        position = position
    }
end

---Hide text UI
function TextUI.Hide()
    if not textUIShown then return end

    SendNUIMessage({
        action = 'hideInteractionPrompt'
    })

    textUIShown = false
    currentPromptData = nil
end

---Set active state (when key is pressed)
---This will trigger the active animation and then hide the prompt
function TextUI.SetActive()
    if not textUIShown then return end

    -- Toggle active state (triggers animation in UI)
    SendNUIMessage({
        action = 'toggleInteractionPromptActive'
    })

    -- Hide after a short delay to show the active animation
    CreateThread(function()
        Wait(200) -- Wait for animation
        SendNUIMessage({
            action = 'hideInteractionPrompt'
        })
        textUIShown = false
        currentPromptData = nil
    end)
end

---Check if text UI is open
---@return boolean
function TextUI.IsOpen()
    return textUIShown
end

---Update text while keeping UI visible
---@param text string New text to display
function TextUI.UpdateText(text)
    if not textUIShown or not currentPromptData then return end

    currentPromptData.text = text
    SendNUIMessage({
        action = 'updateInteractionPromptText',
        data = {
            text = text
        }
    })
end

---Update position while keeping UI visible
---@param position string New position ('left-center', 'top-center', 'right-center', etc.)
function TextUI.UpdatePosition(position)
    if not textUIShown or not currentPromptData then return end

    currentPromptData.position = position
    SendNUIMessage({
        action = 'updateInteractionPromptPosition',
        data = {
            position = position
        }
    })
end

-- Export functions
exports('ShowTextUI', TextUI.Show)
exports('HideTextUI', TextUI.Hide)
exports('SetActiveTextUI', TextUI.SetActive)
exports('IsTextUIOpen', TextUI.IsOpen)
exports('UpdateTextUIText', TextUI.UpdateText)
exports('UpdateTextUIPosition', TextUI.UpdatePosition)
