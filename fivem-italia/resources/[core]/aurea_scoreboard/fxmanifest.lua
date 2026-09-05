fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_scoreboard'
author      'AUREA · Italia Roleplay'
description 'Elenco dei collegati con enti in servizio e stato del server'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
}

client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }

dependencies {
    'aurea_core',
    'aurea_ui',
}
