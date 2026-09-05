fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'lav_elettricista'
author      'AUREA · Italia Roleplay'
description 'Manutenzione della rete elettrica: guasti veri che lasciano al buio una zona'
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
