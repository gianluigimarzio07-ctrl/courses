fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_inventory'
author      'AUREA · Italia Roleplay'
description 'Inventario a slot con peso, metadata per istanza, contenitori e oggetti a terra'
version     '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/stile.css',
    'html/app.js',
}

client_scripts { 'client/main.lua' }

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/contenitore.lua',
    'server/main.lua',
    'server/usa.lua',
}

dependencies { 'aurea_core', 'aurea_ui' }
