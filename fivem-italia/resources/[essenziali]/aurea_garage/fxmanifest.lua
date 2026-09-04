fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_garage'
author      'AUREA · Italia Roleplay'
description 'Garage pubblici e privati, ricovero veicoli, carburante e usura'
version     '1.0.0'

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua', 'client/carburante.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies { 'aurea_core', 'aurea_ui', 'ita_veicoli' }
