fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_codicestrada'
author      'AUREA · Italia Roleplay'
description 'Autovelox, tutor, varchi ZTL, patente a punti, verbali e ruolo esattoriale'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}

client_scripts {
    'client/rilevatori.lua',
    'client/ztl.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/patente.lua',
    'server/verbali.lua',
    'server/main.lua',
}

dependencies {
    'aurea_core',
    'aurea_ui',
}
