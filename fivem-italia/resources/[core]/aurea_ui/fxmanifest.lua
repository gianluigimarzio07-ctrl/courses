fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_ui'
author      'AUREA · Italia Roleplay'
description 'Toolkit di interfaccia: notifiche, menu, dialoghi, barre di avanzamento, prompt'
version     '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/stile.css',
    'html/app.js',
}

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'aurea_core',
}
