fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_core'
author      'AUREA · Italia Roleplay'
description 'Framework di base: personaggi, denaro, lavori, permessi, callback, item'
version     '1.0.0'

shared_scripts {
    'shared/config.lua',
    'shared/utils.lua',
    'shared/item.lua',
    'shared/lavori.lua',
    'shared/reati.lua',
}

client_scripts {
    'client/callback.lua',
    'client/main.lua',
    'client/stato.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/callback.lua',
    'server/anagrafe.lua',
    'server/giocatore.lua',
    'server/main.lua',
    'server/denaro.lua',
    'server/comandi.lua',
}

dependencies {
    'oxmysql',
}

provide 'aurea'
