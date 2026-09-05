fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_fisco'
author      'AUREA · Italia Roleplay'
description 'Agenzia delle Entrate: partita IVA, imprese, fatturazione, IRPEF, IVA, cartelle'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}
client_scripts { 'client/main.lua' }
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/erario.lua',
    'server/imprese.lua',
    'server/main.lua',
}

dependencies {
    'aurea_core',
    'aurea_ui',
}
