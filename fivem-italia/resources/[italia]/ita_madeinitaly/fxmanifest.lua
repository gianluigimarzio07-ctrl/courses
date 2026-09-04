fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_madeinitaly'
author      'AUREA · Italia Roleplay'
description 'Filiere produttive italiane: vino, olio, formaggio, caffè, pizza, sartoria'
version     '1.0.0'

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies { 'aurea_core', 'aurea_ui', 'aurea_inventory' }
