fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_illegale'
author      'AUREA · Italia Roleplay'
description 'Mercato nero: attrezzatura, precursori e armi senza matricola'
version     '2.0.0'

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
    'aurea_armi',
    'ita_famiglie',
}
