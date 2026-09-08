fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_vigilfuoco'
author      'AUREA · Italia Roleplay'
description 'Vigili del Fuoco: incendi che si propagano, acqua che finisce, estricazione, CPI'
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
    'aurea_target',
    'ita_112',
}
