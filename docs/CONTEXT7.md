# CONTEXT7 Integration Guide

This document provides optimal formatting and structure for CONTEXT7 AI system integration.

## Project Context

**Project Name**: Dusa Bridge
**Type**: FiveM Multi-Framework Compatibility Layer
**Version**: 0.7.8-release
**Language**: Lua (FiveM/CitizenFX)
**Architecture**: Modular Bridge System

## Code Structure for CONTEXT7

### Primary Files
- `bridge.lua` - Core initialization and detection logic
- `fxmanifest.lua` - Resource manifest with dependencies
- `override.lua` - Configuration override system

### Module Organization
```
framework/[system]/[client|server].lua - Framework adapters
inventory/[system]/[client|server].lua - Inventory system bridges
target/[system]/[client|server].lua - Target system integrations
zone/[system]/[client|server].lua - Zone management systems
```

### Shared Components
```
shared/cache.lua - Caching system
shared/locale.lua - Localization system
shared/loader.lua - Module loading system
utils/[client|server|shared].lua - Utility functions
```

## Key Concepts for AI Understanding

### Bridge Pattern Implementation
The system uses the Bridge design pattern to decouple framework-specific implementations from the unified API. Each supported system (framework, inventory, etc.) has its own adapter that translates between the bridge API and the native system API.

### Auto-Detection Algorithm
```lua
-- Detection priority order:
1. Manual override configuration
2. Resource state checking
3. Metadata extraction
4. Fallback defaults
```

### Modular Architecture
Each module can be independently enabled/disabled using the `bridge_disable` metadata tag in resource manifests.

### Unified API Design
All bridge functions follow consistent naming patterns:
- `Framework.GetPlayer()` - Works across ESX, QBCore, QBox, etc.
- `Inventory.AddItem()` - Works across all supported inventory systems
- `Target.AddBoxZone()` - Works across all target systems

## Framework Mapping

### ESX Framework
```lua
Bridge.Framework = 'esx'
Bridge.FrameworkName = 'es_extended'
Bridge.FrameworkEvent = 'esx:getSharedObject'
Bridge.FrameworkPrefix = 'esx'
```

### QBCore/QBox Framework
```lua
Bridge.Framework = 'qb' | 'qbox'
Bridge.FrameworkName = 'qb-core' | 'qbx_core'
Bridge.FrameworkEvent = 'QBCore:GetObject' | nil
Bridge.FrameworkPrefix = 'QBCore'
```

## State Management

### Bridge State Variables
```lua
Bridge.Resource - Current resource name
Bridge.Name - Bridge resource name
Bridge.Version - Bridge version
Bridge.Context - 'client' | 'server'
Bridge.DebugMode - Debug flag
Bridge.Locale - Language setting
Bridge.Disabled - Disabled modules table
```

### System Detection States
```lua
Bridge.[System] - Detected system type
Bridge.[System]Name - Resource name
Bridge.[System]Event - Event name (if applicable)
Bridge.[System]Prefix - API prefix (if applicable)
```

## Error Handling Patterns

### Detection Errors
All detection failures result in error messages and resource termination to prevent undefined behavior.

### Runtime Errors
Bridge provides graceful fallbacks and error logging for runtime failures.

### Validation Errors
Input parameters are validated before passing to underlying systems.

## Performance Characteristics

### Initialization
- Synchronous detection phase
- Asynchronous module loading
- Lazy loading of optional components

### Runtime
- Minimal overhead wrapper functions
- Direct system API calls where possible
- Caching for frequently accessed data

### Memory Usage
- Small footprint per player
- Shared system instances
- Automatic cleanup on disconnect

## Integration Patterns

### Resource Integration
1. Add `bridge 'dusa_bridge'` to manifest
2. Use bridge APIs instead of framework-specific APIs
3. Handle bridge events for cross-framework compatibility

### Framework Detection
```lua
if Bridge.Framework == 'esx' then
    -- ESX-specific implementation
elseif Bridge.Framework == 'qb' then
    -- QBCore-specific implementation
end
```

### Callback Pattern
```lua
Framework.RegisterCallback('name', serverFunction)
Framework.TriggerCallback('name', clientCallback, args)
```

## Configuration System

### Override Precedence
1. override.lua settings (highest priority)
2. Resource metadata
3. Automatic detection (lowest priority)

### Module Control
```lua
-- In fxmanifest.lua
bridge_disable 'framework'
bridge_disable 'inventory'
bridge_disable 'target'
```

### Debug Configuration
```lua
-- In override.lua
override.debug = true
```


## Event System

### Cross-Framework Events
Bridge normalizes event names and parameters across different frameworks.

### Custom Events
Bridge provides its own event system for bridge-specific functionality.

### Hook System (Server)
```lua
Hook.Register('eventName', callbackFunction)
Hook.Trigger('eventName', data)
```

## Best Practices for CONTEXT7

### Code Analysis
- Focus on the bridge pattern implementation
- Understand auto-detection algorithms
- Recognize unified API design patterns
- Identify framework-specific adapters

### Troubleshooting
- Check detection logs first
- Verify override configurations
- Test individual module functionality
- Use debug mode for detailed logging

### Development
- Always use bridge APIs for compatibility
- Implement proper error handling
- Test across multiple framework configurations
- Follow bridge naming conventions

## Common Issues for AI Assistance

### Detection Problems
- Framework not starting before bridge
- Custom resource names not matching detection patterns
- Missing dependencies (ox_lib)

### Configuration Issues
- Incorrect override syntax
- Module conflicts
- Version incompatibilities

### Runtime Problems
- API misuse across different frameworks
- Event handling inconsistencies
- Database connection issues

This guide provides CONTEXT7 with the essential understanding needed to effectively analyze, debug, and enhance the Dusa Bridge system.