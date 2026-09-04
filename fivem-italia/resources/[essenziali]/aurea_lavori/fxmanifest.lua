fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_lavori'
author      'AUREA · Italia Roleplay'
description 'Centro per l Impiego, turni, missioni di lavoro e officina'
version     '1.0.0'

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua', 'client/missioni.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies { 'aurea_core', 'aurea_ui' }
