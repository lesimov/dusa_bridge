fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'

game 'gta5'

author 'Dusa'
version '0.7.3'
description 'Dusa Bridge'

shared_script 'override.lua'
shared_script {
    '@ox_lib/init.lua',
}

files {
    '**/**/client.lua',
    '**/*.lua',
}

escrow_ignore {
    'bridge.lua',
    'override.lua',
    '**/*.lua',
}

dependency '/assetpacks'
dependency '/assetpacks'
dependency '/assetpacks'