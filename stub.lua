-- 极简 WoW 1.12 API 桩：只为跑通 AiBar 的加载、事件、点击、拖动、配置面板
local W = { frames = {}, time = 0, cursor = { x = 500, y = 400 }, mouseDown = false,
            chat = {}, target = false, pet = false, inCombat = false, unknown = {},
            stealth = false, classLocal = "术士", classToken = "Warlock" }
_G.EVAL_HELP_CONFIG = {}

local FNS = {}
local meta = {}
meta.__index = function(t, k)
  local fn = FNS[k]
  if fn then return fn end
  if type(k) == "string" and string.sub(k, 1, 2) == "__" then return nil end
  -- 只有大写开头的才当方法；小写字段缺省返回 nil（跟真客户端一致）
  if type(k) == "string" and string.find(k, "^%u") then
    return function() W.unknown[k] = (W.unknown[k] or 0) + 1 end
  end
  return nil
end

local function newObj(kind, name, parent)
  local o = setmetatable({ __kind = kind, __name = name, __parent = parent,
                           __w = 0, __h = 0, __shown = true, __scripts = {}, __events = {},
                           __pt = nil, __scale = 1 }, meta)
  W.frames[#W.frames + 1] = o
  if name then _G[name] = o end
  return o
end

function FNS:GetNumPoints() return #(self.__points or {}) end
function FNS:SetOwner(anchor) W.tipOwner = self end
function FNS:SetInventoryItem(unit, slot) self.__inv = tostring(unit) .. ":" .. tostring(slot) end
function FNS:SetBagItem(bag, slot) self.__bagitem = tostring(bag) .. ":" .. tostring(slot) end
function FNS:SetHyperlink(link) self.__link = link end
function FNS:AddLine(txt) end
function FNS:GetChildren()
  local out = {}
  local i
  for i = 1, #W.frames do
    local o = W.frames[i]
    if o.__parent == self then out[#out + 1] = o end
  end
  return unpack(out)
end
function FNS:GetRegions()
  local out = {}
  local i
  for i = 1, #W.frames do
    local o = W.frames[i]
    if o.__parent == self and o.__kind == "FontString" then out[#out + 1] = o end
  end
  return unpack(out)
end
function FNS:SetPoint(pt, rel, rp, x, y)
  if type(pt) == "table" or x ~= nil or y ~= nil or rel ~= nil then
    self.__pt = { pt, rel, rp, x or 0, y or 0 }
  end
end
function FNS:GetPoint(i)
  local p = self.__pt
  if not p then return nil end
  return p[1], p[2], p[3], p[4], p[5]
end
function FNS:ClearAllPoints() self.__pt = nil end
function FNS:SetAllPoints() self.__pt = { "TOPLEFT", nil, "TOPLEFT", 0, 0 } end
function FNS:SetWidth(w) self.__w = w end
function FNS:SetHeight(h) self.__h = h end
function FNS:GetWidth() return self.__w end
function FNS:GetHeight() return self.__h end
function FNS:GetLeft()
  local p = self.__pt
  if not p then return nil end
  return (p[4] or 0)
end
function FNS:GetTop()
  local p = self.__pt
  if not p then return nil end
  return 768 - (p[5] or 0)
end
function FNS:GetBottom()
  local t = self:GetTop()
  if not t then return nil end
  return t - (self.__h or 0)
end
function FNS:SetBackdrop() end
function FNS:SetBackdropColor() end
function FNS:SetBackdropBorderColor() end
function FNS:SetTexture(a, b, c, d)
  if type(a) == "number" then self.__color = { a, b, c, d } else self.__tex = a end
end
function FNS:SetTexCoord(a, b, c, d) if type(a) == "number" then self.__tc = { a, b, c, d } end end
function FNS:SetVertexColor(a, b, c, d) if type(a) == "number" then self.__vc = { a, b, c, d } end end
function FNS:SetAlpha(a) self.__alpha = a or 1 end
function FNS:GetAlpha() return self.__alpha or 1 end
function FNS:SetScale(s) self.__scale = s or 1 end
function FNS:GetScale() return self.__scale end
function FNS:SetFrameLevel() end
function FNS:SetFrameStrata(v) self.__strata = v end
function FNS:SetMovable() end
function FNS:RegisterForDrag() end
function FNS:RegisterForClicks() end
function FNS:EnableMouse() end
function FNS:StartMoving() end
function FNS:StopMovingOrSizing() end
function FNS:SetHighlightTexture() end
function FNS:SetJustifyH() end
function FNS:SetText(t) self.__text = t end
function FNS:GetText() return self.__text end
function FNS:SetFont(f, s, fl) self.__font = { f, s, fl } end
function FNS:GetFont()
  local f = self.__font
  if f then return f[1], f[2], f[3] end
  return "Fonts\\FRIZQT__.TTF", 12, ""
end
function FNS:Show() self.__shown = true end
function FNS:Hide()
  local was = self.__shown
  self.__shown = false
  local fn = self.__scripts and self.__scripts.OnHide
  if was and fn then fn() end
end
function FNS:IsShown() return self.__shown end
function FNS:IsVisible() return self.__shown end
function FNS:SetScript(name, fn) self.__scripts[name] = fn end
function FNS:GetScript(name) return self.__scripts[name] end
function FNS:RegisterEvent(ev) self.__events = self.__events or {}; self.__events[ev] = true end
function FNS:GetParent() return self.__parent end
function FNS:SetParent(p) self.__parent = p end
function FNS:GetName() return self.__name end
function FNS:GetID() return self.__id end
function FNS:SetID(v) self.__id = v end
function FNS:GetObjectType() return self.__kind end
function FNS:CreateTexture() return newObj("Texture", nil, self) end
function FNS:CreateFontString() return newObj("FontString", nil, self) end
function FNS:GetEffectiveScale() return 1 end
function FNS:SetHitRectInsets() end
function FNS:GetFrameStrata() return self.__strata end
function FNS:GetFrameLevel() return self.__level or 1 end
function FNS:SetFrameLevel(l) self.__level = l end
function FNS:Click()
  if self.__scripts and self.__scripts.OnClick then W:call(self, "OnClick", "LeftButton") end
end

function W:call(obj, script, a1, ev)
  local fn = obj.__scripts and obj.__scripts[script]
  if not fn then return false end
  _G.this = obj
  _G.arg1 = a1
  _G.event = ev
  fn()
  return true
end

function W:tick(dt)
  self.time = self.time + (dt or 0.05)
  for i = 1, #self.frames do
    local f = self.frames[i]
    if f.__scripts and f.__scripts.OnUpdate then self:call(f, "OnUpdate", dt) end
  end
end

function W:event(ev)
  for i = 1, #self.frames do
    local f = self.frames[i]
    if f.__events and f.__events[ev] and f.__scripts and f.__scripts.OnEvent then
      self:call(f, "OnEvent", nil, ev)
    end
  end
end

function W:click(cmd)
  local fn = _G.SlashCmdList[cmd]
  if fn then fn("") end
end

function W:clickButton(obj, button)
  return self:call(obj, "OnClick", button or "LeftButton")
end

-- 全局 API
_G.CreateFrame = function(kind, name, parent)
  return newObj(kind or "Frame", name, parent)
end
_G.getglobal = function(n) return _G[n] end
_G.GetTime = function() return W.time end
_G.GetCursorPosition = function() return W.cursor.x, W.cursor.y end
_G.IsMouseButtonDown = function() return W.mouseDown end
_G.GetScreenWidth = function() return 1024 end
_G.GetScreenHeight = function() return 768 end
_G.ReloadUI = function() W.reloaded = (W.reloaded or 0) + 1 end
_G.EnumerateFrames = function(prev)
  if not prev then return W.frames[1] end
  for i = 1, #W.frames do
    if W.frames[i] == prev then return W.frames[i + 1] end
  end
  return nil
end

_G.UIParent = newObj("Frame", "UIParent", nil)
_G.UIParent.__w, _G.UIParent.__h = 1024, 768
local TIP = {
  [9]  = { "终结技：造成 39 点伤害，每个连击点额外造成 15 点伤害。" },
  [10] = { "造成 10 点伤害，并使目标昏迷 4 秒。奖励 2 个连击点。" },
}
local tipLines = {}
_G.GameTooltip = {
  SetOwner = function(_, anchor) W.tipOwner = anchor end,
  SetAction = function(_, slot) tipLines = TIP[slot] or { "测试技能" } end,
  SetBagItem = function(_, bag, slot) tipLines = { "物品 " .. tostring(bag) .. "/" .. tostring(slot) } end,
  NumLines = function() return #tipLines end,
  AddLine = function() end, Show = function() W.tipShown = true end, Hide = function() W.tipShown = false end,
  SetPoint = function(_, pt, rel, rp, x, y) W.tipAnchor = rel; W.tipPoint = pt end,
  SetWidth = function(_, w) W.tipW = w end,
  ClearAllPoints = function() end,
  SetInventoryItem = function() end,
  IsShown = function() return W.tipShown == true end,
  GetBottom = function() return W.tipBottom or 400 end,
}
local li
for li = 1, 12 do
  _G["GameTooltipTextLeft" .. li] = { GetText = function() return tipLines[li] end }
end
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) W.chat[#W.chat + 1] = m end }
_G.SlashCmdList = {}
_G.SaveVariables = function() end
-- 模拟安卓触屏客户端：长按/右键换算接口
_G.EVAL_RMB_BTN = function(b) return b end
_G.BOOKTYPE_SPELL = "spell"

function _G.UnitClass() return W.classLocal, W.classToken end
function _G.UnitExists(u)
  if u == "target" then return W.target end
  if u == "pet" then return W.pet end
  return u == "player"
end
function _G.UnitHealth(u) return u == "target" and 620 or 900 end
function _G.UnitHealthMax(u) return 1000 end
function _G.UnitMana() return 420 end
function _G.UnitManaMax() return 800 end
function _G.UnitPowerType() return 0, "MANA" end
function _G.UnitAffectingCombat() return W.inCombat end
function _G.UnitAttackSpeed() return 2.4 end
function _G.UnitBuff(unit, i)
  if W.stealth and i == 1 then return "Interface\\Icons\\Ability_Stealth" end
  return nil
end
function _G.GetComboPoints() return W.combo or 0 end
function _G.GetNumShapeshiftForms() return 0 end
function _G.GetShapeshiftFormCooldown(i) return 0, 0 end

-- 每个槽位给一张像样的图标：9 号是终结技（剔骨），10 号是产连击点的技能，
-- 其余共用一个普通图标，和真实客户端“不同技能不同图标”的行为接近
local ACTION_ICONS = {
  [9]  = "Interface\\Icons\\Ability_Rogue_Eviscerate",
  [10] = "Interface\\Icons\\Ability_Rogue_SinisterStrike",
}
function _G.GetActionTexture(slot)
  if slot and slot <= 12 then
    return ACTION_ICONS[slot] or "Interface\\Icons\\Spell_Holy_Heal"
  end
  return nil
end
function _G.GetActionText(slot) if slot == 2 then return "开怪-测试宏" end return nil end
function _G.GetActionCount(slot) if slot == 3 then return 5 end return 1 end
function _G.GetActionCooldown(slot)
  if slot == 1 then
    W.cd1 = W.cd1 or (W.time + 0.1)
    return W.cd1, 3600
  end
  if slot == 4 then
    W.cd4 = W.cd4 or (W.time + 0.1)
    return W.cd4, 6
  end
  return 0, 0
end
function _G.IsActionInRange(slot) if slot == 5 then return 0 end return 1 end
function _G.IsUsableAction(slot) if slot == 6 then return 0, 0 end return 1, 0 end
function _G.UseAction(slot, c) W.used = (W.used or 0) + 1 end
function _G.PickupAction() end
function _G.PlaceAction() end
function _G.PickupSpell() end
function _G.PickupMacro() end
function _G.PickupContainerItem(bag, slot)
  local b = W.bags[bag]
  if not b then b = {}; W.bags[bag] = b end
  if W.cursorItem then
    local there = b[slot]
    b[slot] = W.cursorItem
    W.cursorItem = there
  else
    W.cursorItem = b[slot]
    W.cursorFrom = { bag = bag, slot = slot }
    b[slot] = nil
  end
end
function _G.ClearCursor()
  if W.cursorItem and W.cursorFrom then
    local f2 = W.cursorFrom
    local b = W.bags[f2.bag]
    if b and not b[f2.slot] then b[f2.slot] = W.cursorItem end
  end
  W.cursorItem, W.cursorFrom = nil, nil
end
function _G.GetNumSpellTabs() return 2 end
function _G.GetSpellTabInfo(tab)
  if tab == 1 then return "神圣", "Interface\\Icons\\Spell_Holy_Heal", 0, 3 end
  return "戒律", "Interface\\Icons\\Spell_Holy_PowerWordShield", 3, 2
end
function _G.GetSpellName(id) return "技能" .. tostring(id), "等级 1" end
function _G.GetSpellTexture() return "Interface\\Icons\\Spell_Holy_Heal" end
function _G.GetNumMacros() return 2, 1 end
function _G.GetMacroInfo(i) return "宏" .. tostring(i), "Interface\\Icons\\INV_Misc_Note_01", "x" end
W.bags = {
  [0] = {
    [1] = { tex = "Interface\\Icons\\INV_Misc_Gem_Soul", link = "|cff9d9d9d|Hitem:6265:0:0:0|h[灵魂碎片]|h|r", count = 3 },
    [2] = { tex = "Interface\\Icons\\INV_Misc_Gem_Soul", link = "|cff9d9d9d|Hitem:6265:0:0:0|h[灵魂碎片]|h|r", count = 3 },
    [3] = { tex = "Interface\\Icons\\INV_Misc_Gem_Soul", link = "|cff9d9d9d|Hitem:6265:0:0:0|h[灵魂碎片]|h|r", count = 3 },
    [4] = { tex = "Interface\\Icons\\INV_Misc_Gem_Soul", link = "|cff9d9d9d|Hitem:6265:0:0:0|h[灵魂碎片]|h|r", count = 3 },
  },
  [1] = {
    [1] = { tex = "Interface\\Icons\\INV_Misc_Note_01", link = "|cffffffff|Hitem:1:0:0:0|h[信纸]|h|r", count = 1 },
    [2] = { tex = "Interface\\Icons\\INV_Misc_Note_01", link = "|cffffffff|Hitem:1:0:0:0|h[信纸]|h|r", count = 1 },
  },
}

function _G.GetContainerNumSlots(bag)
  if bag == 0 then return 16 end
  if bag == 1 then return 16 end
  if bag == -2 then return W.keyring and 32 or 0 end
  return 0
end
function _G.GetContainerItemInfo(bag, slot)
  local b = W.bags[bag]
  local it = b and b[slot]
  if it then return it.tex, it.count, false, it.q or 0 end
  return nil
end
function _G.GetContainerItemLink(bag, slot)
  local b = W.bags[bag]
  local it = b and b[slot]
  return it and it.link or nil
end
function _G.GetContainerNumFreeSlots(bag)
  local b = W.bags[bag] or {}
  local n = (bag == 0 or bag == 1) and 16 or 0
  local used = 0
  local i
  for i = 1, n do if b[i] then used = used + 1 end end
  return n - used, 0
end
function _G.TargetNearestEnemy() W.target = true end
function _G.GetMoney() return 1234567 end
function _G.GetNumLootItems() return W.lootN or 0 end
function _G.GetLootSlotInfo(i)
  local l = W.loot and W.loot[i]
  if l then return l.tex, l.name, l.qty, 1 end
  return nil
end
function _G.LootSlot(i)
  if W.loot then W.looted = (W.looted or 0) + 1; table.remove(W.loot, i); W.lootN = #W.loot end
end
function _G.CloseLoot() W.lootN = 0 end
function _G.GetItemInfo(link)
  if type(link) ~= "string" then return nil end
  if string.find(link, "紫装", 1, true) then
    return "紫装", link, 4, 60, 1, "护甲", "皮甲", 1, "INVTYPE_CHEST", "Interface\\Icons\\X", 100
  end
  if string.find(link, "食谱", 1, true) then
    return "食谱", link, 1, 10, 1, "配方", "烹饪", 1, "", "Interface\\Icons\\X", 100
  end
  if string.find(link, "空皮包", 1, true) then
    return "空皮包", link, 1, 10, 1, "容器", "背包", 1, "INVTYPE_BAG", "Interface\\Icons\\X", 100
  end
  if string.find(link, "轻皮", 1, true) then
    return "轻皮", link, 1, 10, 1, "材料", "制皮", 20, "", nil, 5
  end
  return "物品", link, 1, 1, 1, "杂项", "", 1, "", nil, 0
end
function _G.GetInventoryItemLink(unit, slot)
  if W.playerEquip and W.playerEquip[slot] then return W.playerEquip[slot] end
  return nil
end
function _G.StaticPopup_Show(which) W.poped = which; return 1 end
function _G.UnitCastingInfo(unit)
  local c = W.cast and W.cast[unit]
  if not c then return nil end
  return c.name, nil, c.tex, c.startT * 1000, c.stopT * 1000, false
end
function _G.UnitChannelInfo() return nil end
function _G.UnitClass(unit)
  local c = W.classes and W.classes[unit]
  if c then return c, c end
  if unit == "player" and W.classToken then return W.classLocal or W.classToken, W.classToken end
  return nil, nil
end
function _G.UseContainerItem(bag, slot) W.usedItem = (W.usedItem or 0) + 1; W.lastUse = bag .. ":" .. slot end
function _G.CursorHasItem() return W.cursorItem ~= nil end
function _G.ChatEdit_InsertLink(link) W.linked = link end
_G.MerchantFrame = { IsShown = function() return W.merchant == true end }

return W
