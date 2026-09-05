fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_soccorso'
author      'AUREA · Italia Roleplay'
description 'Soccorso stradale: chiamate, traino su pianale, interventi sul posto, rimozione forzata'
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
    'aurea_inventory',
    'ita_veicoli',
    'ita_fisco',
}
