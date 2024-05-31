local BD = require("ui/bidi")
local ConfirmBox = require("ui/widget/confirmbox")
local DocumentRegistry = require("document/documentregistry")
local TelegramApi = require("apps/cloudstorage/telegram-bot-lua/core")
local InfoMessage = require("ui/widget/infomessage")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local UIManager = require("ui/uimanager")
local ReaderUI = require("apps/reader/readerui")
local util = require("util")
local socket = require("socket")
local socketutil = require("socketutil")
local http = require("socket.http")
local logger = require("logger")
local T = require("ffi/util").template
local _ = require("gettext")

local Telegram = {offset = 0}

local function concatTableKeys(t)
    local keys = {}
    for k,v in pairs(t) do
        table.insert(keys, k)
    end
    local keys_str = table.concat(keys, ", ")
    return keys_str
end

function Telegram:run(password)
    TelegramApi.token = password

    local limitNumberOfUpdates = 100
    local success = TelegramApi.get_updates(1, Telegram.offset, limitNumberOfUpdates, {"message"})

    local books = {}
    print(json.encode(success))
    if type(success) == "table" and type(success.result) == "table" then
        local updates = success.result
        print(string.format("Size = %d", #updates))
        for i, update in ipairs(updates) do
            print("Update N =", i)
            if type(update) == "table" and type(update.message) == "table" then
                local document = update.message.document
                local entities = update.message.entities
                local text = update.message.text
                if type(document) == "table" and document.file_name and document.file_id then
                    table.insert(books, {text = document.file_name, file_id = document.file_id, type = "file"})
                elseif type(entities) == "table" then
                    for _, entitie in ipairs(entities) do
                        if type(entitie) == "table" and entitie.type == "url" and entitie.length and entitie.offset and text then
                            print("Url detected")
                            local offset_index = entitie.offset + 1
                            local url = text:sub(offset_index, offset_index + entitie.length)
                            table.insert(books, {text = url, url = url, type = "file"})
                        end
                    end
                end
                Telegram.offset = update.update_id and update.update_id + 1 or Telegram.offset
                print(Telegram.offset)
            end
        end
    end
    return books
end
   
function Telegram:getFileUrl(file_id, token)
    TelegramApi.token = token
    success = TelegramApi.get_file(file_id)
    if type(success) == "table" and type(success.result) == "table" and success.result.file_path then
        file_path = success.result.file_path
        return "https://api.telegram.org/file/bot" .. token .. "/" .. file_path
    else
        logger.warn("Telegram.getFileUrl: get_file error")
        return false
    end
end

function downloadFileFromUrl(url, local_path)
    socketutil:set_timeout(socketutil.FILE_BLOCK_TIMEOUT, socketutil.FILE_TOTAL_TIMEOUT)
    local code, headers, status = socket.skip(1, http.request{
        url     = url,
        method  = "GET",
        sink    = ltn12.sink.file(io.open(local_path, "w")),
    })
    socketutil:reset_timeout()
    if code ~= 200 then
        logger.warn("Telegram: can't download file:", status or code)
    end
    return code
end


function Telegram:downloadFile(item, address, username, password, path, callback_close)
    print(item, address, username, password, path, callback_close)
    local url
    if item.file_id and type(item.file_id) == "string" then
        -- we need first get url using getFileUrl method
        url = Telegram:getFileUrl(item.file_id, password)
        print(url)
    elseif item.url and type(item.url) == "string" then
        url = item.url
    end
    if url then
        local code = downloadFileFromUrl(url, path)
        if code == 200 then
            local __, filename = util.splitFilePathName(path)
            if G_reader_settings:isTrue("show_unsupported") and not DocumentRegistry:hasProvider(filename) then
                UIManager:show(InfoMessage:new{
                    text = T(_("File saved to:\n%1"), BD.filename(path)),
                })
            else
                UIManager:show(ConfirmBox:new{
                    text = T(_("File saved to:\n%1\nWould you like to read the downloaded book now?"),
                        BD.filepath(path)),
                    ok_callback = function()
                        local Event = require("ui/event")
                        UIManager:broadcastEvent(Event:new("SetupShowReader"))

                        if callback_close then
                            callback_close()
                        end

                        ReaderUI:showReader(path)
                    end
                })
            end
        else
            UIManager:show(InfoMessage:new{
                text = T(_("Could not save file to:\n%1"), BD.filepath(path)),
                timeout = 3,
            })
        end
    else
        UIManager:show(InfoMessage:new{
            text = T(_("Could not save file to:\n%1"), BD.filepath(path)),
            timeout = 3,
        })
    end
end



function Telegram:config(item, callback)
    local text_info = _([[
For using this functionality you must first create bot in Telegram client application using @BotFather.
Paste provided token in token field. Send books to this device just post to bot
book file or http/https link. Select books from list and download it (max size <= 20 MB).]])
    local text_name, text_token, text_appkey, text_url
    if item then
        text_name = item.text
        text_token = item.password
    end
    self.settings_dialog = MultiInputDialog:new {
        title = _("Telegram bot"),
        fields = {
            {
                text = text_name,
                hint = _("Name (any, for menu entry only)"),
            },
            {
                text = text_token,
                hint = _("Bot token (from BotFather)"),
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

function Telegram:info(item)
    local yes_no = function(v) return v and _("Yes") or _("No")  end
    TelegramApi.token = item.password
    local success, res = TelegramApi.get_me()
    if type(success) == "table" and type(success.result) == "table" then
        local info = success.result
        UIManager:show(InfoMessage:new{
            text = T(_"Username: %1\nFirst name: %2\nCan join groups: %3\nCan read all group messages: %4",
                info.username, info.first_name,
                yes_no(info.can_join_groups),
                yes_no(info.can_read_all_group_messages))
        })
    end
end

return Telegram
