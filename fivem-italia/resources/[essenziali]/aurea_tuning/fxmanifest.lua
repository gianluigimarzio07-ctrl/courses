fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_tuning'
author      'AUREA · Italia Roleplay'
description 'Elaborazione dei veicoli, omologazione delle modifiche e nulla osta della Motorizzazione'
version     '1.0.0'

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies {
    'aurea_core',
    'aurea_ui',
    'ita_veicoli',
    'ita_codicestrada',
    'ita_fisco',
}
