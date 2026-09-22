fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_forestale'
author      'AUREA · Italia Roleplay'
description 'Carabinieri Forestali: rilievo delle superfici percorse dal fuoco, vincolo decennale, vigilanza venatoria e ambientale'
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
    'aurea_target',
    'aurea_inventory',
    'ita_codicestrada',
    'ita_giustizia',
    'ita_attivita',
    'ita_vigilfuoco',
}
