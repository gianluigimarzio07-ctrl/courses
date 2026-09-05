fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_cayo'
author      'AUREA · Italia Roleplay'
description 'Punta Corvo: ricognizione, infiltrazione e colpo alla villa del latitante'
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
    'aurea_inventory',
    'ita_giustizia',
    'ita_famiglie',
    'ita_112',
}
