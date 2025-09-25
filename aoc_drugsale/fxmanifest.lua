shared_script "@ReaperV4/imports/bypass.lua"
shared_script "@ReaperV4/imports/bypass_s.lua"
shared_script "@ReaperV4/imports/bypass_c.lua"
lua54 "yes" -- needed for Reaper

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
server_script {
      '@oxmysql/lib/MySQL.lua',
      'server.lua'
}


files {
    'data/reputation.json',
    'data/sessions.json'
}
