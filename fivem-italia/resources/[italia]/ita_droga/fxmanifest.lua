fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_droga'
author      'AUREA · Italia Roleplay'
description 'Stupefacenti: coltivazione, lavorazione, taglio, piazze di spaccio, narcotest'
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
    'aurea_medico',
    'ita_giustizia',
    'ita_famiglie',
    'ita_112',
}
