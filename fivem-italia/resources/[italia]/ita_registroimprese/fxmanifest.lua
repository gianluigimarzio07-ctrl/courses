fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_registroimprese'
author      'AUREA · Italia Roleplay'
description 'Camera di Commercio: iscrizione al Registro Imprese, numero REA, visura camerale, compagine sociale, diritto annuale'
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
    'ita_fisco',
}
