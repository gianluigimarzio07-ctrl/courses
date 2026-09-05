fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_admin'
author      'AUREA · Italia Roleplay'
description 'Strumenti di staff: sanzioni, segnalazioni, modalità servizio, gestione giocatori'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
}

client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies {
    'aurea_core',
    'aurea_ui',
}
