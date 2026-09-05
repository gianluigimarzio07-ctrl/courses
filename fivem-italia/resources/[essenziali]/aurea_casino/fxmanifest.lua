fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_casino'
author      'AUREA · Italia Roleplay'
description 'Casinò: blackjack, roulette europea e slot, con margine del banco e imposta sulle vincite'
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
    'aurea_target',
    'aurea_inventory',
    'ita_fisco',
}
