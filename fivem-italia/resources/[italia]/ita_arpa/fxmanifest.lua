fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_arpa'
author      'AUREA · Italia Roleplay'
description 'Campionamenti ambientali su emissioni, scarichi, rumore, amianto e suolo, con prescrizioni a termine'
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
    'aurea_musica',
    'ita_rifiuti',
    'ita_giustizia',
    'ita_fisco',
}
