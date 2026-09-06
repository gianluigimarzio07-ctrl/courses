fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_backup'
author      'AUREA · Italia Roleplay'
description 'Istantanee periodiche dei dati che contano, con rotazione e consultazione'
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
}
