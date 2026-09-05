fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_caricamento'
author      'AUREA · Italia Roleplay'
description 'Schermata di caricamento con i consigli che spiegano come si gioca qui'
version     '1.0.0'

loadscreen 'html/index.html'
loadscreen_manual_shutdown 'yes'

files {
    'html/index.html',
    'html/stile.css',
    'html/app.js',
}

client_scripts { 'client/main.lua' }
