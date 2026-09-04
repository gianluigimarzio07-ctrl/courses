fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_aspetto'
author      'AUREA · Italia Roleplay'
description 'Creazione del personaggio, abbigliamento, barbiere, tatuatore e armadio'
version     '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/stile.css',
    'html/app.js',
}

shared_scripts { 'config.lua' }
client_scripts { 'client/aspetto.lua', 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies {
    'aurea_core',
    'aurea_ui',
}
