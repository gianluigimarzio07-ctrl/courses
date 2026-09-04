fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_economia'
author      'AUREA · Italia Roleplay'
description 'Motore economico: domanda e offerta, indice dei prezzi, inflazione, listino'
version     '1.0.0'

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies { 'aurea_core', 'aurea_ui' }
