
-- Главные таблицы
TPR = CreateFrame("Frame")
TPR:RegisterEvent("ADDON_LOADED")
TPR:RegisterEvent("PLAYER_LOGIN")
TPR:RegisterEvent("GUILD_ROSTER_UPDATE")

TPR_Data = TPR_Data or {} -- Сохраняемые переменные через SavedVariables -- Сохраняемые переменные позже через SavedVariables

-- Ограничения по жетонам
TPR_MAX_LT = 10
TPR_MAX_PT = 3

-- Slash-команды
SLASH_TPR1 = "/tpr"
SLASH_TPRA1 = "/tpra"

SlashCmdList["TPR"] = function()
  if not TPR_MainFrame then
    print("TPR: интерфейс ещё не загружен")
    return
  end
  TPR_MainFrame:SetShown(not TPR_MainFrame:IsShown())
end

SlashCmdList["TPRA"] = function()
  if not TPR_AdminFrame then
    print("TPR Admin: интерфейс ещё не загружен")
    return
  end
  TPR_AdminFrame:SetShown(not TPR_AdminFrame:IsShown())
end

-- Событие загрузки
TPR:SetScript("OnEvent", function(self, event, addon)
  if event == "ADDON_LOADED" and addon == "TPR" then
    if not TPR_Data then TPR_Data = {} end
    print("TPR загружен. Используйте /tpr для доступа.")
    TPR_InitMainFrame()
  elseif event == "PLAYER_LOGIN" then
    GuildRoster() -- Запрашиваем обновление гильдростера при входе
  elseif event == "GUILD_ROSTER_UPDATE" then
    if TPR_MainFrame and TPR_MainFrame:IsShown() then
      TPR_MainFrame:RefreshTable()
    end
  end
end)

-- Создание основного UI
function TPR_InitMainFrame()
  local f = CreateFrame("Frame", "TPR_MainFrame", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(523, 400)
  f:SetPoint("CENTER")
  f:Hide()
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.title:SetPoint("TOP", 0, -5)
  f.title:SetText("TPR — Таблица жетонов")

  -- Столбцы и сортировка
  local columns = {
    { key = "name", label = "Имя", x = 5 },
    { key = "class", label = "Класс", x = 140 },
    { key = "lt", label = "Lucky Token", x = 280 },
    { key = "pt", label = "Prestige Token", x = 380 },
  }
  f.sortKey = "name"
  f.sortAsc = true
  f.showOffline = true

  for _, col in ipairs(columns) do
    local btn = CreateFrame("Button", nil, f)
    btn:SetSize(100, 20)
    btn:SetPoint("TOPLEFT", col.x, -25)
    btn:SetNormalFontObject("GameFontHighlightSmall")
    btn:SetText(col.label)
    btn:SetScript("OnClick", function()
      if f.sortKey == col.key then
        f.sortAsc = not f.sortAsc
      else
        f.sortKey = col.key
        f.sortAsc = true
      end
      f:RefreshTable()
    end)
  end

  -- Scroll
  f.scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  f.scrollFrame:SetPoint("TOPLEFT", 15, -40)
  f.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)

  f.content = CreateFrame("Frame", nil, f.scrollFrame)
  f.content:SetSize(560, 1000)
  f.scrollFrame:SetScrollChild(f.content)

  f.rows = {}

  local function GetClassColor(class)
    local c = RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }
    return c.r, c.g, c.b
  end

  function f:RefreshTable()
    SetGuildRosterShowOffline(true)
    for _, row in ipairs(f.rows) do row:Hide() end
    wipe(f.rows)

    local data = {}
    for i = 1, GetNumGuildMembers() do
      local nameWithRealm, _, _, _, class, _, _, officerNote, online, _, classFilename = GetGuildRosterInfo(i)
      if f.showOffline or online then
      local name = strsplit("-", nameWithRealm)
      local lt, pt = 0, 0
      if officerNote and officerNote:find(",") then
        lt, pt = officerNote:match("(%d+),(%d+)")
        lt, pt = tonumber(lt), tonumber(pt)
      end
      table.insert(data, { name = name, class = class, lt = lt, pt = pt, online = online, classFilename = classFilename })
    end
  end

    table.sort(data, function(a, b)
      local k = f.sortKey
      if f.sortAsc then
        return tostring(a[k]) < tostring(b[k])
      else
        return tostring(a[k]) > tostring(b[k])
      end
    end)

    for i, entry in ipairs(data) do
      local row = f.rows[i] or CreateFrame("Frame", nil, f.content)
      row:SetSize(540, 20)
      row:SetPoint("TOPLEFT", 0, -((i - 1) * 22))

      local r, g, b = GetClassColor(entry.classFilename)
      local alpha = entry.online and 1 or 0.4

      row.nameText = row.nameText or row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      row.nameText:SetPoint("LEFT", 5, 0)
      row.nameText:SetTextColor(r, g, b, alpha)
      row.nameText:SetText(entry.name)

      row.classText = row.classText or row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      row.classText:SetPoint("LEFT", 150, 0)
      row.classText:SetTextColor(1, 1, 1, alpha)
      row.classText:SetText(entry.class)

      row.ltText = row.ltText or row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      row.ltText:SetPoint("LEFT", 300, 0)
      row.ltText:SetTextColor(1, 1, 1, alpha)
      row.ltText:SetText("LT: " .. entry.lt)

      row.ptText = row.ptText or row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      row.ptText:SetPoint("LEFT", 400, 0)
      row.ptText:SetTextColor(1, 1, 1, alpha)
      row.ptText:SetText("PT: " .. entry.pt)

      row:Show()
      f.rows[i] = row
    end
  end

  -- Кнопка-глаз для переключения отображения оффлайна
local toggleBtn = CreateFrame("Button", nil, f)
toggleBtn:SetSize(15, 15)
toggleBtn:SetPoint("TOPRIGHT", -30, -5)

toggleBtn.icon = toggleBtn:CreateTexture(nil, "ARTWORK")
toggleBtn.icon:SetAllPoints()
toggleBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02") -- Можно заменить

toggleBtn:SetScript("OnEnter", function()
  GameTooltip:SetOwner(toggleBtn, "ANCHOR_RIGHT")
  GameTooltip:SetText("Показ оффлайн: " .. (f.showOffline and "включен" or "выключен"), 1, 1, 1)
  GameTooltip:Show()
end)
toggleBtn:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

toggleBtn:SetScript("OnClick", function()
  f.showOffline = not f.showOffline
  f:RefreshTable()
  GameTooltip:Hide()
end)

  f:SetScript("OnShow", function() f:RefreshTable() end)

 -- Функции жетонов
function GetPlayerTokens(name)
  for i = 1, GetNumGuildMembers() do
    local fullName, _, _, _, _, _, _, officerNote = GetGuildRosterInfo(i)
    local shortName = strsplit("-", fullName)
    if shortName == name then
      if officerNote and officerNote:find(",") then
        local lt, pt = officerNote:match("(%d+),(%d+)")
        return tonumber(lt) or 0, tonumber(pt) or 0
      end
    end
  end
  return 0, 0
end
function SetPlayerTokens(name, lt, pt)
  lt = math.min(lt, TPR_MAX_LT)
  pt = math.min(pt, TPR_MAX_PT)

  for i = 1, GetNumGuildMembers() do
    local fullName = GetGuildRosterInfo(i)
    local shortName = strsplit("-", fullName)
    if shortName == name then
      GuildRosterSetOfficerNote(i, lt .. "," .. pt)
      return
    end
  end
end
  -- Кнопки внизу
 local function CreateButton(name, text, x, parent, onClickFunc)
  local btn = CreateFrame("Button", name, parent, "GameMenuButtonTemplate")
  btn:SetSize(160, 30)
  btn:SetPoint("BOTTOMLEFT", x, 10)
  btn:SetText(text)
  if onClickFunc then
    btn:SetScript("OnClick", onClickFunc)
  end
  return btn
end

local playerName = UnitName("player")

local function HasTokens(ltNeeded, ptNeeded)
  local lt, pt = GetPlayerTokens(playerName)
  return (lt or 0) >= (ltNeeded or 0) and (pt or 0) >= (ptNeeded or 0)
end

CreateButton("TPR_RollButton", "Бросок (LT)", 10, f, function()
  if not HasTokens(1, 0) then
    print("TPR: у вас нет достаточного количества LT жетонов")
    return
  end
  local lt, pt = GetPlayerTokens(playerName)
  SetPlayerTokens(playerName, lt - 1, pt)
  SendChatMessage(" использовал 1 Счастливый жетон (LT)", "GUILD")
  SlashCmdList["RANDOM"]("")
  print("Выполнен бросок LT для " .. playerName)
  if TPR_MainFrame:IsShown() then TPR_MainFrame:RefreshTable() end
end)

CreateButton("TPR_PrestigeRollButton", "Бросок Престижа (PT)", 180, f, function()
  if not HasTokens(0, 1) then
    print("TPR: у вас нет достаточного количества PT жетонов")
    return
  end
  local lt, pt = GetPlayerTokens(playerName)
  SetPlayerTokens(playerName, lt, pt - 1)
  SendChatMessage(" использовал 1 Жетон престижа (PT)", "GUILD")
  SlashCmdList["RANDOM"]("")
  print("Выполнен бросок PT для " .. playerName)
  if TPR_MainFrame:IsShown() then TPR_MainFrame:RefreshTable() end
end)

CreateButton("TPR_ExchangeButton", "Обмен 10LT В 1PT", 350, f, function()
  local lt, pt = GetPlayerTokens(playerName)
  if lt < 10 then
    print("TPR: недостаточно LT для обмена (нужно 10).")
    return
  end
  if pt >= TPR_MAX_PT then
    print("TPR: достигнут максимум PT жетонов.")
    return
  end
   SetPlayerTokens(playerName, lt - 10, pt + 1)
  SendChatMessage(" обменял 10 LT на 1 Жетон престижа (PT)", "GUILD")

  if TPR_MainFrame:IsShown() then TPR_MainFrame:RefreshTable() end
end)
end


