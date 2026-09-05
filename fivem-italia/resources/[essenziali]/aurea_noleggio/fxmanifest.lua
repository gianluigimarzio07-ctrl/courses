fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_noleggio'
author      'AUREA · Italia Roleplay'
description 'Autonoleggio a ore con cauzione, penale per il ritardo e trattenuta sui danni'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}
client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }

dependencies {
    'aurea_core',
    'aurea_ui',
    'aurea_target',
    'ita_codicestrada',
    'ita_fisco',
}
