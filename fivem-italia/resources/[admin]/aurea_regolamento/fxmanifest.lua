fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_regolamento'
author      'AUREA · Italia Roleplay'
description 'Regolamento consultabile in gioco e tutorial del primo accesso'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies {
    'aurea_core',
    'aurea_ui',
}
