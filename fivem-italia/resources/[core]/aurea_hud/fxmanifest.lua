fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_hud'
author      'AUREA · Italia Roleplay'
description 'HUD: bisogni, denaro, tachimetro con limiti di velocità, patente a punti, ZTL'
version     '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/stile.css',
    'html/app.js',
}

client_scripts {
    'client/main.lua',
}

dependencies {
    'aurea_core',
    'aurea_ui',
}
