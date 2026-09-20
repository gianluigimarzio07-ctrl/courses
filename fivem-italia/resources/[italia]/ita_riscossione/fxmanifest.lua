fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_riscossione'
author      'AUREA · Italia Roleplay'
description 'Agente della riscossione: ruoli, rateizzazione, fermo amministrativo, pignoramento presso terzi'
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
    'aurea_azienda',
    'ita_fisco',
    'ita_codicestrada',
    'ita_veicoli',
}
