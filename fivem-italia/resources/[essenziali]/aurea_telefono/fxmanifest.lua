fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_telefono'
author      'AUREA · Italia Roleplay'
description 'Telefono unico: un registro di app che ogni risorsa riempie da sé'
version     '2.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/stile.css',
    'html/app.js',
}

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}

client_scripts { 'client/main.lua' }

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/registro.lua',
    'server/chiamate.lua',
    'server/main.lua',
}

dependencies {
    'aurea_core',
    'aurea_ui',
    'aurea_inventory',
    'aurea_voce',
    'aurea_banca',
    'ita_codicestrada',
    'ita_fisco',
}
