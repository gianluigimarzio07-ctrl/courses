fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_bische'
author      'AUREA · Italia Roleplay'
description 'Sette e mezzo clandestino, banco di tasca propria, soffiate e irruzioni, art. 718 e 720 c.p.'
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
    'ita_112',
}
