fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_telefono'
author      'AUREA · Italia Roleplay'
description 'Smartphone: contatti, SMS, SPID, banca, annunci, 112, fisco'
version     '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/stile.css',
    'html/app.js',
}

client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies { 'aurea_core', 'aurea_ui' }
