fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_ferrovie'
author      'AUREA · Italia Roleplay'
description 'Linee regionali con orario e ritardo, biglietti da obliterare, capotreno, passaggi a livello'
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
    'aurea_azienda',
    'ita_codicestrada',
    'ita_fisco',
}
