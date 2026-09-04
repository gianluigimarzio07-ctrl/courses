fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_spawn'
author      'AUREA · Italia Roleplay'
description 'Selezione e creazione personaggio con anagrafe italiana'
version     '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/stile.css',
    'html/app.js',
}

client_scripts { 'client/main.lua' }

dependencies {
    'aurea_core',
    'aurea_ui',
}
