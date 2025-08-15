fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'

game 'gta5'

author 'Dusa'
version '0.7.7-test'
description 'Dusa Bridge'

shared_script 'override.lua'
shared_script {
    '@ox_lib/init.lua',
}

-- ui_page 'interaction/web/index.html'

client_scripts {
    'interaction/init.lua',
    -- 'interaction/client/**/*.lua',
    'interaction/client/*.lua',
}

files {
    '**/**/client.lua',
    '**/*.lua',
    'interaction/**',
    'interaction/web/*.*',
    'interaction/web/js/*.*',
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