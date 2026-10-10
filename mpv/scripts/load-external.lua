-- load-external.lua: загрузка внешних аудио/субтитров через zenity (аналог open-file из uosc)
-- Биндинги: см. input.conf (ctrl+s = субтитры, ctrl+a = аудио),
--   плюс средняя кнопка мыши на иконках сабов/аудио в ModernZ.
-- ModernZ из коробки показывает только встроенные дорожки (select-меню mpv),
-- поэтому внешние файлы грузим этим скриптом.
--
-- sub-add/audio-add живут только одну сессию, а watch-later сохраняет sid/aid
-- по индексу — после перезапуска индекс бьёт в пустоту и гаснут вообще все сабы.
-- Поэтому храним {файл: внешние дорожки + sid/aid} в external-tracks.json,
-- при открытии файла пере-добавляем внешние дорожки и восстанавливаем выбор.
local utils = require("mp.utils")

local state_path = mp.command_native({ "expand-path", "~~/external-tracks.json" })

local function load_state()
    local f = io.open(state_path, "r")
    if not f then return {} end
    local data = f:read("*a")
    f:close()
    if not data or data == "" then return {} end
    local ok, tbl = pcall(utils.parse_json, data)
    if ok and type(tbl) == "table" then return tbl end
    return {}
end

local function store_state(state)
    local f = io.open(state_path, "w")
    if not f then return end
    f:write(utils.format_json(state))
    f:close()
end

-- ключ: абсолютный путь (или URL для стримов)
local function media_key()
    local path = mp.get_property("path")
    if not path or path == "" then return nil end
    if path:match("://") or path:sub(1, 1) == "/" then return path end
    return (mp.get_property("working-directory") or "") .. "/" .. path
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

-- запомнить внешние дорожки + текущий выбор sid/aid для открытого файла
local function save_state()
    local key = media_key()
    if not key then return end
    local tracks = mp.get_property_native("track-list") or {}
    local subs, audios = {}, {}
    for _, t in ipairs(tracks) do
        if t.external and t["external-filename"] then
            if t.type == "sub" then subs[#subs + 1] = t["external-filename"] end
            if t.type == "audio" then audios[#audios + 1] = t["external-filename"] end
        end
    end
    local state = load_state()
    if #subs == 0 and #audios == 0 then
        state[key] = nil -- внешних нет — хранить нечего
    else
        state[key] = {
            subs = subs,
            audios = audios,
            sid = mp.get_property_native("sid"), -- число или false
            aid = mp.get_property_native("aid"),
        }
    end
    store_state(state)
end

local function set_track(prop, val)
    if val == nil then return end
    if val == false then
        mp.commandv("set", prop, "no")
    else
        mp.commandv("set", prop, val)
    end
end

-- при открытии файла: пере-добавить внешние дорожки, восстановить sid/aid
mp.register_event("file-loaded", function()
    local key = media_key()
    if not key then return end
    local entry = load_state()[key]
    if not entry then return end
    local tracks = mp.get_property_native("track-list") or {}
    local present = {}
    for _, t in ipairs(tracks) do
        if t.external and t["external-filename"] then
            present[t["external-filename"]] = true
        end
    end
    for _, f in ipairs(entry.subs or {}) do
        if not present[f] and file_exists(f) then
            mp.commandv("sub-add", f, "auto")
            present[f] = true
        end
    end
    for _, f in ipairs(entry.audios or {}) do
        if not present[f] and file_exists(f) then
            mp.commandv("audio-add", f, "auto")
            present[f] = true
        end
    end
    set_track("sid", entry.sid)
    set_track("aid", entry.aid)
end)

-- при закрытии/конце файла: зафиксировать состояние
mp.register_event("end-file", function()
    save_state()
end)

local function pick_file(title)
    local res = utils.subprocess({
        args = { "zenity", "--file-selection", "--title=" .. title },
        cancellable = false,
    })
    if not res or res.status ~= 0 or not res.stdout or res.stdout == "" then
        return nil -- отмена диалога
    end
    return (res.stdout:gsub("%s+$", ""))
end

mp.add_key_binding(nil, "load-file", function()
    local path = pick_file("Open media file")
    if path then
        mp.commandv("loadfile", path)
    end
end)

mp.add_key_binding(nil, "load-sub", function()
    local path = pick_file("Load subtitle file")
    if path then
        mp.commandv("sub-add", path, "select")
        mp.osd_message("Subtitles loaded: " .. path)
        save_state()
    end
end)

mp.add_key_binding(nil, "load-audio", function()
    local path = pick_file("Load audio file")
    if path then
        mp.commandv("audio-add", path, "select")
        mp.osd_message("Audio loaded: " .. path)
        save_state()
    end
end)
