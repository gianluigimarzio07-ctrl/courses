fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_palestra'
author      'AUREA · Italia Roleplay'
description 'Palestra: forza e resistenza che si allenano, si sentono in gioco e si perdono'
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
    'ita_fisco',
}
