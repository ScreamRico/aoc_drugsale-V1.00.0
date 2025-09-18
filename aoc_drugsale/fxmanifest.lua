fx_version 'cerulean'
game 'gta5'

author 'AOCDEV'
description 'Drug Sale Script with NPC Logic, ox_lib v2.44.5'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/shared.lua',
    'locales/en.lua'
}

client_script 'client.lua'
server_script 'server.lua'

files {
    'data/reputation.json',
    'data/sessions.json'
}
