fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_musica'
author      'AUREA · Italia Roleplay'
description 'Stereo portatili e autoradio sincronizzati: si sentono da dove sei'
version     '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
}

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
    'ita_112',
}
