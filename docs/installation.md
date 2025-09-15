# Installation Guide

## Prerequisites

Before installing Dusa Bridge, ensure you have:

1. A FiveM server running
2. One of the supported frameworks installed and running
3. OX Lib installed (recommended for full functionality)

## Installation Steps

### 1. Download and Extract

1. Download the Dusa Bridge resource
2. Extract it to your server's `resources` folder
3. Rename the folder to `dusa_bridge` if needed

### 2. Server Configuration

Add the following to your `server.cfg`:

```cfg
# Framework (start before bridge)
ensure es_extended  # or your chosen framework

# Dependencies
ensure ox_lib

# Dusa Bridge (start after dependencies)
ensure dusa_bridge

# Your other resources (start after bridge)
ensure your_custom_resource
```

### 3. Resource Manifest

In your resource that uses Dusa Bridge, add to `fxmanifest.lua`:

```lua
fx_version 'cerulean'
game 'gta5'

-- Bridge dependency
dependency 'dusa_bridge'

-- Bridge metadata (required)
bridge 'dusa_bridge'

-- Bridge integration (required)
shared_scripts {
    '@dusa_bridge/bridge.lua'
}

-- Your resource files
client_scripts {
    'client/*.lua'
}

server_scripts {
    'server/*.lua'
}
```

### 4. Verify Installation

Check your server console for:

```
[BRIDGE] Version 0.7.8-release
[BRIDGE] Framework Detected: esx (or your framework)
[BRIDGE] Inventory Detected: ox_inventory (or your inventory)
[BRIDGE] Target Detected: ox_target (or your target)
```

## Common Installation Issues

### Bridge Not Found Error

**Error**: `Bridge Not Found, Bridge Tag Must Be Included In Resource Manifest`

**Solution**: Add `bridge 'dusa_bridge'` to your resource's `fxmanifest.lua`

### Lua Version Error

**Error**: `Lua 5.4 Must Be Enabled In The Resource Manifest`

**Solution**: Add `lua54 'yes'` to your resource's `fxmanifest.lua`

### Framework Not Found

**Error**: `No Compatible Framework Resource Found`

**Solutions**:
1. Ensure your framework is started before dusa_bridge in server.cfg
2. Check that your framework resource name matches supported names
3. Use override configuration if using custom framework names


## Post-Installation

1. Review the [Configuration Guide](configuration.md) for customization options
2. Check [Framework Integration](framework-integration.md) for framework-specific setup
3. Test basic functionality with the [Examples](examples.md)

## Updating

When updating Dusa Bridge:

1. Stop the server
2. Backup your `override.lua` file
3. Replace the dusa_bridge folder
4. Restore your `override.lua` configuration
5. Start the server and check console for any errors