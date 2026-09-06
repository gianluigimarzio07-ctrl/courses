fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_carcere'
author      'AUREA · Italia Roleplay'
description 'Vita in istituto: peculio, sopravvitto, colloqui, isolamento, evasione'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}
client_scripts { 'client/main.lua' }
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'aurea_core',
    'aurea_ui',
    'aurea_inventory',
    'aurea_target',
    'ita_giustizia',
}
