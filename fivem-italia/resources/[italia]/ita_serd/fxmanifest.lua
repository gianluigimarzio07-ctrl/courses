fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_serd'
author      'AUREA · Italia Roleplay'
description 'Art. 75 D.P.R. 309/1990: segnalazione al Prefetto per uso personale, programma terapeutico, archiviazione'
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
    'ita_droga',
    'ita_codicestrada',
    'ita_fisco',
}
