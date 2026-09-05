fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'lav_camionista'
author      'AUREA · Italia Roleplay'
description 'Trasporto merci su lunga distanza: il carico si rovina se guidi male'
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
