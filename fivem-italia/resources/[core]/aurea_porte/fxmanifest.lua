fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_porte'
author      'AUREA · Italia Roleplay'
description 'Serrature: chi apre cosa lo decide il server, e il grimaldello è un rischio'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}
client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }

dependencies {
    'aurea_core',
    'aurea_ui',
    'aurea_inventory',
    'ita_giustizia',
    'ita_112',
}
