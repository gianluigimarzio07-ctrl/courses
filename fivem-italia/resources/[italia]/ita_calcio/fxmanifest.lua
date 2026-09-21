fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_calcio'
author      'AUREA · Italia Roleplay'
description 'Campionato che gira da solo, tessera del tifoso, biglietti, tafferugli e DASPO allo stadio'
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
    'aurea_scommesse',
    'ita_questura',
    'ita_giustizia',
    'ita_fisco',
}
