fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_antiriciclaggio'
author      'AUREA · Italia Roleplay'
description 'D.Lgs. 231/2007: adeguata verifica, frazionamento su finestra mobile, segnalazioni, congelamento delle somme'
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
    'aurea_banca',
    'ita_giustizia',
    'ita_fisco',
}
