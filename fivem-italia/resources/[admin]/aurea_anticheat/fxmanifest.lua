fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_anticheat'
author      'AUREA · Italia Roleplay'
description 'Protezioni server-side: eventi, entità, movimento, risorse'
version     '1.0.0'

client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies {
    'aurea_core',
    'aurea_admin',
}
