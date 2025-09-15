# Configuration Guide

## Override System

Dusa Bridge uses an automatic detection system, but you can override any configuration in the `override.lua` file.

## Override.lua Configuration

```lua
override = {}

-- Enable or disable debug mode
override.debug = false

-- Set the locale
override.locale = 'en'

-- Database Configuration
override.database = 'oxmysql'
override.databasename = 'oxmysql'

-- Framework Configuration
override.framework = 'esx'  -- 'esx', 'qb', 'qbox', 'ox', 'vrp', 'ndcore'
override.frameworkname = 'es_extended'
override.frameworkevent = 'esx:getSharedObject'
override.frameworkprefix = 'esx'

-- Inventory Configuration
override.inventory = 'ox_inventory'
override.inventoryname = 'ox_inventory'
override.imagepath = "ox_inventory/web/images/"

-- Target Configuration
override.target = 'ox_target'
override.targetname = 'ox_target'

-- Zone Configuration
override.zone = 'ox_lib'
override.zonename = 'ox_lib'

-- Menu Configuration
override.menu = 'ox_lib'  -- 'ox_lib' or 'qb-menu'
```

## Module Disabling

You can disable specific modules by adding metadata to your resource manifest:

```lua
-- In fxmanifest.lua
bridge_disable 'framework'  -- Disable framework integration
bridge_disable 'inventory'  -- Disable inventory integration
bridge_disable 'target'     -- Disable target integration
bridge_disable 'zone'       -- Disable zone integration
bridge_disable 'database'   -- Disable database integration
bridge_disable 'locale'     -- Disable locale system
bridge_disable 'sprites'    -- Disable sprite system
bridge_disable 'menu'       -- Disable menu integration
```

## Debug Mode

Enable debug mode to see detailed information about bridge detection and loading:

```lua
-- In override.lua
override.debug = true
```

Debug output includes:
- Detected framework, inventory, target, zone systems
- Module loading status
- Disabled modules
- Version information

## Framework-Specific Configuration

### ESX Configuration

```lua
override.framework = 'esx'
override.frameworkname = 'es_extended'
override.frameworkevent = 'esx:getSharedObject'
override.frameworkprefix = 'esx'
```

### QBCore Configuration

```lua
override.framework = 'qb'
override.frameworkname = 'qb-core'
override.frameworkevent = 'QBCore:GetObject'
override.frameworkprefix = 'QBCore'
```

### QBox Configuration

```lua
override.framework = 'qbox'
override.frameworkname = 'qbx_core'
override.frameworkprefix = 'QBCore'
```

### OX Core Configuration

```lua
override.framework = 'ox'
override.frameworkname = 'ox_core'
override.frameworkprefix = 'ox'
```

## Inventory-Specific Configuration

### OX Inventory

```lua
override.inventory = 'ox_inventory'
override.inventoryname = 'ox_inventory'
override.imagepath = "ox_inventory/web/images/"
```

### QB-Inventory

```lua
override.inventory = 'qb-inventory'
override.inventoryname = 'qb-inventory'
override.imagepath = "qb-inventory/html/images/"
```

### QS-Inventory

```lua
override.inventory = 'qs-inventory'
override.inventoryname = 'qs-inventory'
override.imagepath = "qs-inventory/html/images/"
```

### Codem Inventory

```lua
override.inventory = 'qb-inventory'
override.inventoryname = 'codem-inventory'
override.imagepath = "codem-inventory/html/itemimages/"
```

### TGiann Inventory

```lua
override.inventory = 'tgiann-inventory'
override.inventoryname = 'tgiann-inventory'
override.imagepath = "inventory_images/images/"
```

## Target-Specific Configuration

### OX Target

```lua
override.target = 'ox_target'
override.targetname = 'ox_target'
```

### QB-Target

```lua
override.target = 'qb-target'
override.targetname = 'qb-target'
```

## Locale Configuration

Set the locale for bridge messages:

```lua
override.locale = 'en'  -- English
override.locale = 'tr'  -- Turkish
override.locale = 'de'  -- German
override.locale = 'fr'  -- French
```

## Environment Variables

You can also use convars for some configuration:

```cfg
# In server.cfg
set bridge:debug "true"   # Enable debug mode
set bridge:locale "en"    # Set locale
```

## Custom Resource Names

If you're using renamed versions of supported resources:

```lua
-- For a renamed ESX resource
override.framework = 'esx'
override.frameworkname = 'my_custom_esx'
override.frameworkevent = 'esx:getSharedObject'

-- For a renamed inventory
override.inventory = 'ox_inventory'
override.inventoryname = 'my_custom_inventory'
override.imagepath = "my_custom_inventory/web/images/"
```

## Validation

After configuration, check your server console for:

1. No error messages during bridge initialization
2. Correct detection messages for your chosen resources
3. Debug output (if enabled) showing proper configuration

## Common Configuration Issues

### Multiple Resources Conflict

If you have multiple versions of the same type of resource, the bridge will detect the first one it finds. Use overrides to specify which one to use.

### Custom Framework Integration

For completely custom frameworks not listed, you'll need to create custom bridge files or contact the bridge developers for support.