# Dusa Bridge Documentation

## Overview

Dusa Bridge is a comprehensive compatibility layer for FiveM resources that provides seamless integration across multiple frameworks, inventory systems, target systems, and zone managers. It automatically detects and bridges differences between various popular FiveM resources.

## Version
Current Version: **0.7.8-release**

## Features

- **Multi-Framework Support**: ESX, QBCore, QBox, OX Core, vRP, NDCore
- **Multi-Inventory Support**: OX Inventory, QB-Inventory variants, QS-Inventory, Core Inventory, TGiann Inventory
- **Target System Integration**: OX Target, QB-Target, QTarget, Meta Target
- **Zone Management**: OX Lib zones, PolyZone
- **Menu System Integration**: OX Lib menus, QB-Menu
- **Automatic Detection**: Automatically detects and configures supported resources
- **Override System**: Manual configuration options for custom setups
- **Debug Mode**: Comprehensive logging and debugging capabilities
- **Modular Architecture**: Enable/disable specific modules as needed

## Quick Start

1. Ensure your framework, inventory, and target resources are started before dusa_bridge
2. Add `ensure dusa_bridge` to your server.cfg
3. Configure overrides in `override.lua` if needed
4. Use Bridge exports in your resources

## Documentation Structure

- [Installation Guide](installation.md)
- [Configuration](configuration.md)
- [Framework Integration](framework-integration.md)
- [Inventory Systems](inventory-systems.md)
- [Target Systems](target-systems.md)
- [Zone Management](zone-management.md)
- [API Reference](api-reference.md)
- [Examples](examples.md)
- [Troubleshooting](troubleshooting.md)

## Supported Resources

### Frameworks
- ESX (es_extended)
- QBCore (qb-core)
- QBox (qbx_core)
- OX Core (ox_core)
- vRP (vrp)
- NDCore (ND_Core)

### Inventory Systems
- OX Inventory (ox_inventory)
- QB-Inventory (qb-inventory)
- LJ-Inventory (lj-inventory)
- AJ-Inventory (aj-inventory)
- AX-Inventory (ax-inventory)
- PS-Inventory (ps-inventory)
- AK47 Inventory (ak47_inventory)
- Codem Inventory (codem-inventory)
- L2S Inventory (l2s-inventory)
- QS-Inventory (qs-inventory)
- TGiann Inventory (tgiann-inventory)
- Core Inventory (core_inventory)

### Target Systems
- OX Target (ox_target)
- QB-Target (qb-target)
- QTarget (qtarget)
- Meta Target (meta_target)

### Zone Systems
- OX Lib (ox_lib)
- PolyZone (PolyZone)

### Databases
- OXMySQL (oxmysql)

## License

This resource is provided as-is. Check the resource manifest for licensing information.