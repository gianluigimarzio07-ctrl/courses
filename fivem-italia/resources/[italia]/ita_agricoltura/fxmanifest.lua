fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_agricoltura'
author      'AUREA · Italia Roleplay'
description 'Poderi, colture a stagione, fertilità del suolo, contributi PAC e controlli in loco'
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
    'ita_ambiente',
    'ita_fisco',
    'ita_giustizia',
}
