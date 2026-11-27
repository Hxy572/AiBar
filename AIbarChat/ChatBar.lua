-- AIbarChat：聊天快捷按钮（从 AIbar 拆出的独立插件）
-- 点按钮 = 把频道前缀填进聊天输入框（不直接发言，防误触）

local ADDON = "AIbarChat"
AIbarChatDB = AIbarChatDB or {}
local DB = AIbarChatDB
if DB.anchor == nil then DB.anchor = false end

local C = {}
C.bar = nil
C.buttons = {}
C.gear = nil
C.cfg = nil

local EN = (type(GetLocale) == "function" and GetLocale() == "enUS")

local BTNS = {
  { "说", "S", "/s ", nil, "说话  /s" },
  { "喊", "Y", "/y ", nil, "呼喊  /y" },
  { "会", "G", "/g ", nil, "公会  /g" },
  { "队", "P", "/p ", nil, "小队  /p" },
  { "团", "R", "/ra ", nil, "团队  /ra" },
  { "1", "1", "/1 ", nil, "综合  /1" },
  { "2", "2", "/2 ", nil, "交易  /2" },
  { "3", "3", "/3 ", nil, "本地防务  /3" },
  { "4", "4", "/4 ", nil, "世界防务  /4" },
  { "5", "5", "/5 ", nil, "寻求组队  /5" },
  { "骰", "ROLL", nil, "roll", "掷骰  /random 100" },
}

local function lbl(d) if EN then return d[2] end return d[1] end
local function txt(s) return s end

local function say(msg)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffd8c081AiBarChat|r：" .. msg) end
end

local function OpenChat(cmd)
  if type(ChatFrame_OpenChat) == "function" then
    local ok = pcall(ChatFrame_OpenChat, cmd)
    if ok then return end
  end
  local eb = _G["ChatFrame1EditBox"]
  if not eb then return end
  if eb.Show then pcall(eb.Show, eb) end
  pcall(eb.SetText, eb, cmd)
  if eb.SetFocus then pcall(eb.SetFocus, eb) end
end

local function RollDice()
  if type(RandomRoll) == "function" then
    if pcall(RandomRoll, 1, 100) then return end
  end
  OpenChat("/random 100 ")
end

-- 拖动（统一用光标位移，不用 StartMoving）
local function makeDraggable(target, handle)
  local down = false
  local sx, sy, ox, oy, moved
  handle:SetScript("OnMouseDown", function()
    down = true
    moved = false
    local cx, cy = GetCursorPosition()
    sx, sy = cx or 0, cy or 0
    local pt, rel, rp, x, y = target:GetPoint(1)
    ox, oy = x or 0, y or 0
  end)
  local upd = CreateFrame("Frame")
  upd:SetScript("OnUpdate", function()
    if not down then return end
    local cx, cy = GetCursorPosition()
    if not cx then return end
    local dx, dy = (cx - sx) / (target:GetEffectiveScale() or 1), (cy - sy) / (target:GetEffectiveScale() or 1)
    if math.abs(dx) > 1 or math.abs(dy) > 1 then
      moved = true
      target:ClearAllPoints()
      target:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", ox + dx, oy + dy)
    end
  end)
  handle:SetScript("OnMouseUp", function()
    down = false
    if moved then
      local L, T = target:GetLeft(), target:GetTop()
      if L and T then
        local H = target:GetHeight() or 34
        DB.anchor = { "BOTTOMLEFT", "BOTTOMLEFT", L, T - H }
      end
      AIbarChat_Save()
    end
  end)
  handle:SetScript("OnHide", function() down = false end)
end

function AIbarChat_Save()
  AIbarChatDB.anchor = DB.anchor
  AIbarChatDB.hide = DB.hide
end

local function ApplyAnchor()
  C.bar:ClearAllPoints()
  local a = DB.anchor
  if type(a) == "table" and a[1] then
    C.bar:SetPoint(a[1], UIParent, a[2], a[3], a[4])
  else
    C.bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 220)
  end
end

local function Blocked()
  local i
  for i = 1, 13 do
    local fr = _G["ContainerFrame" .. i]
    if fr and fr:IsShown() then return true end
  end
  local list = { "BankFrame", "MacroFrame", "GossipFrame", "MerchantFrame", "MailFrame" }
  for i = 1, #list do
    local fr = _G[list[i]]
    if fr and fr:IsShown() then return true end
  end
  return false
end

local function Layout()
  local x = 0
  local i, b, d
  for i = 1, #BTNS do
    b, d = C.buttons[i], BTNS[i]
    if b then
      if DB.hide and DB.hide[d[1]] then
        b:Hide()
      else
        b:ClearAllPoints()
        b:SetPoint("LEFT", C.bar, "LEFT", x, 0)
        x = x + 44
        b:Show()
      end
    end
  end
  if C.gear then
    C.gear:ClearAllPoints()
    C.gear:SetPoint("LEFT", C.bar, "LEFT", x, 0)
    x = x + 44
  end
  C.bar:SetWidth(math.max(44, x))
end

function AIbarChat_ApplyVis()
  if not C.bar then return end
  if DB.on == false or Blocked() then
    C.bar:Hide()
  else
    C.bar:Show()
  end
end

local function MkButton(bar, d, i)
  local b = CreateFrame("Button", nil, bar)
  b:SetWidth(40); b:SetHeight(32)
  b:SetPoint("LEFT", bar, "LEFT", (i - 1) * 44, 0)
  b:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  b:SetBackdropColor(0.16, 0.15, 0.14, 0.9)
  b:SetBackdropBorderColor(0.42, 0.39, 0.34, 1)
  local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetPoint("CENTER", b, "CENTER")
  t:SetText(lbl(d))
  b.lbl = t
  b:SetScript("OnClick", function()
    if d[4] == "roll" then RollDice() else OpenChat(d[3]) end
  end)
  return b
end

local function OpenCfg()
  local f = C.cfg
  if not f then
    f = CreateFrame("Frame", "AIbarChatCfg", UIParent)
    f:SetWidth(300); f:SetHeight(70 + #BTNS * 30)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
    f:SetBackdropBorderColor(0.42, 0.39, 0.34, 1)
    local ti = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ti:SetPoint("TOP", f, "TOP", 0, -10)
    ti:SetText("|cffd8c081聊天按钮开关|r")
    f.rows = {}
    local i, d
    for i = 1, #BTNS do
      d = BTNS[i]
      local b = CreateFrame("Button", nil, f)
      b:SetWidth(260); b:SetHeight(26)
      b:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -30 - (i - 1) * 30)
      b:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
      b:SetBackdropColor(0.14, 0.24, 0.14, 0.9)
      local l = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      l:SetPoint("LEFT", b, "LEFT", 8, 0)
      l:SetText(lbl(d) .. "  " .. (d[3] or "roll"))
      b.__key = d[1]
      b:SetScript("OnClick", function()
        DB.hide = DB.hide or {}
        local k = b.__key
        if DB.hide[k] then DB.hide[k] = nil else DB.hide[k] = true end
        Layout()
        OpenCfg()
        AIbarChat_Save()
      end)
      f.rows[i] = b
    end
    local cl = CreateFrame("Button", nil, f)
    cl:SetWidth(120); cl:SetHeight(26)
    cl:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)
    cl:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
    cl:SetBackdropColor(0.2, 0.18, 0.14, 0.95)
    local clt = cl:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clt:SetPoint("CENTER", cl, "CENTER")
    clt:SetText("关闭")
    cl:SetScript("OnClick", function() f:Hide() end)
    C.cfg = f
  end
  local i, d, b
  for i = 1, #BTNS do
    d, b = BTNS[i], f.rows[i]
    if b then
      if DB.hide and DB.hide[d[1]] then
        b:SetBackdropColor(0.3, 0.12, 0.12, 0.9)
      else
        b:SetBackdropColor(0.14, 0.24, 0.14, 0.9)
      end
    end
  end
  f:Show()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local bar = CreateFrame("Frame", "AIbarChatBar", UIParent)
  C.bar = bar
  bar:SetHeight(34)
  bar:SetFrameStrata("LOW")
  if bar.SetFrameLevel then bar:SetFrameLevel(1) end
  ApplyAnchor()

  local i
  for i = 1, #BTNS do
    C.buttons[i] = MkButton(bar, BTNS[i], i)
  end

  -- 拖动把手
  local hd = CreateFrame("Button", "AIbarChatHandle", bar)
  hd:SetWidth(64); hd:SetHeight(16)
  hd:SetPoint("BOTTOM", bar, "TOP", 0, 0)
  hd:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  hd:SetBackdropColor(0.16, 0.15, 0.14, 0.85)
  hd:SetBackdropBorderColor(0.45, 0.42, 0.38, 0.9)
  local hl = hd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  hl:SetPoint("CENTER", hd, "CENTER")
  hl:SetText("拖")
  hd:EnableMouse(true)
  makeDraggable(bar, hd)
  bar.handle = hd

  -- 设置按钮
  local gear = CreateFrame("Button", nil, bar)
  gear:SetWidth(40); gear:SetHeight(32)
  gear:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  gear:SetBackdropColor(0.22, 0.19, 0.13, 0.95)
  gear:SetBackdropBorderColor(0.55, 0.46, 0.3, 1)
  local gt = gear:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  gt:SetPoint("CENTER", gear, "CENTER")
  gt:SetText(EN and "Cfg" or "设")
  gear:SetScript("OnClick", OpenCfg)
  C.gear = gear

  Layout()
  AIbarChat_ApplyVis()
end)

local tick = CreateFrame("Frame")
tick:SetScript("OnUpdate", function()
  tick.__t = (tick.__t or 0) + (arg1 or 0)
  if tick.__t < 0.3 then return end
  tick.__t = 0
  if AIbarChat_ApplyVis then AIbarChat_ApplyVis() end
end)

-- 关闭窗口后恢复显示：打开时每 0.3 秒自动检测
