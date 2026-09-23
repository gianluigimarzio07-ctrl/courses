fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_mercato'
author      'AUREA · Italia Roleplay'
description 'Mercato rionale: posteggi in concessione, banco presidiato con clienti che arrivano da soli, scontrino battuto o no, controllo dei corrispettivi'
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
    'ita_economia',
    'ita_fisco',
    'ita_madeinitaly',
}
