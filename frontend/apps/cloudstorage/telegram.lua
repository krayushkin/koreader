local BD = require("ui/bidi")
local ConfirmBox = require("ui/widget/confirmbox")
local DocumentRegistry = require("document/documentregistry")
local TelegramApi = require("apps/cloudstorage/telegram-bot-lua/core")
local InfoMessage = require("ui/widget/infomessage")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local UIManager = require("ui/uimanager")
local ReaderUI = require("apps/reader/readerui")
local util = require("util")
local T = require("ffi/util").template
local _ = require("gettext")

local Telegram = {}





local function getCurrentOffset()
    TelegramApi.currentOffset = (TelegramApi.currentOffset or -1) + 1
    return TelegramApi.currentOffset
end

function Telegram:run(password)
    TelegramApi.token = password
    local success = TelegramApi.get_updates(1, TelegramApi.getCurrentOffset(), 100, {"message", "document"})

    if type(success) == "table" and success.result then
        local updates = success.result
        print(string.format("Size = %d", #updates))
    end
    
    return {
             {text = "BookWithoutSpaces", type = "file", url = "/usr/book1"}, 
             {text = "First book.mobi", type = "file", url = "/usr/book2"},
             {text = "My favorite book.epub", type = "file", url = "/usr/book3"},
             {text = "Folder with spaces", type = "folder", url = "/usr/book4"},
     }
end

function Telegram:downloadFile(item, password, path, callback_close)
    local code_response = TelegramApi:downloadFile(item.url, password, path)
    if code_response == 200 then
            UIManager:show(InfoMessage:new{
                text = T(_("File saved!\n")),
            })
    else
        UIManager:show(InfoMessage:new{
            text = T(_("Could not save file.\n")),
            timeout = 3,
        })
    end
end

function Telegram:downloadFileNoUI(url, password, path)
    local code_response = TelegramApi:downloadFile(url, password, path)
    return code_response == 200
end


function Telegram:config(item, callback)
    local text_info = _([[
For using this functionality you must first create bot in Telegram client application using @BotFather.
Supply provided token in token field. Send books to this device just post to bot
book file or http/https link. Select books from list and download it (max size <= 20 MB).]])
    local text_name, text_token, text_appkey, text_url
    if item then
        text_name = item.text
        text_token = item.password
    end
    self.settings_dialog = MultiInputDialog:new {
        title = _("Telegram bot file transfer"),
        fields = {
            {
                text = text_name,
                hint = _("Telegram bot name"),
            },
            {
                text = text_token,
                hint = _("Telegram bot token"),
            },
        },
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        self.settings_dialog:onClose()
                        UIManager:close(self.settings_dialog)
                    end
                },
                {
                    text = _("Info"),
                    callback = function()
                        UIManager:show(InfoMessage:new{ text = text_info })
                    end
                },
                {
                    text = _("Save"),
                    callback = function()
                        local fields = self.settings_dialog:getFields()
                        if item then
                            callback(item, fields)
                        else
                            callback(fields)
                        end
                        self.settings_dialog:onClose()
                        UIManager:close(self.settings_dialog)
                    end
                },
            },
        },
    }
    UIManager:show(self.settings_dialog)
    self.settings_dialog:onShowKeyboard()
end

function Telegram:info(token)
        UIManager:show(InfoMessage:new{
            text = T(_"Nothing to say here"),
        })
end

return Telegram
