fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_negozi'
author      'AUREA · Italia Roleplay'
description 'Negozi, bar, farmacie e mercati con prezzi dinamici e scontrino fiscale'
version     '1.0.0'

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies { 'aurea_core', 'aurea_ui', 'aurea_inventory' }
