fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_autostrade'
author      'AUREA · Italia Roleplay'
description 'Caselli, pedaggio sulla distanza, Telepass, art. 176 CdS e insoluti messi a ruolo'
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
    'ita_veicoli',
    'ita_codicestrada',
    'ita_riscossione',
}
