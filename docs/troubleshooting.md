# Troubleshooting Guide

## Common Issues and Solutions

### Bridge Initialization Issues

#### Bridge Not Found Error

**Error Message**: `Bridge Not Found, Bridge Tag Must Be Included In Resource Manifest`

**Cause**: The resource manifest is missing the bridge metadata tag.

**Solution**:
```lua
-- Add to fxmanifest.lua
bridge 'dusa_bridge'
```

#### Lua Version Error

**Error Message**: `Lua 5.4 Must Be Enabled In The Resource Manifest`

**Cause**: The resource is not using Lua 5.4.

**Solution**:
```lua
-- Add to fxmanifest.lua
lua54 'yes'
```

#### Bridge Must Be Started First

**Error Message**: `dusa_bridge Must Be Started Before This Resource`

**Cause**: The bridge resource is not started before your resource.

**Solution**:
```cfg
# In server.cfg - ensure proper order
ensure dusa_bridge
ensure your_resource
```

### Framework Detection Issues

#### No Compatible Framework Found

**Error Message**: `No Compatible Framework Resource Found`

**Causes and Solutions**:

1. **Framework not started**: Ensure your framework is started before the bridge
   ```cfg
   ensure es_extended  # or your framework
   ensure dusa_bridge
   ```

2. **Custom framework name**: Use override configuration
   ```lua
   -- In override.lua
   override.framework = 'esx'
   override.frameworkname = 'my_custom_esx'
   ```

3. **Framework not supported**: Check supported frameworks list or contact developers

#### Framework Detection Incorrect

**Problem**: Bridge detects wrong framework when multiple are present.

**Solution**: Use override configuration to specify exact framework
```lua
-- In override.lua
override.framework = 'esx'  -- Force ESX
override.frameworkname = 'es_extended'
override.frameworkevent = 'esx:getSharedObject'
```

### Database Issues

#### No Compatible Database Found

**Error Message**: `No Compatible Database Resource Found`

**Solutions**:

1. **Install OXMySQL**:
   ```cfg
   ensure oxmysql
   ensure dusa_bridge
   ```

2. **Override database configuration**:
   ```lua
   -- In override.lua
   override.database = 'oxmysql'
   override.databasename = 'oxmysql'
   ```

#### Database Connection Problems

**Symptoms**: Database queries failing, timeout errors

**Solutions**:

1. **Check database configuration**: Verify connection string in oxmysql
2. **Check database permissions**: Ensure database user has proper permissions
3. **Test connection**: Use database testing tools

### Inventory System Issues

#### Inventory Not Detected

**Error Message**: `No Compatible Inventory Resource Found`

**Solutions**:

1. **Check inventory resource**: Ensure supported inventory is installed and started
2. **Override inventory configuration**:
   ```lua
   -- In override.lua
   override.inventory = 'ox_inventory'
   override.inventoryname = 'ox_inventory'
   ```

#### Item Images Not Loading

**Problem**: Items show without images in inventory

**Solutions**:

1. **Check image path**:
   ```lua
   -- In override.lua
   override.imagepath = "ox_inventory/web/images/"
   ```

2. **Verify image files exist**: Check that item images are in the correct folder

3. **Check file permissions**: Ensure web server can access image files

#### Items Not Adding/Removing

**Problem**: Inventory operations fail silently

**Solutions**:

1. **Check item exists**: Verify item is registered in your inventory system
2. **Check player data**: Ensure player is fully loaded
3. **Debug inventory calls**:
   ```lua
   local success = Inventory.AddItem(source, 'bread', 1)
   print('Add item result:', success)
   ```

### Target System Issues

#### Targets Not Appearing

**Problem**: Target zones don't show interaction prompts

**Solutions**:

1. **Check target resource**: Ensure target system is started before bridge
2. **Verify zone creation**:
   ```lua
   -- Add debug to see if zone is created
   print('Creating zone:', name, coords)
   Target.AddBoxZone(name, coords, length, width, options)
   ```

3. **Check distance**: Ensure you're within interaction distance
4. **Debug mode**: Enable target debug mode
   ```lua
   -- For ox_target
   exports.ox_target:debug(true)
   ```

#### Target Options Not Working

**Problem**: Target shows but clicking does nothing

**Solutions**:

1. **Check event registration**: Ensure events are properly registered
2. **Verify event names**: Check for typos in event names
3. **Check job requirements**: Verify player meets job/grade requirements

### Zone Management Issues

#### Zones Not Working

**Problem**: Zone enter/exit events not triggering

**Solutions**:

1. **Check zone resource**: Ensure ox_lib or PolyZone is properly installed
2. **Verify coordinates**: Check zone coordinates are correct
3. **Debug zone creation**:
   ```lua
   local zone = Zone.CreateBox(coords, size, rotation, {
       onEnter = function()
           print('Entered zone')
       end,
       onExit = function()
           print('Exited zone')
       end
   })
   ```

### Menu System Issues

#### Menus Not Opening

**Problem**: Menu.Show() calls don't display menu

**Solutions**:

1. **Check menu resource**: Ensure ox_lib or qb-menu is installed
2. **Verify menu data structure**:
   ```lua
   Menu.Show({
       title = 'Test Menu',
       items = {
           {
               title = 'Option 1',
               description = 'Test option',
               event = 'test:event'
           }
       }
   })
   ```

3. **Check for NUI errors**: Look for browser console errors

### Performance Issues

#### High CPU Usage

**Causes and Solutions**:

1. **Too many zones**: Reduce number of active zones
   ```lua
   -- Implement zone loading/unloading based on distance
   CreateThread(function()
       while true do
           local playerCoords = GetEntityCoords(PlayerPedId())
           ManageZonesByDistance(playerCoords)
           Wait(5000)
       end
   end)
   ```

2. **Excessive target checks**: Optimize target options
   ```lua
   -- Use canInteract function to reduce checks
   {
       canInteract = function()
           return GetPlayerData().job.name == 'police'
       end
   }
   ```

#### Memory Issues

**Problem**: Resource using excessive memory

**Solutions**:

1. **Clean up unused zones**: Remove zones when no longer needed
   ```lua
   Target.RemoveZone(zoneName)
   Zone.Remove(zone)
   ```

2. **Optimize callbacks**: Avoid creating too many callbacks
3. **Use proper cleanup**: Clean up on resource stop

### Debug and Logging

#### Enable Debug Mode

```lua
-- In override.lua
override.debug = true
```

This will show:
- Framework detection results
- Module loading status
- Resource compatibility information

#### Custom Debug Functions

```lua
-- Debug player data
RegisterCommand('debugplayer', function()
    local playerData = Framework.GetPlayerData()
    print('Player data:', json.encode(playerData, {indent = true}))
end)

-- Debug bridge status
RegisterCommand('bridgestatus', function()
    print('Framework:', Bridge.Framework)
    print('Inventory:', Bridge.Inventory)
    print('Target:', Bridge.Target)
    print('Database:', Bridge.Database)
end)

-- Debug inventory
RegisterCommand('debuginv', function(source)
    local items = Inventory.GetItems(source)
    print('Inventory:', json.encode(items, {indent = true}))
end, true)
```

### Version Compatibility

#### Outdated Bridge Version

**Problem**: Features not working with newer framework versions

**Solutions**:

1. **Update bridge**: Download latest bridge version
2. **Check compatibility**: Verify framework version compatibility
3. **Report issues**: Contact bridge developers for support

#### Framework Version Conflicts

**Problem**: Bridge not working with specific framework version

**Solutions**:

1. **Check supported versions**: Verify your framework version is supported
2. **Use override configuration**: Force specific settings
3. **Downgrade/upgrade**: Use compatible framework version

### Resource Conflicts

#### Multiple Bridges

**Problem**: Conflicts when multiple bridge resources are present

**Solutions**:

1. **Remove duplicate bridges**: Keep only one bridge resource
2. **Check resource priorities**: Ensure proper loading order

#### Export Conflicts

**Problem**: Export function names conflicting with other resources

**Solutions**:

1. **Use specific exports**: Use full export syntax
   ```lua
   exports.dusa_bridge:GetPlayerData()
   ```

2. **Check export names**: Verify export function names

### Getting Help

#### Console Output

Always check your server console for error messages and warnings. Enable debug mode for detailed information.

#### Log Files

Check FiveM log files for additional error information:
- `server.log`
- `client.log` (if available)

#### Community Support

1. **Documentation**: Check all documentation files
2. **Examples**: Review example implementations
3. **GitHub Issues**: Report bugs or request help
4. **Community Forums**: Ask in FiveM development communities

#### Reporting Issues

When reporting issues, include:

1. **Bridge version**: Current bridge version
2. **Framework and version**: What framework you're using
3. **Error messages**: Complete error messages from console
4. **Configuration**: Your override.lua settings
5. **Reproduction steps**: How to reproduce the issue
6. **Server setup**: Other resources that might be related

#### Emergency Debugging

If bridge is completely broken:

1. **Disable modules**: Use bridge_disable to disable problematic modules
   ```lua
   -- In fxmanifest.lua
   bridge_disable 'inventory'
   bridge_disable 'target'
   ```

2. **Manual configuration**: Override all settings manually
3. **Minimal setup**: Test with minimal resource configuration
4. **Fresh installation**: Try clean bridge installation