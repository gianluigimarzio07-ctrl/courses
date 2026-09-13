fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_edilizia'
author      'AUREA · Italia Roleplay'
description 'Cantieri, permesso a costruire, DURC, DPI e sicurezza sul lavoro (D.Lgs. 81/2008)'
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
    'aurea_azienda',
    'ita_fisco',
    'ita_comune',
    'ita_112',
    'ita_previdenza',
}
