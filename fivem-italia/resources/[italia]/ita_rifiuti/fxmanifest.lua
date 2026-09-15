fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_rifiuti'
author      'AUREA · Italia Roleplay'
description 'Rifiuti speciali, registro di carico e scarico, formulario, discariche abusive, art. 256 e 452-quaterdecies'
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
    'ita_giustizia',
    'ita_famiglie',
    'ita_fisco',
}
