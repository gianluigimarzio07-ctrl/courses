fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_ambiente'
author      'AUREA · Italia Roleplay'
description 'Meteo stagionale italiano, tempo sincronizzato, festività ed eventi dinamici'
version     '1.0.0'

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies { 'aurea_core', 'aurea_ui' }
