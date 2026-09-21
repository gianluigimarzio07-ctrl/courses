fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_caf'
author      'AUREA · Italia Roleplay'
description 'Dichiarazione dei redditi precompilata, scaglioni IRPEF, detrazioni, conguaglio e controllo formale'
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
    'aurea_azienda',
    'aurea_banca',
    'ita_fisco',
    'ita_previdenza',
    'ita_condominio',
}
