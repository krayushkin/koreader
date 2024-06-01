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
local json = require("rapidjson")
local ltn12 = require('ltn12')
local T = require("ffi/util").template
local _ = require("gettext")

-- TODO
-- Deal with files with size more then 20MB
-- Test connection loss. On get_updates and on get_file
-- Refactor. Minimize size of functions
-- Remove unused code from telegram-bot-lua/core
-- Replace print with logger function
-- Implement functionality with download using plain url
-- Implement Info button and test it
-- Test functionality with with several telegram bot api tokens
-- Maybe add refresh button for force refresh?
-- Or just leave message for user if list of updates is empty

local Telegram = {
    offset = 0 -- offset for get_updates
}


function Telegram:run(password)
    TelegramApi.token = password

    local limitNumberOfUpdates = 100
    local timeout = 1
    local success = TelegramApi.get_updates(timeout, Telegram.offset, limitNumberOfUpdates, {"message"})

    local books = {}
    logger.dbg("Recieved updates object:", json.encode(success))
    if type(success) == "table" and type(success.result) == "table" then
        local updates = success.result
        for i, update in ipairs(updates) do
            logger.dbg("Process update N =", i)
            if type(update) == "table" and type(update.message) == "table" then
                local document = update.message.document
                local entities = update.message.entities
                local text = update.message.text
                if type(document) == "table" and document.file_name and document.file_id then
                    if DocumentRegistry:hasProvider(document.file_name) or G_reader_settings:isTrue("show_unsupported") then
                        table.insert(books, {text = document.file_name, file_id = document.file_id, type = "file"})
                    end
                end
                Telegram.offset = update.update_id and update.update_id + 1 or Telegram.offset
                logger.dbg("offset for next get_updates request:", Telegram.offset)
            end
        end
    end
    return books
end


function Telegram:getFileUrl(file_id, token)
    TelegramApi.token = token
    local success = TelegramApi.get_file(file_id)
    local max_allowed_file_size = 20e6 -- 20MB
    if type(success) == "table" and type(success.result) == "table" and success.result.file_path then
        local file_path = success.result.file_path
        local file_size = tonumber(success.result.file_size)
        if file_size and (file_size <= max_allowed_file_size) then
            return "https://api.telegram.org/file/bot" .. token .. "/" .. file_path
        else
            return false
        end
    else
        logger.warn("Telegram.getFileUrl: get_file error")
        return false
    end
end

local function downloadFileFromUrl(url, local_path)
    socketutil:set_timeout(socketutil.FILE_BLOCK_TIMEOUT, socketutil.FILE_TOTAL_TIMEOUT)
    local code = socket.skip(1, http.request{
        url     = url,
        method  = "GET",
        sink    = ltn12.sink.file(io.open(local_path, "w")),
    })
    socketutil:reset_timeout()
    if code ~= 200 then
        logger.warn("Telegram: can't download file:", code)
    end
    return code
end


function Telegram:downloadFile(item, address, username, password, path, callback_close)
    local url
    if item.file_id and type(item.file_id) == "string" then
        -- we need first get url using getFileUrl method
        url = Telegram:getFileUrl(item.file_id, password)
    end
    if url then
        local code = downloadFileFromUrl(url, path)
        if code == 200 then
            local __, filename = util.splitFilePathName(path)
            if DocumentRegistry:hasProvider(filename) then
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
            else
                UIManager:show(InfoMessage:new{
                    text = T(_("File saved to:\n%1"), BD.filename(path)),
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
            text = _("Could not get file url for download or file too large"),
            timeout = 3,
        })
    end
end



function Telegram:config(item, callback)
    local text_info = _([[
First create bot in Telegram client application using @BotFather.
Paste provided token in token field. Send telegram message with book (as file) to your bot.
Select book from list and download. The maximum file size to download is 20 MB.
]])

    local text_name, text_token
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
                hint = _("Bot token (from @BotFather)"),
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
                        if fields[1] ~= "" and fields[2] ~= "" then
                            if item then
                                callback(item, fields)
                            else
                                callback(fields)
                            end
                            self.settings_dialog:onClose()
                            UIManager:close(self.settings_dialog)
                        else
                            UIManager:show(InfoMessage:new{
                                text = _("Please fill in all fields.")
                            })
                        end
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
    local success = TelegramApi.get_me()
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
