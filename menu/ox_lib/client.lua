module 'shared/debug'
module 'shared/resource'
module 'shared/table'

Version = resource.version(Bridge.Menu)
Bridge.Debug('Menu', Bridge.Menu, Version)

local menu = exports[Bridge.Menu]

---@param data ContextMenuProps | ContextMenuProps[]
function Menu.openMenu(data)
    menu:registerContext({id = data.id, title = data.title, options = data.options})
    menu:showContext(data.id)
    return data.id
end

function Menu.closeMenu(onExit)
    menu:hideContext(onExit)
end