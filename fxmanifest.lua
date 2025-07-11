fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'zrx_tebex'
author 'zRxnx'
version '1.0.0'
description 'Advanced tebex system'
repository 'https://github.com/zrxnx/zrx_tebex'

dependencies {
    '/server:6116',
    '/onesync',
	'ox_lib',
    'oxmysql'
}

shared_scripts {
    '@ox_lib/init.lua',
    'utils.lua',
    'configuration/*.lua',
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

ui_page 'html/index.html'

files {
  'html/index.html',
}