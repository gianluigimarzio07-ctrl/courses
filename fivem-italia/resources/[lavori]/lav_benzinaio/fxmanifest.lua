fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'lav_benzinaio'
author      'AUREA · Italia Roleplay'
description 'Rifornimento dei distributori: i serbatoi si svuotano davvero e vanno riempiti'
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
    'aurea_target',
    'ita_fisco',
}
