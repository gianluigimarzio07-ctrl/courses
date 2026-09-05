fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_ristorazione'
author      'AUREA · Italia Roleplay'
description 'Bar e pizzeria: comande, cucina, servizio al tavolo e piatti che nutrono di più'
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
    'aurea_target',
    'aurea_inventory',
    'ita_fisco',
}
