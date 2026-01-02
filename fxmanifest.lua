fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'

game 'gta5'

author 'Dusa'
version '0.8.2'
description 'Dusa Bridge'

shared_scripts {
    '@ox_lib/init.lua',
    -- Telemetry shared (loaded before server/client)
    'telemetry/shared/constants.lua',
    'telemetry/shared/config.lua',
    'telemetry/shared/breadcrumb.lua',
}

ui_page 'web/index.html'

server_scripts {
    -- Telemetry server modules
    'telemetry/server/context.lua',
    'telemetry/server/sentry.lua',
    'telemetry/server/capture.lua',
    'telemetry/server/trace_integration.lua',
    'telemetry/server/degradation.lua',
    'telemetry/server/init.lua',
}

client_scripts {
    'interaction/init.lua',
    -- 'interaction/client/**/*.lua',
    'interaction/client/*.lua',
    -- Telemetry client modules
    'telemetry/client/capture.lua',
    'telemetry/client/nui_bridge.lua',
    'telemetry/client/init.lua',
    -- TextUI module (exports)
    'textui/client.lua',
}

files {
    '**/**/client.lua',
    '**/*.lua',
    'interaction/**',
    'interaction/web/*.*',
    'interaction/web/js/*.*',
    -- Telemetry shared modules (for LoadResourceFile)
    'telemetry/shared/constants.lua',
    'telemetry/shared/config.lua',
    'telemetry/shared/breadcrumb.lua',
    -- Telemetry server modules
    'telemetry/server/context.lua',
    'telemetry/server/sentry.lua',
    'telemetry/server/capture.lua',
    'telemetry/server/trace_integration.lua',
    'telemetry/server/degradation.lua',
    -- Telemetry client modules
    'telemetry/client/capture.lua',
    'telemetry/client/nui_bridge.lua',
    'telemetry/nui/*.ts',
    -- TextUI module
    'textui/client.lua',
    -- TextUI NUI
    'web/index.html',
    -- 'interaction/client/*.lua',
    -- 'interaction/client/modules/*.lua',
}

escrow_ignore {
    'bridge.lua',
    'override.lua',
    '**/*.lua',
}

dependency '/assetpacks'
dependency '/assetpacks'
dependency '/assetpacks'