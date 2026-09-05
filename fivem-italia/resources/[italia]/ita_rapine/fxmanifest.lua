fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_rapine'
author      'AUREA · Italia Roleplay'
description 'Rapine a esercizi, gioiellerie, portavalori e istituti di credito'
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
}
