fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_protezionecivile'
author      'AUREA · Italia Roleplay'
description 'Allertamento, COC, volontari del gruppo comunale e scenari di emergenza'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}
client_scripts { 'client/main.lua' }
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'aurea_core',
    'aurea_ui',
    'aurea_target',
    'aurea_inventory',
    'ita_ambiente',
    'ita_112',
    'ita_vigilfuoco',
}
