fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_logs'
author      'AUREA · Italia Roleplay'
description 'Recapito dei log su Discord con accodamento e limitazione di frequenza'
version     '1.0.0'

server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies {
    'aurea_core',
}
