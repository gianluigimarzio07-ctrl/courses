fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_metriche'
author      'AUREA · Italia Roleplay'
description 'Metriche del server: presenze, massa monetaria, erario e allarmi di inflazione'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies {
    'aurea_core',
    'aurea_ui',
}
