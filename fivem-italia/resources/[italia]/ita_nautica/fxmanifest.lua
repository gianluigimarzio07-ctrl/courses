fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_nautica'
author      'AUREA · Italia Roleplay'
description 'Nautica da diporto: patente, dotazioni, ormeggi, controlli e soccorso in mare'
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
    'ita_codicestrada',
    'ita_112',
}
