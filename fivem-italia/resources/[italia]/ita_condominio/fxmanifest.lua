fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_condominio'
author      'AUREA · Italia Roleplay'
description 'Condominio: tabella millesimale dalla rendita catastale, assemblea, spese, decreto ingiuntivo, decoro del palazzo'
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
    'aurea_case',
    'ita_catasto',
}
