fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_emote'
author      'AUREA · Italia Roleplay'
description 'Animazioni, emote con oggetti, andature e azioni condivise'
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
}
