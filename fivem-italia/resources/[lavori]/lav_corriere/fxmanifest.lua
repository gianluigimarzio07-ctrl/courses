fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'lav_corriere'
author      'AUREA · Italia Roleplay'
description 'Consegne a domicilio su indirizzi veri, con bonus se il destinatario ritira di persona'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies {
    'aurea_core',
    'aurea_ui',
    'aurea_target',
}
