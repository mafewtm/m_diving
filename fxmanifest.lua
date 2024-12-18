fx_version 'cerulean'
game 'gta5'

author 'mafewtm'
name 'm_diving'
description 'Just another diving resource'
repository 'https://github.com/mafewtm/m_diving'
version '1.0.0'

ox_lib 'locale'

shared_script '@ox_lib/init.lua'

client_script 'client/*.lua'

server_script 'server/*.lua'

files {
    'config/client.lua',
    'config/shared.lua',
    'locales/*.json'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'