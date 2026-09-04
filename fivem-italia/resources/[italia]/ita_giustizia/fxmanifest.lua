fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_giustizia'
author      'AUREA · Italia Roleplay'
description 'Casellario giudiziale, fermo, arresto, detenzione, tribunale e difesa legale'
version     '1.0.0'

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua', 'client/carcere.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua', 'server/detenzione.lua' }

dependencies { 'aurea_core', 'aurea_ui' }
