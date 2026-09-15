fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_asl'
author      'AUREA · Italia Roleplay'
description 'Igiene degli esercizi, piano HACCP, ispezioni, tossinfezioni e sospensione dell\'attività'
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
    'aurea_azienda',
    'ita_ristorazione',
    'ita_fisco',
    'ita_112',
}
