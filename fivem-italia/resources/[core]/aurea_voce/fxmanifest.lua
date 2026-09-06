fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_voce'
author      'AUREA · Italia Roleplay'
description 'Portate della voce, radio a frequenze riservate, indicatore di chi parla'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}
client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }

dependencies {
    'aurea_core',
    'aurea_ui',
    'aurea_inventory',
}
