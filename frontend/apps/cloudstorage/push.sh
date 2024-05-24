#!/usr/bin/bash


cp cloudstorage.lua /usr/lib/koreader/frontend/apps/cloudstorage/cloudstorage.lua
cp telegram.lua /usr/lib/koreader/frontend/apps/cloudstorage/telegram.lua
mkdir -p /usr/lib/koreader/frontend/apps/cloudstorage/telegram-bot-lua
cp telegram-bot-lua/* /usr/lib/koreader/frontend/apps/cloudstorage/telegram-bot-lua/


