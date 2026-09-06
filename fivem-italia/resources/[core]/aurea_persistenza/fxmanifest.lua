fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_persistenza'
author      'AUREA · Italia Roleplay'
description 'I veicoli lasciati in strada restano dove sono, anche dopo un riavvio'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies {
    'aurea_core',
}
