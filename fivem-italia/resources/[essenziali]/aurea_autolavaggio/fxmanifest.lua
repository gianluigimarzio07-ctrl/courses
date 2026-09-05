fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_autolavaggio'
author      'AUREA · Italia Roleplay'
description 'Autolavaggio: lo sporco si accumula guidando e si toglie pagando'
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
    'ita_fisco',
}
