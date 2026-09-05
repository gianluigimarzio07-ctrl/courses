fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_interazioni'
author      'AUREA · Italia Roleplay'
description 'Menu unico delle interazioni fra persone: manette, accompagnamento, consenso'
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
    'aurea_emote',
    'aurea_inventory',
}
