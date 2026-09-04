fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_medico'
author      'AUREA · Italia Roleplay'
description 'Sistema sanitario: ferite localizzate, emorragie, incoscienza, 118 e ospedale'
version     '1.0.0'

shared_scripts { 'config.lua' }
client_scripts { 'client/ferite.lua', 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies {
    'aurea_core',
    'aurea_ui',
    'aurea_inventory',
    'ita_fisco',
}
