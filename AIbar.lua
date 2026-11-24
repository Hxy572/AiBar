-- AIbar 7.0 核心：自绘按钮（黑铁圆角边框）
AIbar = AIbar or {}
local U = AIbar

AIbarDB = AIbarDB or {}
-- 角色级存档：有些客户端只认 SavedVariablesPerCharacter（toc 里已声明），
-- 账号级 AIbarDB 不落盘时靠它兜底。
AIbarDBC = AIbarDBC or {}
local DB = AIbarDB
local D = { cols = 6, icon = 72, gap = 8, skin = false,
            move = true, bar2 = false, bar3 = false, bar4 = false, curBar = 1, classBar = true, classScale = 1,
            jumpOn = true, targetOn = true, utilScale = 1, jumpScale = 1, targetScale = 1, bagIcon = 44, bagCols = 10, bagRows = 5, castOn = true, castScale = 1, castW = 240, castH = 18, castReverse = false, castTW = 240, castTH = 18, castTScale = 1, castTReverse = false, castLock = false, modBar = true, modCast = true, modBag = true, modRes = true, modUtil = true,
            petBar = true, petScale = 1,
            resOn = true, resScale = 1, resWidth = 200, resBg = true, resLocked = false, resCombatOnly = false, resAlpha = 1, 
            resOrder = { "power", "combo", "self", "target", "pet", "shard" },
            resH = { power = 12, combo = 14, self = 11, target = 11, pet = 11, shard = 14 },
            resPower = true, resCombo = true, resSelf = true, resTarget = true, resSwing = true, 
            resPet = true, resShard = true }
for k, v in pairs(D) do if DB[k] == nil then DB[k] = v end end

local KEYS = { "cols", "icon", "gap", "skin", "move", "bar2", "bar3", "bar4", "curBar", "bars", "bar2Anchor", "bar3Anchor", "bar4Anchor",
               "rlButton", "cfgBtn", "anchor", "rlAnchor", "cfgAnchor",
               "classBar", "classScale", "classAnchor",
               "jumpOn", "targetOn", "utilScale", "jumpScale", "targetScale", "jumpAnchor", "targetAnchor", "bagIcon", "bagCols", "bagRows", "bagAnchor", "castOn", "castScale", "castW", "castH", "castReverse", "castTW", "castTH", "castTScale", "castTReverse", "castLock", "modBar", "modCast", "modBag", "modRes", "modUtil", "castSelfAnchor", "castTargetAnchor",
               "petBar", "petScale", "petAnchor",
               "resOn", "resScale", "resWidth", "resBg", "resLocked", "resCombatOnly", "resAlpha", "resAnchor", "resOrder", "resH",
               "resPower", "resSwing", "resCombo", "resSelf", "resTarget",
               "resPet", "resShard", "nudgeSel", "utilAnchor", "finCache", "pcMode" }

-- 平台识别：安卓触屏客户端提供 EVAL_RMB_BTN（长按/右键换算）；电脑端没有。
-- DB.pcMode = "pc" / "touch" 可手动覆盖，nil 表示自动。
-- 主块局部变量已到 200 上限，这里用 U 表上的函数，别用 local function
function U.IsTouchClient()
  local touch = (type(EVAL_RMB_BTN) == "function")
  if DB.pcMode == "pc" then return false end
  if DB.pcMode == "touch" then return true end
  return touch
end
U.TouchMode = U.IsTouchClient()

local COUNT = 12

-- 设备自适应系数（以 768 高度为基准）
local DEV_H = 768
local DEV_S = 1
do
  local ok, h = pcall(function() return UIParent:GetHeight() end)
  if ok and type(h) == "number" and h > 200 then
    DEV_S = h / DEV_H
    if DEV_S < 0.8 then DEV_S = 0.8 end
    if DEV_S > 1.6 then DEV_S = 1.6 end
  end
end

local KX, KY = 1.5, 1.5

local function FS()
  return DEV_S
end
local G = getglobal

-- ---------- 拖动（统一实现：按下记录、逐帧跟随、松开或抬手落位） ----------
U.PendingClamp = nil
-- 几何布局只在配置变化/定时兜底时重排，避免每 0.5 秒白算一遍
U.Geo = true
local DRAGS = {}

local function anchorOf(f)
  local pt, relf, rp, x, y = f:GetPoint(1)
  return pt or "BOTTOM", relf or UIParent, rp or pt or "BOTTOM", x or 0, y or 0
end

local function endDrag(st)
  if not st.on then return end
  st.on = false
  local pt, relf, rp, x, y = anchorOf(st.target)
  -- 只有真的拖动过才保存：单击也会走到这里，重复换算坐标会让组件一点点跑位
  if st.drop and (st.moved or 0) >= 2 then st.drop(pt, relf, rp, x, y, st.moved or 0) end
  -- 位置一落手就落盘：手机端随时可能被系统切掉，不能只靠 5 秒一次的定时保存
  if U.Save then U.Save(true) end
  -- 不做自动回位/吸附：拖到哪就停哪（用户要求）。
  -- 只有登录时第一次摆位会做越界修正，之后一律不再自动移动组件。
end

function U.IsDragging(f)
  local i
  for i = 1, #DRAGS do
    local st = DRAGS[i]
    if st.on and st.target == f then return true end
  end
  return false
end

-- source 收鼠标事件，target 是被移动的框体
-- cfg: canDrag() / drop(pt,relf,rp,x,y,moved) / onClick() / clamp=false
function U.MakeDraggable(target, source, cfg)
  cfg = cfg or {}
  local st = { target = target, on = false, drop = cfg.drop, clamp = cfg.clamp,
               noClamp = cfg.noClamp }
  DRAGS[#DRAGS + 1] = st

  source:SetScript("OnMouseDown", function()
    if cfg.canDrag and not cfg.canDrag() then return end
    local cx, cy = GetCursorPosition()
    if not cx then return end
    local pt, relf, rp, x, y = anchorOf(target)
    st.on = true
    st.p, st.relf, st.rp = pt, relf, rp
    st.ox, st.oy = x, y
    st.cx, st.cy = cx, cy
    st.kx, st.ky = 1, 1
    st.lastX, st.lastY = x, y
    st.lastL, st.lastT = target:GetLeft(), target:GetTop()
    st.moved = 0
    st.idleFrom = GetTime()
    -- 拖动动作条 1 前先把挂在它身上的副条/配置按钮“摘下来”（见 U.DetachDeps）
    if cfg.onDown then pcall(cfg.onDown) end
  end)

  source:SetScript("OnMouseUp", function()
    if not st.on then return end
    local moved = st.moved or 0
    endDrag(st)
    if cfg.onClick and moved < 8 then cfg.onClick() end
  end)
  return st
end

-- 把当前屏幕位置换算成相对 UIParent 的固定锚点（BOTTOMLEFT 基准）。
-- 存成绝对坐标后，再移动动作条 1 时这些组件不会被带着走。
-- 可见区域（UI 坐标）：UIParent 和真实屏幕取并集。
-- 这个客户端的 UIParent 不等于可见画面，只看 UIParent:GetHeight() 会误判。
function U.VisibleRect()
  local uw, uh = 0, 0
  local ok, v = pcall(UIParent.GetWidth, UIParent)
  if ok and type(v) == "number" then uw = v end
  ok, v = pcall(UIParent.GetHeight, UIParent)
  if ok and type(v) == "number" then uh = v end
  if type(GetScreenWidth) == "function" and type(GetScreenHeight) == "function" then
    local sc = 1
    if UIParent.GetEffectiveScale then
      local ok2, v2 = pcall(UIParent.GetEffectiveScale, UIParent)
      if ok2 and type(v2) == "number" and v2 > 0 then sc = v2 end
    end
    local sw, sh = GetScreenWidth() / sc, GetScreenHeight() / sc
    if sw > uw then uw = sw end
    if sh > uh then uh = sh end
  end
  return uw, uh
end

function U.BakeAnchor(fr)
  if not fr then return nil end
  -- 只用 GetLeft/GetTop/GetHeight：这个客户端的 GetBottom 不可靠，
  -- 之前的版本用它取底边，结果换算出来的坐标被判成越界，位置每次登录都被打回默认。
  local L, T = fr:GetLeft(), fr:GetTop()
  if not L or not T then return nil end
  local H = fr:GetHeight() or 0
  local uL, uB = 0, 0
  local ok, v = pcall(UIParent.GetLeft, UIParent)
  if ok and type(v) == "number" then uL = v end
  -- UIParent 底边 = 顶边 - 高度；任一项取不到就按 0 算（UIParent 通常就是整块屏幕）
  local uT, uH = nil, nil
  ok, v = pcall(UIParent.GetTop, UIParent)
  if ok and type(v) == "number" then uT = v end
  ok, v = pcall(UIParent.GetHeight, UIParent)
  if ok and type(v) == "number" then uH = v end
  if uT and uH then uB = uT - uH end
  -- 存档格式和拖动保存的一致：{ 自身锚点, 参照锚点, x, y, 是否相对动作条(可空) }
  return { "BOTTOMLEFT", "BOTTOMLEFT", L - uL, (T - H) - uB }
end

function U.UpdateDrags()
  local i
  for i = 1, #DRAGS do
    local st = DRAGS[i]
    if st.on then
      -- 触摸客户端 IsMouseButtonDown 经常恒为 false，不能拿它判断松手；
      -- 改成"光标 2 秒没动"兜底，避免手指抬起后组件一直粘着
      local idleFrom = st.idleFrom or st.cx or 0
      if GetTime() - idleFrom > 2 then endDrag(st) end
      if st.on then
        local cx, cy = GetCursorPosition()
        if cx then
          -- 只有光标“真的换了位置”才刷新最后活动时间。
          -- 以前在移动分支里每帧都刷新，而 st.cx 是拖动起点、不会跟着变，
          -- 于是 dx 永远不为 0，2 秒兜底永远不触发：拖动结束不了、drop 不执行、
          -- 位置也就存不上（这就是组件和背包位置重登后消失的原因）。
          if cx ~= (st.__lcx or st.cx) or cy ~= (st.__lcy or st.cy) then
            st.__lcx, st.__lcy = cx, cy
            st.idleFrom = GetTime()
          end
          local dx, dy = cx - st.cx, cy - st.cy
          if math.abs(dx) > 600 or math.abs(dy) > 600 then
            st.cx, st.cy = cx, cy
          elseif math.abs(dx) >= 1 or math.abs(dy) >= 1 then
            st.moved = math.abs(dx) + math.abs(dy)
            local nx = st.ox + dx / (st.kx or 1)
            local ny = st.oy + dy / (st.ky or 1)
            st.target:ClearAllPoints()
            st.target:SetPoint(st.p, st.relf, st.rp, nx, ny)

            local L, T = st.target:GetLeft(), st.target:GetTop()

            -- 拖到屏幕边缘就停住：组件不能被拖出可见区域。
            -- 用可见区域（UIParent 与真实屏幕的并集）当边界，只贴边不吸附到格子。
            local fw, fh = st.target:GetWidth() or 0, st.target:GetHeight() or 0
            if not st.noClamp and L and T and fw > 0 and fh > 0 then
              local vw, vh = U.VisibleRect()
              local ax, ay = 0, 0
              if L < 0 then ax = -L
              elseif L + fw > vw then ax = vw - (L + fw) end
              if T - fh < 0 then ay = fh - T
              elseif T > vh then ay = vh - T end
              if ax ~= 0 or ay ~= 0 then
                -- 缩放系数只在合理范围内才用，估算失真时按 1 处理，避免被“推”出屏幕
                local kx, ky = st.kx or 1, st.ky or 1
                if kx < 0.8 or kx > 1.25 then kx = 1 end
                if ky < 0.8 or ky > 1.25 then ky = 1 end
                nx = nx + ax / kx
                ny = ny + ay / ky
                st.target:ClearAllPoints()
                st.target:SetPoint(st.p, st.relf, st.rp, nx, ny)
                L, T = st.target:GetLeft(), st.target:GetTop()
              end
            end
            if L and st.lastL and math.abs(nx - st.lastX) > 0.5 then
              local k = (L - st.lastL) / (nx - st.lastX)
              if k and k > 0.05 and k < 3 then st.kx = k end
            end
            if T and st.lastT and math.abs(ny - st.lastY) > 0.5 then
              local k = (T - st.lastT) / (ny - st.lastY)
              if k and k > 0.05 and k < 3 then st.ky = k end
            end
            st.lastX, st.lastY, st.lastL, st.lastT = nx, ny, L, T
          end
        end
      end
    end
  end
end

local function lowFrame(f)
  if f and f.SetFrameLevel then pcall(f.SetFrameLevel, f, 0) end
  return f
end
-- 自绘转圈冷却：48 帧扇形贴图（8×6 拼图），不依赖客户端动画接口
local CDART = "Interface\\AddOns\\AIbar\\sweep.tga"
local CDN, CDCOLS, CDROWS = 48, 8, 6

local function setCdFrame(b, rem)
  if not b.cdArt then return end
  local idx = math.floor((1 - rem) * (CDN - 1) + 0.5)
  if idx < 0 then idx = 0 elseif idx > CDN - 1 then idx = CDN - 1 end
  if b.__cdFrame == idx then return end
  b.__cdFrame = idx
  local col, row = idx % CDCOLS, math.floor(idx / CDCOLS)
  pcall(b.cdArt.SetTexCoord, b.cdArt, col / CDCOLS, (col + 1) / CDCOLS,
        row / CDROWS, (row + 1) / CDROWS)
end

local BORDER = "Interface\\AddOns\\AIbar\\border.tga"
local BORD = 4        -- 图标内缩像素（对应贴图边宽）

-- ---------- 镜像存档（手动安装插件可能不落盘） ----------
local function mirrorTable()
  local cfg = rawget(_G, "EVAL_HELP_CONFIG")
  if type(cfg) == "table" then
    if type(cfg.AIbar) ~= "table" then cfg.AIbar = {} end
    return cfg.AIbar
  end
  return nil
end

-- 存档写三处：账号级 AIbarDB、角色级 AIbarDBC、镜像表（如果客户端提供了）。
-- 哪个真的落盘就靠哪个；登录时挑版本号最大的那份读回来。
function U.OtherStores()
  local out = {}
  if type(AIbarDBC) == "table" then out[#out + 1] = AIbarDBC end
  local m = mirrorTable()
  if m then out[#out + 1] = m end
  return out
end

function U.Restore()
  local best, bestSeq = nil, DB.seq or 0
  local list = U.OtherStores()
  local i
  for i = 1, #list do
    local st = list[i]
    if type(st.seq) == "number" and st.seq > bestSeq then
      best, bestSeq = st, st.seq
    end
  end
  if not best then return end
  for i = 1, #KEYS do
    local k = KEYS[i]
    if best[k] ~= nil then DB[k] = best[k] end
  end
  DB.seq = bestSeq
end

-- 强制落盘：客户端如果提供 SaveVariables()，就能主动把存档写进文件，
-- 不用等到正常退出（手机上大多是直接杀进程，等不到写盘）。
function U.Flush(force)
  if type(SaveVariables) ~= "function" then return false end
  local now = GetTime()
  if not force and now - (U.flushT or 0) < 15 then return true end
  U.flushT = now
  pcall(SaveVariables, "AIbarDB")
  pcall(SaveVariables, "AIbarDBC")
  pcall(SaveVariables)
  return true
end

function U.Save(force)
  DB.seq = (DB.seq or 0) + 1      -- 每次保存递增，用来判断哪份存档更新
  local list = U.OtherStores()
  local i, j
  for j = 1, #list do
    local st = list[j]
    for i = 1, #KEYS do st[KEYS[i]] = DB[KEYS[i]] end
    st.seq = DB.seq
  end
  local flushed = U.Flush(force)
  U.lastFlushed = flushed
end

-- 报错上报：脚本里一旦报错，客户端会把错误交给全局错误处理器。
-- 包一层，把跟 AIbar 有关的错误直接打到聊天框，省得只能靠猜。
do
  local okg = pcall(function() return geterrorhandler and geterrorhandler() end)
  local orig = okg and geterrorhandler and geterrorhandler() or nil
  if type(orig) == "function" and seterrorhandler then
    local ok, err = pcall(seterrorhandler, function(msg)
      local t = tostring(msg or "")
      if string.find(t, "AIbar", 1, true) then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6666AIbar 报错|r " .. t)
      end
      return orig(msg)
    end)
  end
end

-- ---------- 页 / 潜行 ----------
-- 页缓存与潜行缓存：Page() 每格都会调用，不能每次都算
local pageNow, pageT = 1, -100
local stealthNow = false
function U.RefreshStealth()
  -- 0.2 秒缓存：结束/进入潜行时客户端会连发一串 UNIT_AURA，
  -- 每个事件都从 1 扫到 32 个 buff，在手机上纯属白花钱。
  -- 0.2 秒内的重复调用直接返回上次结果，换页最多晚 0.2 秒（下一拍一定扫到）。
  -- 时间存 U.stealthT：主块局部变量已到 200 上限，不能再加局部。
  local now = GetTime()
  if now - (U.stealthT or 0) < 0.2 then return stealthNow, false end
  U.stealthT = now
  local st = false
  if type(UnitBuff) == "function" then
    local i = 1
    while i < 32 do
      local ok, icon = pcall(UnitBuff, "player", i)
      if not ok or not icon then break end
      if type(icon) == "string" then
        local l = string.lower(icon)
        if string.find(l, "ability_stealth", 1, true) or
           string.find(l, "\\stealth", 1, true) then
          st = true
          break
        end
      end
      i = i + 1
    end
  end
  local changed = (st ~= stealthNow)
  stealthNow = st
  if changed then pageT = -100 end
  return st, changed
end


-- 客户端当前动作页（姿态/形态会切页）
local function clientPage()
  if type(CURRENT_ACTIONBAR_PAGE) == "number" then return CURRENT_ACTIONBAR_PAGE end
  if type(GetActionBarPage) == "function" then
    local ok, v = pcall(GetActionBarPage)
    if ok and type(v) == "number" then return v end
  end
  return 1
end

local followedPage = 1

local function pageHasActions(p)
  local i = 1
  while i <= 12 do
    if GetActionTexture(i + (p - 1) * 12) then return true end
    i = i + 1
  end
  return false
end

function U.Page()
  local now = GetTime()
  if now - pageT < 0.2 then return pageNow end
  pageT = now

  local p = 7
  if not stealthNow then
    -- 原版：姿态/形态由客户端切页，这里照它的页号取槽位
    p = clientPage()
    if type(p) ~= "number" or p < 1 or p > 7 then p = 1 end
    -- 该页没技能就退回第 1 页，避免整条空着（每次重算都复核）
    if p ~= 1 and not pageHasActions(p) then p = 1 end
  end
  followedPage = p
  pageNow = p
  return p
end

function U.BarCfg(n)
  DB.bars = DB.bars or {}
  local t = DB.bars[n]
  if type(t) ~= "table" then t = {}; DB.bars[n] = t end
  if type(t.cols) ~= "number" then t.cols = DB.cols or 6 end
  if type(t.icon) ~= "number" then t.icon = DB.icon or 72 end
  if type(t.gap) ~= "number" then t.gap = DB.gap or 8 end
  if t.icon < 44 then t.icon = 44 end
  if t.icon > 96 then t.icon = 96 end
  if t.gap < 0 then t.gap = 0 end
  if t.gap > 20 then t.gap = 20 end
  if type(t.slots) ~= "number" then t.slots = 12 end
  if t.slots > 12 then t.slots = 12 end
  if t.slots < 1 then t.slots = 1 end
  if t.cols < 1 then t.cols = 1 end
  if t.cols > 12 then t.cols = 12 end
  return t
end

function U.SlotOf(i) return i + (U.Page() - 1) * 12 end

-- 影袭：没有目标时自动选最近的敌人（等同于宏 /targetenemy）
function U.AutoTarget(slot)
  if not slot then return end
  if type(UnitExists) == "function" and UnitExists("target") then return end
  if type(TargetNearestEnemy) ~= "function" then return end
  local name
  if type(GetSpellName) == "function" then
    local ok, n = pcall(GetSpellName, slot, BOOKTYPE_SPELL or "spell")
    if ok then name = n end
  end
  if not name and type(GetActionText) == "function" then
    local ok2, t = pcall(GetActionText, slot)
    if ok2 then name = t end
  end
  if name and (name == "邪恶攻击" or name == "影袭" or name == "Sinister Strike") then
    pcall(TargetNearestEnemy)
    -- 不再补 AttackTarget：目标太远时客户端会每一下平砍都弹「离目标太远」，
    -- 潜行里选中远处目标时尤其明显。现在只选目标，攻击交给技能本身。
  end
end

-- ---------- 面板容器 ----------
local panel = lowFrame(CreateFrame("Frame", "AIbarPanel", UIParent))
U.panel = panel
panel:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 8)
panel:SetMovable(true)

local skinF = lowFrame(CreateFrame("Frame", "AIbarSkin", panel))
skinF:SetAllPoints(panel)
skinF:SetFrameLevel(0)
skinF:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 10,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
skinF:SetBackdropColor(0, 0, 0, 0.55)
skinF:SetBackdropBorderColor(0.55, 0.45, 0.3, 0.9)
skinF:Hide()

-- ---------- 职业栏容器 ----------
local classPanel = lowFrame(CreateFrame("Frame", "AIbarClass", UIParent))
classPanel:SetWidth(10)
classPanel:SetHeight(10)
classPanel:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 140)
U.classPanel = classPanel

-- 登录前先把原生姿态/形态栏藏掉：否则刚进游戏的头一两秒会先显示原生那排
do
  local cb0 = G("ShapeshiftBarFrame")
  if cb0 and cb0.Hide then pcall(cb0.Hide, cb0) end
  local ci
  for ci = 1, 10 do
    local b0 = G("ShapeshiftButton" .. ci)
    if b0 and b0.Hide then pcall(b0.Hide, b0) end
  end
end

local classHandle = lowFrame(CreateFrame("Button", "AIbarClassHandle", classPanel))
classHandle:SetWidth(U.TouchMode and 92 or 76)
classHandle:SetHeight(U.TouchMode and 24 or 20)
classHandle:SetPoint("BOTTOM", classPanel, "TOP", 0, 2)
classHandle:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 8,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
classHandle:SetBackdropColor(0.16, 0.15, 0.14, 0.9)
classHandle:SetBackdropBorderColor(0.45, 0.42, 0.38, 1)
local chl = classHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
chl:SetPoint("CENTER", classHandle, "CENTER")
chl:SetText("职业拖动")
pcall(function()
  local fn, sz = chl:GetFont()
  if fn then chl:SetFont(fn, (sz or 12) + (U.TouchMode and 3 or 1), "OUTLINE") end
end)
classHandle:Hide()

-- ---------- 辅助按钮（跳跃 / 选目标，各自独立） ----------
local function utilUnit(key, icon, label, fn)
  local box = lowFrame(CreateFrame("Frame", "AIbarUtil" .. key, UIParent))
  box:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300)

  local h = CreateFrame("Button", nil, box)
  h:SetWidth(U.TouchMode and 90 or 74)
  h:SetHeight(U.TouchMode and 24 or 20)
  h:SetPoint("BOTTOM", box, "TOP", 0, 2)
  h:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  h:SetBackdropColor(0.16, 0.15, 0.14, 0.9)
  h:SetBackdropBorderColor(0.45, 0.42, 0.38, 1)
  local ht = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ht:SetPoint("CENTER", h, "CENTER")
  ht:SetText(label .. "拖动")
  pcall(function()
    local fn, sz = ht:GetFont()
    if fn then ht:SetFont(fn, (sz or 12) + (U.TouchMode and 3 or 1), "OUTLINE") end
  end)
  h:Hide()

  local btn = lowFrame(CreateFrame("Button", "AIbar" .. key, box))
  btn:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
  local ic = btn:CreateTexture(nil, "ARTWORK")
  ic:SetPoint("CENTER", btn, "CENTER")
  ic:SetTexture(icon)
  btn.icon = ic
  local fr = btn:CreateTexture(nil, "OVERLAY")
  fr:SetAllPoints(btn)
  fr:SetTexture("Interface\\AddOns\\AiBar\\border.tga")
  local lb = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  lb:SetPoint("CENTER", btn, "CENTER", 0, 0)
  lb:SetText(label)
  btn.label = lb
  btn:SetScript("OnClick", fn)

  U.MakeDraggable(box, h, {
    canDrag = function() return DB.move end,
    drop = function(pt, relf, rp, x, y)
      if key == "jump" then DB.jumpAnchor = { pt, rp, x, y }
      else DB.targetAnchor = { pt, rp, x, y } end
    end,
  })

  box.handle = h
  box.btn = btn
  return box
end

-- 自绘跳跃键：优先调客户端函数，没有就点原生跳跃键（原生保持可见，不接管）
function U.DoJump()
  if type(Jump) == "function" then
    if pcall(Jump) then return true end
  end
  if type(JumpOrAscendStart) == "function" then
    if pcall(JumpOrAscendStart) then return true end
  end
  local b = G("JumpButton")
  if b then
    if b.Click and pcall(b.Click, b) then return true end
    local h = b.GetScript and b:GetScript("OnClick")
    if h and pcall(h) then return true end
  end
  return false
end

local boxJump = utilUnit("jump", "Interface\\Icons\\Ability_Rogue_Sprint", "跳", function()
  U.DoJump()
end)

local boxTarget = utilUnit("target", "Interface\\Icons\\Ability_Hunter_SniperShot", "目", function()
  if not UnitExists("target") and type(TargetNearestEnemy) == "function" then
    pcall(TargetNearestEnemy)
  end
end)

-- ---------- 职业资源监控（模块化） ----------
local resF = lowFrame(CreateFrame("Frame", "AIbarRes", UIParent))
resF:SetFrameStrata("BACKGROUND")
resF:SetWidth(200)
resF:SetHeight(90)
resF:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 400)
resF:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 10,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
resF:SetBackdropColor(0.06, 0.06, 0.06, 0.85)
resF:SetBackdropBorderColor(0.45, 0.42, 0.38, 1)

local powerBg = resF:CreateTexture(nil, "BACKGROUND")
powerBg:SetTexture(0.15, 0.15, 0.15, 0.8)

local powerBar = resF:CreateTexture(nil, "ARTWORK")
powerBar:SetHeight(12)
powerBar:SetWidth(10)
powerBar:SetTexture(0.35, 0.75, 0.45, 0.85)

local pips, pipBgs = {}, {}
local pi
for pi = 1, 5 do
  local bg = resF:CreateTexture(nil, "OVERLAY")
  bg:SetWidth(34); bg:SetHeight(14)
  bg:SetTexture(0.85, 0.68, 0.25, 0.95)
  pipBgs[pi] = bg

  local t = resF:CreateTexture(nil, "OVERLAY")
  t:SetWidth(32); t:SetHeight(12)
  t:SetTexture(0.18, 0.18, 0.18, 0.9)
  pips[pi] = t
end

local selfBg = resF:CreateTexture(nil, "BACKGROUND")
selfBg:SetWidth(150); selfBg:SetHeight(11)
selfBg:SetTexture(0.15, 0.15, 0.15, 0.8)
local selfBar = resF:CreateTexture(nil, "ARTWORK")
selfBar:SetHeight(11); selfBar:SetWidth(10)
selfBar:SetTexture(0.25, 0.80, 0.35, 0.95)

local targetBg = resF:CreateTexture(nil, "BACKGROUND")
targetBg:SetWidth(150); targetBg:SetHeight(11)
targetBg:SetTexture(0.15, 0.15, 0.15, 0.8)
local targetBar = resF:CreateTexture(nil, "ARTWORK")
targetBar:SetHeight(11); targetBar:SetWidth(10)
targetBar:SetTexture(0.90, 0.30, 0.25, 0.95)

local shardBg = resF:CreateTexture(nil, "BACKGROUND")
shardBg:SetWidth(150); shardBg:SetHeight(14)
shardBg:SetTexture(0.15, 0.15, 0.15, 0.8)
local shardBar = resF:CreateTexture(nil, "ARTWORK")
shardBar:SetHeight(14); shardBar:SetWidth(10)
shardBar:SetTexture(0.60, 0.35, 0.85, 0.95)
local petBg = resF:CreateTexture(nil, "BACKGROUND")
petBg:SetWidth(150); petBg:SetHeight(11)
petBg:SetTexture(0.15, 0.15, 0.15, 0.8)
local petBar = resF:CreateTexture(nil, "ARTWORK")
petBar:SetHeight(11); petBar:SetWidth(10)
petBar:SetTexture(0.85, 0.65, 0.20, 0.95)

-- 平砍计时：进入战斗/每次挥砍都重置起点；用实测的两次挥砍间隔当周期
local swingT, swingOn, swingSpeed, gotHit = 0, false, nil, false
local swingCount, swingSource = 0, "-"
-- 最近 5 次挥砍间隔，用来实测人物攻速（比 UnitAttackSpeed 可靠）
local swingIv, swingIvN = {}, 0
local function pushInterval(iv)
  swingIvN = swingIvN + 1
  swingIv[(swingIvN - 1) % 5 + 1] = iv
  local sum, cnt, i = 0, 0
  for i = 1, 5 do
    local v = swingIv[i]
    if v then sum = sum + v; cnt = cnt + 1 end
  end
  if cnt > 0 then swingSpeed = sum / cnt end
end
local swingEv = CreateFrame("Frame")
swingEv:RegisterEvent("PLAYER_ENTER_COMBAT")
swingEv:RegisterEvent("PLAYER_LEAVE_COMBAT")
swingEv:RegisterEvent("UNIT_ATTACK")
swingEv:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
swingEv:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
swingEv:SetScript("OnEvent", function()
  if event == "PLAYER_LEAVE_COMBAT" then
    swingOn = false
    swingT = GetTime()
    return
  end
  if event == "UNIT_ATTACK" then
    -- 全单位的攻击事件，别被目标的攻击重置
    if arg1 ~= nil and arg1 ~= "player" then return end
    -- 已经有命中/未命中事件时，忽略"开始攻击"，否则一刀会被重置两次
    if gotHit then return end
  elseif event == "CHAT_MSG_COMBAT_SELF_HITS" or event == "CHAT_MSG_COMBAT_SELF_MISSES" then
    gotHit = true
  end
  local now = GetTime()
  if swingOn and (now - swingT) < 0.15 then return end
  if swingOn and swingT > 0 then
    local iv = now - swingT
    if iv > 0.4 and iv < 6 then pushInterval(iv) end
  end
  swingT = now
  swingOn = true
  swingCount = swingCount + 1
  if event == "CHAT_MSG_COMBAT_SELF_HITS" or event == "CHAT_MSG_COMBAT_SELF_MISSES" then
    swingSource = "命中"
  else
    swingSource = "攻击"
  end
end)

local swingBg = resF:CreateTexture(nil, "BACKGROUND")
swingBg:SetWidth(150); swingBg:SetHeight(10)
swingBg:SetTexture(0.15, 0.15, 0.15, 0.8)
local swingBar = resF:CreateTexture(nil, "ARTWORK")
swingBar:SetHeight(10); swingBar:SetWidth(10)
swingBar:SetTexture(1, 1, 1, 0.95)

local DEFAULT_ORDER = { "power", "swing", "combo", "self", "target", "pet", "shard" }
local DEFAULT_H = { power = 12, swing = 10, combo = 14, self = 11, target = 11, pet = 11, shard = 14 }

function U.FixResData()
  if type(DB.resOrder) ~= "table" or #DB.resOrder < 7 then
    DB.resOrder = {}
    local i
    for i = 1, #DEFAULT_ORDER do DB.resOrder[i] = DEFAULT_ORDER[i] end
  end
  if type(DB.resH) ~= "table" then DB.resH = {} end
  local k, v
  for k, v in pairs(DEFAULT_H) do
    if type(DB.resH[k]) ~= "number" then DB.resH[k] = v end
  end
end

local BGS = { power = powerBg, swing = swingBg, self = selfBg, target = targetBg, pet = petBg, shard = shardBg }
local BARS = { power = powerBar, swing = swingBar, self = selfBar, target = targetBar, pet = petBar, shard = shardBar }

function U.LayoutRes()
  U.FixResData()
  local W = (DB.resWidth or 200) * FS()
  local barW = W - 10
  resF:SetWidth(W)

  local order = DB.resOrder or DEFAULT_ORDER
  local H = DB.resH or {}
  local _, cls = UnitClass("player")
  cls = cls and string.lower(cls) or ""
  local y = -4
  local on = {
    power = DB.resPower,
    swing = DB.resSwing,
    combo = DB.resCombo and (cls == "rogue" or cls == "druid"),
    self = DB.resSelf,
    target = DB.resTarget and UnitExists("target") and true or false,
    pet = DB.resPet and UnitExists("pet") and true or false,
    shard = DB.resShard and cls == "warlock",
  }

  local i, j
  for i = 1, #order do
    local k = order[i]
    local h = H[k] or 12
    local bg, bar = BGS[k], BARS[k]
    if on[k] then
      if k == "combo" then
        -- 5 段 + 4 个 6px 间隔正好铺满整条
        local gap = 6
        local pw = math.max(6, math.floor((barW - gap * 4) / 5))
        local step = pw + gap
        for j = 1, 5 do
          local ox = 5 + (j - 1) * step
          pipBgs[j]:Show()
          pipBgs[j]:SetWidth(pw); pipBgs[j]:SetHeight(h)
          pipBgs[j]:ClearAllPoints()
          pipBgs[j]:SetPoint("TOPLEFT", resF, "TOPLEFT", ox, y)
          pips[j]:Show()
          pips[j]:SetWidth(pw - 2); pips[j]:SetHeight(h - 2)
          pips[j]:ClearAllPoints()
          pips[j]:SetPoint("TOPLEFT", resF, "TOPLEFT", ox + 1, y - 1)
        end
      else
        if bg then
          bg:Show()
          bg:SetWidth(barW); bg:SetHeight(h)
          bg:ClearAllPoints(); bg:SetPoint("TOPLEFT", resF, "TOPLEFT", 5, y)
        end
        if bar then
          bar:Show()
          bar:SetHeight(h)
          bar:ClearAllPoints(); bar:SetPoint("TOPLEFT", resF, "TOPLEFT", 5, y)
        end
      end
      y = y - h - 4
    else
      if bar then bar:Hide() end
      if bg then bg:Hide() end
      if k == "combo" then
        for j = 1, 5 do pips[j]:Hide(); pipBgs[j]:Hide() end
      end
    end
  end

  resF:SetHeight(math.max(24, -y + 4))
end

-- ---------- 按钮 ------------ ---------- 按钮 ------------ ---------- 独立经验条 ----------
-- ---------- 按钮 ----------
U.buttons = {}
local cachedTex, cachedCnt, cachedMacro = {}, {}, {}

-- 清缓存时给个哨兵值：nil 表示"新的一格也是空的"，会导致图标清不掉
local function resetTexCache()
  local i
  cachedTex, cachedCnt, cachedMacro = {}, {}, {}
  for i = 1, 12 do cachedTex[i] = false end
end
local cachedCd = {}

local i
for i = 1, COUNT do
  local b = lowFrame(CreateFrame("Button", "AIbarBtn" .. i, panel))
  b.idx = i
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.icon:SetWidth(54)
  b.icon:SetHeight(54)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  b.frameArt = b:CreateTexture(nil, "OVERLAY")
  b.frameArt:SetAllPoints(b)
  b.frameArt:SetTexture(BORDER)

  b.cdArt = b:CreateTexture(nil, "ARTWORK")
  b.cdArt:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.cdArt:SetTexture(CDART)
  b.cdArt:SetWidth(48)
  b.cdArt:SetHeight(48)
  b.cdArt:Hide()

  local cdF = CreateFrame("Frame", nil, b)
  cdF:SetAllPoints(b)
  b.cd = cdF:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  b.cd:SetPoint("CENTER", cdF, "CENTER", 0, 0)
  b.cd:SetText("")
  pcall(function()
    local fn, sz = b.cd:GetFont()
    if fn then b.cd:SetFont(fn, (sz or 14) + 2, "OUTLINE") end
  end)

  b.macro = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.macro:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)

  b.count = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.count:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -3)

  b.empty = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.empty:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.empty:SetText("")


  if b.RegisterForClicks then
    pcall(b.RegisterForClicks, b, "LeftButtonUp", "RightButtonUp")
  end
  b:SetScript("OnMouseDown", function()
    this.downT = GetTime()
  end)
  b:SetScript("OnClick", function()
    local held = this.downT and (GetTime() - this.downT) or 0
    this.downT = nil
    if this.suppress then this.suppress = nil return end
    local btn = arg1
    if type(EVAL_RMB_BTN) == "function" then
      local okb, vb = pcall(EVAL_RMB_BTN, btn)
      if okb and type(vb) == "string" and vb ~= "" then btn = vb end
    end
    local a = U.SlotOf(this.idx)
    -- 右键或长按 3 秒 = 换技能；空槽左键也是换技能
    if btn == "RightButton" or (U.TouchMode and held > 3) then
      U.OpenPicker(a)
      return
    end
    if GetActionTexture(a) then
      UseAction(a, 0)
    else
      U.OpenPicker(a)
    end
  end)
  b:SetScript("OnEnter", function()
    local a = U.SlotOf(this.idx)
    if GetActionTexture(a) then
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetAction(a)
    end
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  U.buttons[i] = b
end

-- ---------- 布局 ----------
local lastSig, lastSkin

local function layout()
  local cfg = U.BarCfg(1)
  local cols = cfg.cols
  local slots = cfg.slots
  local m = FS()
  local icon = cfg.icon * m
  local cell = icon + cfg.gap * m
  local rows = math.ceil(slots / cols)
  panel:SetWidth(cols * cell + 4)
  panel:SetHeight(rows * cell + 4)
  panel:ClearAllPoints()
  if DB.anchor then
    panel:SetPoint(DB.anchor[1], UIParent, DB.anchor[2], DB.anchor[3], DB.anchor[4])
  else
    panel:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 8)
  end
  local rows = math.max(1, math.ceil(slots / cols))
  local k
  for k = 1, COUNT do
    local b = U.buttons[k]
    local col = (k - 1) % cols
    -- 从下往上：第 1 格在左下角
    local row = rows - 1 - math.floor((k - 1) / cols)
    if k > slots then b:Hide() else b:Show() end
    b:SetWidth(icon)
    b:SetHeight(icon)
    b.icon:SetWidth(icon - BORD * 2)
    b.icon:SetHeight(icon - BORD * 2)
    if b.cdArt then
      b.cdArt:SetWidth(icon - BORD * 2)
      b.cdArt:SetHeight(icon - BORD * 2)
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", panel, "TOPLEFT", 5 + col * cell, -(5 + row * cell))
  end
end

local function utf8sub(str, n)
  local i, count = 1, 0
  while i <= string.len(str) and count < n do
    local c = string.byte(str, i)
    if c >= 240 then i = i + 4
    elseif c >= 224 then i = i + 3
    elseif c >= 192 then i = i + 2
    else i = i + 1 end
    count = count + 1
  end
  if i > string.len(str) then return str end
  if n <= 1 then return string.sub(str, 1, i - 1) end
  return string.sub(str, 1, i - 1) .. ".."
end

-- ---------- 额外动作条 2~4（自绘，样式同第一条） ----------
U.extraBars = {}

local function makeExtraButton(parent, slot, name)
  local b = lowFrame(CreateFrame("Button", name, parent))
  b.slot = slot
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local fr = b:CreateTexture(nil, "OVERLAY")
  fr:SetAllPoints(b); fr:SetTexture(BORDER)

  b.cdArt = b:CreateTexture(nil, "ARTWORK")
  b.cdArt:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.cdArt:SetTexture(CDART)
  b.cdArt:Hide()

  local cdF = CreateFrame("Frame", nil, b)
  cdF:SetAllPoints(b)
  b.cd = cdF:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  b.cd:SetPoint("CENTER", cdF, "CENTER", 0, 0)
  b.cd:SetText("")
  pcall(function()
    local fn, sz = b.cd:GetFont()
    if fn then b.cd:SetFont(fn, (sz or 14) + 2, "OUTLINE") end
  end)
  b.cnt = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.cnt:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -3)
  b.empty = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.empty:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.macro = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.macro:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  if b.RegisterForClicks then
    pcall(b.RegisterForClicks, b, "LeftButtonUp", "RightButtonUp")
  end
  b:SetScript("OnMouseDown", function()
    this.downT = GetTime()
  end)
  b:SetScript("OnClick", function()
    local held = this.downT and (GetTime() - this.downT) or 0
    this.downT = nil
    local btn = arg1
    if type(EVAL_RMB_BTN) == "function" then
      local ok, v = pcall(EVAL_RMB_BTN, btn)
      if ok and type(v) == "string" and v ~= "" then btn = v end
    end
    if btn == "RightButton" or (U.TouchMode and held > 3) then U.OpenPicker(this.slot); return end
    if not GetActionTexture(this.slot) then U.OpenPicker(this.slot); return end
    U.AutoTarget(this.slot)
    UseAction(this.slot)
  end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetAction(this.slot)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

local function buildExtra(n)
  local fr = lowFrame(CreateFrame("Frame", "AIbarExtra" .. n, UIParent))
  fr.buttons = {}

  local h = CreateFrame("Button", "AIbarExtraHandle" .. n, fr)
  h:SetWidth(U.TouchMode and 100 or 84); h:SetHeight(U.TouchMode and 24 or 20)
  h:SetPoint("BOTTOM", fr, "TOP", 0, 2)
  h:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  h:SetBackdropColor(0.16, 0.15, 0.14, 0.9)
  h:SetBackdropBorderColor(0.45, 0.42, 0.38, 1)
  local ht = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ht:SetPoint("CENTER", h, "CENTER")
  ht:SetText(n .. "拖动")
  pcall(function()
    local fn, sz = ht:GetFont()
    if fn then ht:SetFont(fn, (sz or 12) + (U.TouchMode and 3 or 1), "OUTLINE") end
  end)
  h:Hide()
  h:Hide()
  U.MakeDraggable(fr, h, {
    canDrag = function() return DB.move end,
    drop = function(pt, relf, rp, x, y)
      -- 存成屏幕绝对坐标：之后移动动作条 1 时副条不再跟着跑
      -- 直接存当前锚点（和动作条 1 一样的存法）：不再二次换算坐标，
      -- 避免换算误差让副条被“推”到屏幕外
      DB["bar" .. n .. "Anchor"] = { pt, rp, x, y, relf == panel and "panel" or nil }
    end,
  })
  fr.handle = h

  local sk = lowFrame(CreateFrame("Frame", "AiBarExtraSkin" .. n, fr))
  sk:SetAllPoints(fr)
  sk:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  sk:SetBackdropColor(0, 0, 0, 0.55)
  sk:SetBackdropBorderColor(0.55, 0.45, 0.3, 0.9)
  sk:Hide()
  fr.skinF = sk
  local k
  for k = 1, COUNT do
    local slot = (n - 1) * 12 + k
    fr.buttons[k] = makeExtraButton(fr, slot, "AIbarExtra" .. n .. "B" .. k)
  end
  return fr
end

function U.ApplyExtra()
  local m = FS()

  local n
  for n = 2, 4 do
    local fr = U.extraBars[n]
    local onOff = DB["bar" .. n]
    if onOff then
      if not fr then fr = buildExtra(n); U.extraBars[n] = fr end
      local cfg = U.BarCfg(n)
      local size = cfg.icon * m
      local gap = cfg.gap * m
      local cell = size + gap
      local cols = cfg.cols
      local slots = cfg.slots
      local rows = math.ceil(slots / cols)
      fr:Show()
      fr:SetWidth(cols * cell + 4)
      fr:SetHeight(rows * cell + 4)
      if not U.IsDragging(fr) then
        fr:ClearAllPoints()
        local anch = DB["bar" .. n .. "Anchor"]
        if anch then
          local rel = (anch[5] == "panel") and panel or UIParent
          fr:SetPoint(anch[1], rel, anch[2], anch[3], anch[4])
          -- 老存档：相对动作条 1 的锚点，就地换成绝对坐标，以后不再联动
          if anch[5] == "panel" then
            local ba = U.BakeAnchor(fr)
            if ba then
              fr:ClearAllPoints()
              fr:SetPoint(ba[1], UIParent, ba[2], ba[3], ba[4])
              DB["bar" .. n .. "Anchor"] = ba
            end
          end
        else
          -- 默认贴动作条上沿，不写档；拖过一次就变成绝对坐标
          fr:SetPoint("BOTTOM", panel, "TOP", 0, 8 + (n - 2) * (rows * cell + 14))
        end
        if DB.move then
          fr.handle:Show()
          U.PlaceHandle(fr.handle, fr)
        else
          fr.handle:Hide()
        end
        if DB.skin then fr.skinF:Show() else fr.skinF:Hide() end
      end
      local k
      for k = 1, COUNT do
        local b = fr.buttons[k]
        local col = (k - 1) % cols
        local rows = math.max(1, math.ceil(slots / cols))
        local row = rows - 1 - math.floor((k - 1) / cols)
        if k > slots then b:Hide() else b:Show() end
        b:SetWidth(size)
        b:SetHeight(size)
        b.icon:SetWidth(size - BORD * 2)
        b.icon:SetHeight(size - BORD * 2)
        if b.cdArt then
          b.cdArt:SetWidth(size - BORD * 2)
          b.cdArt:SetHeight(size - BORD * 2)
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", fr, "TOPLEFT", 5 + col * cell, -(5 + row * cell))
      end
    elseif fr then
      fr:Hide()
    end
  end
end

-- 第 2~4 条（副条）刷新。0.3 秒一次，但分两档：
--   快档（每次）：冷却数字/扇形、四态染色
--   慢档（1 秒）：图标、空格编号、宏名、物品数量
-- 图标只在换技能时变，客户端会发 ACTIONBAR_SLOT_CHANGED，事件里立刻补一次 updateExtra；
-- 所以慢档 1 秒只是兜底。空格子直接跳过可用性/距离/冷却查询（手机上最贵的一块）。
local function updateExtra()
  local now = GetTime()
  local n
  for n = 2, 4 do
    local fr = U.extraBars[n]
    if fr and fr:IsShown() then
      if now >= (fr.__nextTxt or 0) then
        fr.__nextTxt = now + 1
        local k
        for k = 1, COUNT do
          local b = fr.buttons[k]
          local tex = GetActionTexture(b.slot)
          if tex ~= b.lastTex then
            b.lastTex = tex
            if tex then
              if b.__texPath ~= tex then
                b.__texPath = tex
                b.icon:SetTexture(tex)
              end
              b.icon:Show()
            else
              b.icon:Hide()   -- 同主条：空格子不清纹理，切回时不用重新加载
            end
          end
          local emptyTxt = tex and "" or ("|cff777777" .. ((b.slot - 1) % 12 + 1) .. "|r")
          if b.__emptyT ~= emptyTxt then b.__emptyT = emptyTxt; b.empty:SetText(emptyTxt) end

          local mt = ""
          if type(GetActionText) == "function" then
            local t = GetActionText(b.slot)
            if type(t) == "string" and t ~= "" then mt = utf8sub(t, 6) end
          end
          if b.macroLast ~= mt then
            b.macroLast = mt
            b.macro:SetText(mt)
            if mt == "" then b.macro:Hide() else b.macro:Show() end
          end

          local c = GetActionCount(b.slot)
          local cs = (c and c > 1) and tostring(c) or ""
          if b.cntLast ~= cs then b.cntLast = cs; b.cnt:SetText(cs) end
        end
      end
      local k
      for k = 1, COUNT do
        local b = fr.buttons[k]
        local tex = b.lastTex

        if tex then
          U.TintIcon(b, U.ActionState(b.slot, tex))
          local st, du = GetActionCooldown(b.slot)
          local left = 0
          if st and du and du > 0 and st > 0 then
            left = st + du - now
            if left < 0 then left = 0 end
          end
          local txt = ""
          if left > 0 then
            if left >= 60 then txt = math.floor(left / 60) .. "m"
            else txt = string.format("%.1f", left) end
          end
          if b.__cdT ~= txt then b.__cdT = txt; b.cd:SetText(txt) end
          if left > 0 then b.__cs, b.__cd = st, du
          else b.__cs, b.__cd = nil, nil end
        else
          -- 空格子：不查 IsUsableAction / IsActionInRange / GetActionCooldown
          U.TintIcon(b, "ok")
          if b.__cdT ~= "" then b.__cdT = ""; b.cd:SetText("") end
          b.__cs, b.__cd = nil, nil
        end
      end
    end
  end
end

local lastPage = 0

-- light=true：只换本页 12 格的图标/文字/数量，跳过宠物条、职业条、副条越界回位、
-- 拖动把手这些重排。进出潜行时用它：那一刻只需要把动作条换过来，
-- 顺手把所有组件重算一遍在手机上会明显顿一下。重排留给 2 秒的整刷。
function U.Refresh(light)
  local rt0 = GetTime()
  local an = DB.anchor
  local cfg1 = U.BarCfg(1)
  local sig = tostring(cfg1.cols) .. "x" .. tostring(cfg1.slots) .. "|" ..
              cfg1.icon .. "|" .. cfg1.gap .. "|" ..
              (an and (tostring(an[3]) .. "," .. tostring(an[4])) or "d")
  if sig ~= lastSig then lastSig = sig; layout() end

  if not light then
  if U.Geo then
    U.Geo = false
    U.ApplyExtra()
    U.ApplyRes()
    U.ApplyUtil()
  end

  -- 第 2~4 条:存档坐标若在屏幕外,清掉并回到默认位置。
  -- 只在启动时做一次；进入游戏之后的拖动一律不吸附、不回位。
  local nb
  for nb = 2, 4 do
    if not U.LayoutReady then
    local fr = U.extraBars[nb]
    if fr and fr:IsShown() and DB["bar" .. nb .. "Anchor"] and not U.IsDragging(fr) then
      local L, T = fr:GetLeft(), fr:GetTop()
      local W = fr:GetWidth() or 1
      local H = fr:GetHeight() or 1
      local UW, UH = U.VisibleRect()
      local M = 24
      if not L or not T or L < -M or T > UH + M or L + W > UW + M or T - H < -M then
        DB["bar" .. nb .. "Anchor"] = nil
        fr:ClearAllPoints()
        fr:SetPoint("BOTTOM", panel, "TOP", 0, 8 + (nb - 2) * (H + 14))
      end
    end
    end
  end
  U.ApplyPet()
  U.ApplyClassBar()
  if DB.move then U.PlaceHandle(G("AIbarHandle"), panel) end
  if lastSkin ~= DB.skin then
    lastSkin = DB.skin
    if DB.skin then skinF:Show() else skinF:Hide() end
  end
  end
  local rt1 = GetTime()
  local p = U.Page()
  if p ~= lastPage then lastPage = p; resetTexCache() end
  -- /abc icons 关掉时完全不碰图标（测试换页卡顿是不是贴图引起的）
  if U.stSkip then return end
  local base = (p - 1) * 12   -- 本页起始槽位：循环里直接算，避免 12 次 U.Page()

  local j
  for j = 1, COUNT do
    local b = U.buttons[j]
    local a = j + base
    local tex = GetActionTexture(a)
    if tex then
      -- 只有真的换了纹理才重新 SetTexture
      if b.__texPath ~= tex then
        b.__texPath = tex
        b.icon:SetTexture(tex)
      end
      b.icon:Show()
      if b.__emptyT ~= "" then b.__emptyT = ""; b.empty:SetText("") end
    else
      -- 空格子只隐藏、不清纹理：从空页（潜行第 7 页）切回来时
      -- 不用再让客户端重新加载 12 张图标，首次切回不会顿一下
      b.icon:Hide()
      local et = "|cff777777" .. j .. "|r"
      if b.__emptyT ~= et then b.__emptyT = et; b.empty:SetText(et) end
    end
    cachedTex[j] = tex
    local txt = ""
    if type(GetActionText) == "function" then
      local t = GetActionText(a)
      if type(t) == "string" and t ~= "" then txt = utf8sub(t, 6) end
    end
    if txt ~= cachedMacro[j] then
      cachedMacro[j] = txt
      b.macro:SetText(txt)
      if txt == "" then b.macro:Hide() else b.macro:Show() end
    end

    local c = GetActionCount(a)
    local cs = (c and c > 1) and tostring(c) or ""
    if cs ~= cachedCnt[j] then cachedCnt[j] = cs; b.count:SetText(cs) end
  end
  U.lastRefreshParts = (GetTime() - rt1) * 1000
end

local classHooked = false

local classRestored = false

function U.ResetClassApplied()
  U.classApplied = nil
end


local function restoreClassBar()
  if classRestored then return end
  classRestored = true
  local i
  for i = 1, 10 do
    local b = G("ShapeshiftButton" .. i)
    if b and b.__aiOrigParent then
      pcall(b.SetParent, b, b.__aiOrigParent)
      b:ClearAllPoints()
      local k
      for k = 1, #b.__aiOrigPts do
        local o = b.__aiOrigPts[k]
        pcall(b.SetPoint, b, o[1], o[2], o[3], o[4], o[5])
      end
      if b.__aiOrigW then b:SetWidth(b.__aiOrigW) end
      if b.__aiOrigH then b:SetHeight(b.__aiOrigH) end
      pcall(b.SetScale, b, 1)
      pcall(b.Show, b)
    end
  end
  local cbar = G("ShapeshiftBarFrame")
  if cbar then U.Revive(cbar) end
end

function U.ApplyClassBar()
  if not DB.classBar then
    U.classApplied = nil
    restoreClassBar()
    classPanel:Hide()
    classHandle:Hide()
    return
  end
  classRestored = false
  if U.IsDragging(classPanel) then return end
  local cbar = G("ShapeshiftBarFrame")
  -- 「职业」按钮和跳/目视觉同大：跳/目是 64 框、图标 54，这里按 54 算
  local size = 54 * (DB.classScale or 1) * FS()
  local gap = 6

  -- 原生那条（头像/展开器）直接藏掉
  if cbar then
    if cbar.Hide then pcall(cbar.Hide, cbar) end
  end

  -- 实际有多少个形态/姿态
  local nForms = 0
  if type(GetNumShapeshiftForms) == "function" then
    local ok, v = pcall(GetNumShapeshiftForms)
    if ok and type(v) == "number" then nForms = v end
  end

  local n = 0
  local i
  for i = 1, 10 do
    local b = G("ShapeshiftButton" .. i)
    if b then
      if DB.classBar and i <= nForms then
        n = n + 1
        if not b.__aiOrigParent and b:GetParent() ~= classPanel then
          b.__aiOrigParent = b:GetParent()
          b.__aiOrigPts = {}
          local np = (b.GetNumPoints and b:GetNumPoints()) or 1
          local k
          for k = 1, np do
            local pt, rl, rp, x, y = b:GetPoint(k)
            b.__aiOrigPts[k] = { pt, rl, rp, x, y }
          end
          b.__aiOrigW = b:GetWidth()
          b.__aiOrigH = b:GetHeight()
        end
        if b:GetParent() ~= classPanel then pcall(b.SetParent, b, classPanel) end
        if not b.__cdTxt then
          local cdt = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
          cdt:SetPoint("CENTER", b, "CENTER", 0, 0)
          cdt:SetText("")
          pcall(function()
            local fn, sz = cdt:GetFont()
            if fn then cdt:SetFont(fn, (sz or 14) + 2, "OUTLINE") end
          end)
          cdt:Hide()
          b.__cdTxt = cdt
          -- 没有形态冷却接口时，至少能显示 GCD
          local orig = b.GetScript and b:GetScript("OnClick")
          b:SetScript("OnClick", function()
            if orig then pcall(orig) end
            b.__gcdT = GetTime()
          end)
        end
        if b.SetFrameLevel then pcall(b.SetFrameLevel, b, 0) end
        pcall(b.Show, b)
        b:ClearAllPoints()
        local base = b.__aiOrigW or 64
        if base <= 0 then base = 64 end
        pcall(b.SetScale, b, size / base)
        b:SetPoint("TOPLEFT", classPanel, "TOPLEFT", (n - 1) * (size + gap), 0)
      else
        if b.Hide then pcall(b.Hide, b) end
      end
    end
  end

  classPanel:SetWidth(math.max(1, n * (size + gap)))
  classPanel:SetHeight(size)
  classPanel:ClearAllPoints()
  if DB.classAnchor then
    classPanel:SetPoint(DB.classAnchor[1], UIParent, DB.classAnchor[2],
                        DB.classAnchor[3], DB.classAnchor[4])
  else
    classPanel:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 140)
  end
  classPanel:SetScale(1)

  if DB.classBar and not classHooked then
    classHooked = true
    local function dropClass(pt, relf, rp, x, y)
      DB.classAnchor = { pt, rp, x, y }
    end
    U.MakeDraggable(classPanel, classPanel, { canDrag = function() return DB.move end, drop = dropClass })
    U.MakeDraggable(classPanel, classHandle, { canDrag = function() return DB.move end, drop = dropClass })
  end
  if DB.move and DB.classBar then
    U.PlaceHandle(classHandle, classPanel)
    classHandle:Show()
  else
    classHandle:Hide()
  end
  if DB.classBar and n > 0 then
    U.classApplied = true
    classPanel:Show()
  else
    classPanel:Hide()
  end
end

local petHooked = false

function U.ApplyPet()
  local pb = G("PetActionBar")
  if not pb then return end
  if DB.petBar then
    pcall(pb.Show, pb)
    pb:ClearAllPoints()
    if DB.petAnchor then
      pb:SetPoint(DB.petAnchor[1], UIParent, DB.petAnchor[2],
                  DB.petAnchor[3], DB.petAnchor[4])
    else
      pb:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 240)
    end
    pb:SetScale((DB.petScale or 1) * FS())
    if pb.SetFrameLevel then pcall(pb.SetFrameLevel, pb, 0) end

    if not petHooked then
      petHooked = true
      pb:EnableMouse(true)
      U.MakeDraggable(pb, pb, {
        canDrag = function() return DB.move end,
        drop = function(pt, relf, rp, x, y) DB.petAnchor = { pt, rp, x, y } end,
      })
    end
  else
    pcall(pb.Hide, pb)
  end
end

local function placeUnit(box, on, anchor, defY, scale)
  if U.IsDragging(box) then return end
  local size = 64 * (scale or DB.utilScale or 1) * FS()
  box.btn:SetWidth(size)
  box.btn:SetHeight(size)
  box.btn.icon:SetWidth(size - 10)
  box.btn.icon:SetHeight(size - 10)
  if box.btn.label then
    local fsz = math.max(13, math.floor(size * 0.46))
    if box.__fsz ~= fsz then
      box.__fsz = fsz
      pcall(function()
        local fn = box.btn.label:GetFont()
        if fn then box.btn.label:SetFont(fn, fsz, "OUTLINE") end
      end)
    end
  end
  box:SetWidth(size)
  box:SetHeight(size)
  box:ClearAllPoints()
  if anchor then
    box:SetPoint(anchor[1], UIParent, anchor[2], anchor[3], anchor[4])
  else
    box:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, defY)
  end
  if on then
    box:Show()
    if DB.move then box.handle:Show() else box.handle:Hide() end
  else
    box:Hide()
    box.handle:Hide()
  end
end

function U.ApplyUtil()
  placeUnit(boxJump, DB.jumpOn, DB.jumpAnchor, 300, DB.jumpScale)
  placeUnit(boxTarget, DB.targetOn, DB.targetAnchor, 210, DB.targetScale)
end


function U.ApplyRes()
  local size = (DB.resScale or 1) * FS()
  resF:SetScale(size)
  if U.IsDragging(resF) then return end
  resF:ClearAllPoints()
  if DB.resAnchor then
    resF:SetPoint(DB.resAnchor[1], UIParent, DB.resAnchor[2], DB.resAnchor[3], DB.resAnchor[4])
  else
    resF:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 400)
  end
  U.LayoutRes()
  if resF.SetAlpha then pcall(resF.SetAlpha, resF, DB.resAlpha or 1) end
  if DB.resBg then
    resF:SetBackdropColor(0.06, 0.06, 0.06, 0.85)
    resF:SetBackdropBorderColor(0.45, 0.42, 0.38, 1)
  else
    resF:SetBackdropColor(0, 0, 0, 0)
    resF:SetBackdropBorderColor(0, 0, 0, 0)
  end
  if not U.LayoutReady and not U.BootSkip then
    local rL, rT = resF:GetLeft(), resF:GetTop()
    local UW, UH = U.VisibleRect()
    local rM = 24
    if rL and rT and (rL < -rM or rT > UH + rM or rL > UW + rM or rT < -rM) then
      DB.resAnchor = nil
      resF:ClearAllPoints()
      resF:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 400)
    end
  end
  if DB.resOn and (not DB.resCombatOnly or UnitAffectingCombat("player")) then
    resF:Show()
  else
    resF:Hide()
  end
  if resF.EnableMouse then pcall(resF.EnableMouse, resF, not DB.resLocked) end
  if not resF.__hooked then
    resF.__hooked = true
    U.MakeDraggable(resF, resF, {
      drop = function(pt, relf, rp, x, y) DB.resAnchor = { pt, rp, x, y } end,
    })
  end
end

local function countShards()
  local n = 0
  local bag, slot
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) or 0 do
      local link = GetContainerItemLink(bag, slot)
      if link and (string.find(link, "item:6265", 1, true) or
                   string.find(link, "灵魂碎片", 1, true)) then n = n + 1 end
    end
  end
  return n
end

local lastTgt, lastPet
local inCombatNow = false
local shardN, shardNext = 0, 0

local function updateRes()
  if not DB.resOn then return end
  local inC = UnitAffectingCombat("player") and true or false
  -- 仅战斗显示时，显示状态和战斗状态不一致就重排（避免只在切换瞬间处理）
  if DB.resCombatOnly and inC ~= resF:IsShown() then U.ApplyRes() end
  inCombatNow = inC
  if not resF:IsShown() then return end

  local ht = UnitExists("target") and true or false
  local hp2 = UnitExists("pet") and true or false
  if ht ~= lastTgt or hp2 ~= lastPet then
    lastTgt, lastPet = ht, hp2
    U.LayoutRes()
    if resF.SetAlpha then pcall(resF.SetAlpha, resF, DB.resAlpha or 1) end
  end

  local a1, b1 = UnitPowerType("player")
  local token
  local PWR = { [0] = "MANA", [1] = "RAGE", [2] = "FOCUS", [3] = "ENERGY" }
  if type(a1) == "string" then token = a1
  elseif type(b1) == "string" then token = b1
  elseif type(a1) == "number" then token = PWR[a1] end
  if not token then token = "MANA" end

  local _, en = UnitClass("player")
  en = en and string.lower(en) or ""
  if en == "warrior" then token = "RAGE"
  elseif en == "rogue" then token = "ENERGY" end

  local barW = (DB.resWidth or 200) * FS() - 10

  if DB.resPower then
    local cur = UnitMana("player") or 0
    local max = UnitManaMax("player") or 1
    if max < 1 then max = 1 end
    local pct = cur / max
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
    local pw = math.max(4, barW * pct)
    if powerBar.__last ~= pw then powerBar.__last = pw; powerBar:SetWidth(pw) end
    if token ~= powerBar.__tok then
      powerBar.__tok = token
      if token == "ENERGY" then powerBar:SetTexture(0.98, 0.86, 0.20, 0.95)
      elseif token == "RAGE" then powerBar:SetTexture(0.85, 0.20, 0.18, 0.95)
      elseif token == "FOCUS" then powerBar:SetTexture(0.95, 0.60, 0.20, 0.95)
      else powerBar:SetTexture(0.30, 0.55, 0.95, 0.95) end
    end
  end

  if DB.resCombo and (en == "rogue" or en == "druid") then
    local cp = 0
    if type(GetComboPoints) == "function" then cp = GetComboPoints() or 0 end
    local i
    for i = 1, 5 do
      if i <= cp then pips[i]:SetTexture(1, 0.42, 0.15, 1)
      else pips[i]:SetTexture(0.16, 0.16, 0.16, 0.85) end
    end
  end

  if DB.resSelf then
    local hp = UnitHealth("player") or 0
    local hpmax = UnitHealthMax("player") or 1
    if hpmax < 1 then hpmax = 1 end
    local sw = math.max(2, barW * (hp / hpmax))
    if selfBar.__last ~= sw then selfBar.__last = sw; selfBar:SetWidth(sw) end
  end

  if DB.resTarget then
    local hp = UnitHealth("target") or 0
    local hpmax = UnitHealthMax("target") or 1
    if hpmax < 1 then hpmax = 1 end
    local tw = math.max(2, barW * (hp / hpmax))
    if targetBar.__last ~= tw then targetBar.__last = tw; targetBar:SetWidth(tw) end
  end

  if DB.resShard and en == "warlock" then
    local now = GetTime()
    if now >= shardNext then
      shardNext = now + 1
      shardN = countShards()
    end
    local w = math.max(2, barW * math.min(1, shardN / 20))
    if shardBar.__last ~= w then shardBar.__last = w; shardBar:SetWidth(w) end
  end

  if DB.resPet then
    local hp = UnitHealth("pet") or 0
    local hpmax = UnitHealthMax("pet") or 1
    if hpmax < 1 then hpmax = 1 end
    local pw2 = math.max(2, barW * (hp / hpmax))
    if petBar.__last ~= pw2 then petBar.__last = pw2; petBar:SetWidth(pw2) end
  end
end

function U.Usable(slot)
  if type(IsUsableAction) ~= "function" then return true, false end
  local ok, u, nm = pcall(IsUsableAction, slot)
  if not ok then return true, false end
  local usable = true
  if u == 0 or u == false then usable = false end
  local noMana = false
  if nm ~= nil and (nm == 1 or nm == true) then noMana = true end
  -- 只给一个返回值时不知道原因，交给"其它不可用"处理
  return usable, noMana
end

-- 统一上色：不可用就压暗
-- ===== 连击点类技能（终结技）在 0 连击点时也压暗 =====
-- IsUsableAction 不算连击点，所以从技能提示里判断"每个连击点/终结技"这类描述
local FIN_CACHE = {}

local function tooltipTexts(slot)
  local out = {}
  if type(GameTooltip) ~= "table" or type(GameTooltip.SetAction) ~= "function" then return out end
  pcall(function()
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:SetAction(slot)
    local n = 0
    if type(GameTooltip.NumLines) == "function" then n = GameTooltip:NumLines() or 0 end
    local i
    for i = 1, n do
      local fs = getglobal("GameTooltipTextLeft" .. i)
      local t = fs and fs.GetText and fs:GetText()
      if type(t) == "string" and t ~= "" then out[#out + 1] = t end
    end
  end)
  if type(GameTooltip.Hide) == "function" then pcall(GameTooltip.Hide, GameTooltip) end
  return out
end

-- 只有盗贼/德鲁伊有连击点，别把战士的"破甲攻击"之类误判
local comboCls, comboNext = nil, 0
local function isComboClass()
  local now = GetTime()
  if comboCls == nil or now >= comboNext then
    comboNext = now + 5
    local _, c = UnitClass("player")
    c = c and string.lower(c) or ""
    comboCls = (c == "rogue" or c == "druid")
  end
  return comboCls
end

local FIN_NAMES = {
  ["剔骨"] = true, ["割裂"] = true, ["肾击"] = true, ["破甲"] = true,
  ["凶猛撕咬"] = true, ["撕扯"] = true,
  ["Eviscerate"] = true, ["Rupture"] = true, ["Kidney Shot"] = true,
  ["Expose Armor"] = true, ["Ferocious Bite"] = true, ["Rip"] = true,
}

function U.Finisher(slot, tex)
  if not isComboClass() then return false end
  if not tex then tex = GetActionTexture(slot) end
  if not tex then return false end
  local c = FIN_CACHE[slot]
  if c and c.tex == tex then return c.fin end
  -- 同一张贴图 = 同一个技能：结果存进存档，以后换页/重登都不用再扫一遍提示
  DB.finCache = DB.finCache or {}
  local cached = DB.finCache[tex]
  if cached ~= nil then
    FIN_CACHE[slot] = { tex = tex, fin = cached }
    return cached
  end
  local fin = false
  local lines = tooltipTexts(slot)
  -- 名字兜底：提示里没带描述时按技能名判断
  local i
  for i = 1, #lines do
    for nm in pairs(FIN_NAMES) do
      if string.find(lines[i], nm, 1, true) then fin = true end
    end
    if fin then break end
  end
  if fin then
    FIN_CACHE[slot] = { tex = tex, fin = true }
    return true
  end
  for i = 1, #lines do
    local low = string.lower(lines[i])
    local cp = string.find(low, "连击点", 1, true) or string.find(low, "combo point", 1, true)
    if cp then
      if string.find(low, "每个", 1, true) or string.find(low, "每点", 1, true) or
         string.find(low, "终结", 1, true) or string.find(low, "finishing", 1, true) or
         string.find(low, "消耗", 1, true) then
        fin = true
        break
      end
    end
  end
  FIN_CACHE[slot] = { tex = tex, fin = fin }
  if DB.finCache then
    DB.finCache[tex] = fin
    -- 别无限膨胀：超过 120 条就清空重来（图标种数远小于这个数）
    local n = 0
    local k
    for k in pairs(DB.finCache) do n = n + 1 end
    if n > 120 then DB.finCache = { [tex] = fin } end
  end
  return fin
end

-- 最终判定：不可用 / 资源不足 / 连击点为 0 的终结技
function U.ActionState(slot, tex, skipRange)
  local usable, noMana = U.Usable(slot)
  local rng = (not skipRange and type(IsActionInRange) == "function") and IsActionInRange(slot) or nil
  if rng == 0 or rng == false then return "range" end
  if noMana then return "mana" end
  if not usable then return "no" end
  if U.Finisher(slot, tex) then
    local cp = 0
    if type(GetComboPoints) == "function" then cp = GetComboPoints() or 0 end
    if cp < 1 then return "no" end
  end
  return "ok"
end

-- 暴雪官方四态配色（和客户端原生动作条一致）
local TINT = {
  ok    = { 1.0, 1.0, 1.0 },   -- 可用
  mana  = { 0.5, 0.5, 1.0 },   -- 资源不足
  no    = { 0.4, 0.4, 0.4 },   -- 其它原因不可用
  range = { 1.0, 0.1, 0.1 },   -- 超出射程
}

function U.TintIcon(b, state)
  if state ~= b.__tint then
    b.__tint = state
    local c = TINT[state] or TINT.ok
    if b.icon and b.icon.SetVertexColor then
      pcall(b.icon.SetVertexColor, b.icon, c[1], c[2], c[3])
    end
  end
end

function U.UpdateClassCd()
  local i
  for i = 1, 10 do
    local b = G("ShapeshiftButton" .. i)
    if b and b.__cdTxt and b:IsShown() then
      local left = 0
      if type(GetShapeshiftFormCooldown) == "function" then
        local ok, st, du = pcall(GetShapeshiftFormCooldown, i)
        if ok and type(st) == "number" and type(du) == "number" and du > 0 and st > 0 and du <= 3600 then
          local now = GetTime()
          local t = st + du - now
          -- 这个客户端没进冷却时也会返回 start/du，必须确认它真的在走
          local cooling = (st <= now - 0.1) or (t < du - 0.1)
          if cooling and t > 0 then left = t end
        end
      end
      if left <= 0 and b.__gcdT then
        left = 1.5 - (GetTime() - b.__gcdT)
        if left < 0 then left = 0 end
      end
      local txt = ""
      if left > 0 then
        if left >= 60 then txt = string.format("%dm", math.floor(left / 60))
        else txt = string.format("%.1f", left) end
      end
      if txt ~= b.__cdTxtT then
        b.__cdTxtT = txt
        b.__cdTxt:SetText(txt)
        if txt == "" then b.__cdTxt:Hide() else b.__cdTxt:Show() end
      end
    end
  end
end

function U.UpdateTint()
  -- 没有目标时距离检查没有意义，省掉这轮 IsActionInRange
  local hasTarget = true
  if type(UnitExists) == "function" then hasTarget = UnitExists("target") and true or false end
  local base = (U.Page() - 1) * 12
  local j
  for j = 1, COUNT do
    local b = U.buttons[j]
    if b and cachedTex[j] ~= nil then
      U.TintIcon(b, U.ActionState(j + base, cachedTex[j], not hasTarget))
    end
  end
end

function U.UpdateStates()
  local pg = U.Page()
  if pg ~= lastPage then
    lastPage = pg
    resetTexCache()
  end
  local base = (pg - 1) * 12   -- 本页起始槽位，循环内直接算，省掉 12 次 U.SlotOf/GetTime
  local j
  for j = 1, COUNT do
    local b = U.buttons[j]
    local a = j + base
    local left, dur, cdFrom = 0, 0, nil
    if cachedTex[j] ~= nil then
      local start, du = GetActionCooldown(a)
      if start and du and du > 0 and start > 0 then
        local now = GetTime()
        local t = start + du - now
        -- 有些服务端在技能没进冷却时也返回 start=0/dur>0，用"是否真的在走"来过滤
        local cooling = (start <= now - 0.1) or (t < du - 0.1)
        if cooling and t > 0 then
          left, dur, cdFrom = t, du, start
        end
      end
    end
    local txt = ""
    if left > 0 then
      if left >= 60 then txt = string.format("%dm", math.floor(left / 60))
      else txt = string.format("%.1f", left) end
      if txt == "0.0" then txt = "" end
    end
    if txt ~= cachedCd[j] then cachedCd[j] = txt; b.cd:SetText(txt) end
    if cachedTex[j] ~= nil and left > 0 then
      b.__cs, b.__cd = cdFrom, dur
    else
      -- 技能被清除/换页时必须把冷却状态一起清掉，否则会留下扫光残影
      b.__cs, b.__cd = nil, nil
    end



  end
end

-- ---------- 隐藏原生 ----------
-- 只隐藏、不提供还原：客户端以后自己 Show() 也无效，不会闪
local function noop() end
function U.Kill(fr)
  if not fr then return end
  if fr.Show and fr.Show ~= noop and not fr.__aiOrigShow then fr.__aiOrigShow = fr.Show end
  fr.Show = noop
  if fr.Hide then pcall(fr.Hide, fr) end
end

function U.Revive(fr)
  if not fr then return end
  if fr.__aiOrigShow then
    fr.Show = fr.__aiOrigShow
    fr.__aiOrigShow = nil
  end
  if fr.Show and fr.Show ~= noop then pcall(fr.Show, fr) end
end

local EXTRA = { "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft" }
local PATTERN = { "MultiBar", "BonusActionBar", "StanceBar",
                  "PageUp", "PageDown", "ActionBarPage", "MainMenuBarPage", "ActionBarToggle",
                  "PageButton", "PageFrame", "ActionPage", "PageBtn", "PageArrow" }
local patFrames, patDone = {}, false

local function collectPattern()
  if patDone or not EnumerateFrames then return end
  patDone = true
  local fr = EnumerateFrames()
  while fr do
    local ok, t = pcall(fr.GetObjectType, fr)
    if ok and t == "Frame" then
      local okn, nm = pcall(fr.GetName, fr)
      if okn and type(nm) == "string" then
        local q
        for q = 1, #PATTERN do
          if string.find(nm, PATTERN[q], 1, true) then
            patFrames[#patFrames + 1] = fr
            break
          end
        end
      end
    end
    local okx, nx = pcall(EnumerateFrames, fr)
    if not okx then break end
    fr = nx
  end
end

local utilNative

-- 只按名字精确识别（旧版用"同尺寸 + 320px 内"猜测，会误伤其它框体）
local function isUtilName(nm)
  if type(nm) ~= "string" then return false end
  local low = string.lower(nm)
  if string.find(low, "dive", 1, true) or string.find(low, "swim", 1, true) or
     string.find(low, "ascend", 1, true) or string.find(low, "descend", 1, true) then
    return true
  end
  return false
end
-- 全帧枚举在这个客户端上一次要好几秒，一次跑完会把画面冻住。
-- 改成每帧只扫一小块：U.utilScanCur 是游标，U.utilScanDone 表示扫完。
-- 用 U 表存状态，主块局部变量已经到 200 上限，不能再加 local。
function U.ScanUtilChunk(budget)
  if U.utilScanDone or not EnumerateFrames then return end
  utilNative = utilNative or {}
  local fr = U.utilScanCur
  if not U.utilScanStarted then
    U.utilScanStarted = true
    fr = EnumerateFrames()
  end
  local n = 0
  while fr and n < (budget or 20) do
    pcall(function()
      local nm = fr:GetName()
      if isUtilName(nm) and not string.find(string.lower(nm), "aibar", 1, true) then
        utilNative[#utilNative + 1] = fr
      end
    end)
    local okx, nx = pcall(EnumerateFrames, fr)
    if not okx then break end
    fr = nx
    n = n + 1
  end
  U.utilScanCur = fr
  if not fr then U.utilScanDone = true end
end

function collectUtilNative()
  -- 老调用点只扫一小块，剩下的交给主循环每帧推进
  U.ScanUtilChunk(40)
end

-- 只隐藏原生的潜游/升降这一组按钮；跳跃键和 MainMenuBar 都保持原样
function hideUtilNative()
  collectUtilNative()
  if not utilNative then return end
  local i
  for i = 1, #utilNative do
    local f = utilNative[i]
    if f then
      if f:GetParent() ~= UIParent then pcall(f.SetParent, f, UIParent) end
      U.Kill(f)
    end
  end
end

function U.PlaceHandle(h, f, gap)
  if not h or not f then return end
  local H = UIParent:GetHeight()
  local top = f:GetTop()
  h:ClearAllPoints()
  if top and top > H - 34 then
    -- 顶到屏幕上方时,把手挪到框体下面
    h:SetPoint("TOP", f, "BOTTOM", 0, -(gap or 2))
  else
    h:SetPoint("BOTTOM", f, "TOP", 0, (gap or 2))
  end
end

function U.FixOffscreen()
  local UW, UH = U.VisibleRect()
  local M = 24
  local list = {
    { "AIbarPanel", "anchor" },
    { "AIbarClass", "classAnchor" },
    { "AIbarUtiljump", "jumpAnchor" },
    { "AIbarUtiltarget", "targetAnchor" },
    { "AIbarRes", "resAnchor" },
    { "AIbarExtra2", "bar2Anchor" },
    { "AIbarExtra3", "bar3Anchor" },
    { "AIbarExtra4", "bar4Anchor" },
    { "AIbarRL", "rlAnchor" },
    { "AiBarCfgBtn", "cfgAnchor" },
  }
  local i
  for i = 1, #list do
    local f = G(list[i][1])
    local key = list[i][2]
    if f and DB[key] then
      local L, T = f:GetLeft(), f:GetTop()
      local W, H = f:GetWidth() or 1, f:GetHeight() or 1
      if not L or not T or L < -M or T > UH + M or L + W > UW + M or T - H < -M then
        DB[key] = nil
      end
    end
  end
end

function U.ApplyNative()
  local j
  for j = 1, 12 do
    local b = G("ActionButton" .. j)
    if b then U.Kill(b) end
  end

  collectPattern()
  local q
  for q = 1, #patFrames do U.Kill(patFrames[q]) end

  local e
  for e = 1, #EXTRA do
    local fr = G(EXTRA[e])
    if fr then U.Kill(fr) end
  end
end

-- 模块开关：关掉某项就把原生相关 UI 还回去
local function reviveActionBars()
  local j
  for j = 1, 12 do U.Revive(G("ActionButton" .. j)) end
  collectPattern()
  local q
  for q = 1, #patFrames do U.Revive(patFrames[q]) end
  local e
  for e = 1, #EXTRA do U.Revive(G(EXTRA[e])) end
end

local CASTN = { "CastingBarFrame", "TargetFrameSpellBar", "PetCastingBarFrame", "FocusFrameSpellBar" }

function U.ApplyModules()
  -- 动作条
  if DB.modBar ~= false then
    U.ApplyNative()
    if panel then panel:Show() end
  else
    reviveActionBars()
    if panel then panel:Hide() end
  end

  -- 施法条
  local i
  if DB.modCast ~= false then
    for i = 1, #CASTN do U.Kill(G(CASTN[i])) end
  else
    for i = 1, #CASTN do U.Revive(G(CASTN[i])) end
    if U.castSelf then U.castSelf:Hide() end
    if U.castTarget then U.castTarget:Hide() end
  end

  -- 背包整合
  if DB.modBag == false then
    for i = 1, 5 do U.Revive(G("ContainerFrame" .. i)) end
    local bf = G("AIbarBag")
    if bf and bf:IsShown() then bf:Hide() end
  end

  -- 资源条
  -- 资源条显隐由它自己的刷新逻辑决定（战斗外只显隐一次），这里只负责强制关闭
  local rf = G("AIbarRes")
  if rf and (DB.modRes == false or DB.resOn == false) then rf:Hide() end

  -- 辅助按钮（跳 / 目标 / RL）
  local uj, ut, rlb = G("AIbarUtiljump"), G("AIbarUtiltarget"), G("AIbarRL")
  local utilOn = DB.modUtil ~= false
  local function showUtil(x, on)
    if not x then return end
    if utilOn and on ~= false then x:Show() else x:Hide() end
  end
  showUtil(uj, DB.jumpOn)
  showUtil(ut, DB.targetOn)
  showUtil(rlb, DB.rlButton)
end

-- ---------- 拖动把手 ----------
local handle = lowFrame(CreateFrame("Button", "AIbarHandle", panel))
-- 把手放大：手机上原来的 96x18 太难点（判定范围 = 框体大小）
handle:SetWidth(U.TouchMode and 132 or 110)
handle:SetHeight(U.TouchMode and 26 or 22)
handle:SetPoint("BOTTOM", panel, "TOP", 0, 2)
handle:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 8,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
handle:SetBackdropColor(0.16, 0.15, 0.14, 0.9)
handle:SetBackdropBorderColor(0.45, 0.42, 0.38, 1)
local hl = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hl:SetPoint("CENTER", handle, "CENTER")
hl:SetText("拖动")
pcall(function()
  local fn, sz = hl:GetFont()
  if fn then hl:SetFont(fn, (sz or 12) + (U.TouchMode and 3 or 1), "OUTLINE") end
end)

U.MakeDraggable(panel, handle, {
  canDrag = function() return DB.move end,
  -- 一开始拖动作条 1，就把“贴在它上面”的副条和配置按钮改成绝对坐标，
  -- 否则它们会跟着动作条 1 一起跑（1.56 用户反馈）
  onDown = function() U.DetachDeps() end,
  drop = function(pt, relf, rp, x, y) DB.anchor = { pt, rp, x, y } end,
})

function clampToScreen(f)
  if not f or type(GetScreenWidth) ~= "function" then return end
  local W = UIParent:GetWidth()
  local H = UIParent:GetHeight()
  if not W or not H or W <= 0 or H <= 0 then
    local e = UIParent:GetEffectiveScale() or 1
    W = (GetScreenWidth() or 0) / e
    H = (GetScreenHeight() or 0) / e
  end
  if W <= 0 or H <= 0 then return end
  local L, T = f:GetLeft(), f:GetTop()
  local w, h = f:GetWidth(), f:GetHeight()
  if not L or not T or not w or not h then return end
  -- 允许外溢 40%（这个客户端的 UIParent 不等于可见画面）
  local ox = W * 0.4
  local oy = H * 0.4
  local dx, dy = 0, 0
  if L < -ox then dx = -ox - L end
  if L + w > W + ox then dx = (W + ox) - (L + w) end
  if T > H + oy then dy = (H + oy) - T end
  if T - h < -oy then dy = (-oy) - (T - h) end
  if dx ~= 0 or dy ~= 0 then
    local pt, relf, rp, x, y = f:GetPoint(1)
    if pt then
      f:ClearAllPoints()
      f:SetPoint(pt, relf or UIParent, rp or pt, (x or 0) + dx, (y or 0) + dy)
    end
  end
end

function U.SetMovable(on)
  DB.move = on and true or false
  U.Geo = true
  if on then handle:Show() else handle:Hide() end
end

-- ---------- RL 按钮 ----------
local rl = lowFrame(CreateFrame("Button", "AIbarRL", UIParent))
rl:SetWidth(84)
rl:SetHeight(52)
rl:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 8,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
rl:SetBackdropColor(0.30, 0.10, 0.09, 0.92)
rl:SetBackdropBorderColor(0.55, 0.35, 0.30, 1)
local rlTxt = rl:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rlTxt:SetPoint("CENTER", rl, "CENTER")
rlTxt:SetText("|cffffddddRL|r")
if DB.rlAnchor then
  rl:SetPoint(DB.rlAnchor[1], UIParent, DB.rlAnchor[2], DB.rlAnchor[3], DB.rlAnchor[4])
else
  rl:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -14, 160)
end

U.MakeDraggable(rl, rl, {
  drop = function(pt, relf, rp, x, y) DB.rlAnchor = { pt, rp, x, y } end,
  onClick = function()
    -- 重载界面时客户端会把插件存档写进文件，这是最可靠的落盘时机
    if U.Save then U.Save(true) end
    if type(ReloadUI) == "function" then ReloadUI() end
  end,
})

-- 配置按钮：可以单独拖到屏幕任意位置（移动模式下）
local cfgBtn = CreateFrame("Button", "AiBarCfgBtn", UIParent)
cfgBtn:SetWidth(64)
cfgBtn:SetHeight(28)
cfgBtn:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -104, 160)
cfgBtn:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 8,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
cfgBtn:SetBackdropColor(0.16, 0.15, 0.14, 0.95)
cfgBtn:SetBackdropBorderColor(0.45, 0.42, 0.38, 1)
-- 配置面板是 DIALOG 层：按钮如果被拖到屏幕中间，打开面板后会正好被面板盖住，
-- 看起来就像“按钮不见了”。把按钮提到面板之上，永远看得见也点得到。
if cfgBtn.SetFrameStrata then pcall(cfgBtn.SetFrameStrata, cfgBtn, "DIALOG") end
if cfgBtn.SetFrameLevel then pcall(cfgBtn.SetFrameLevel, cfgBtn, 100) end
local cfgTxt = cfgBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cfgTxt:SetPoint("CENTER", cfgBtn, "CENTER")
cfgTxt:SetText("配置")
local function toggleConfig()
  local cf = G("AIbarConfig")
  if cf then
    if cf:IsShown() then cf:Hide() else cf:Show() end
  end
end

-- 单独放开：不用进移动模式也能拖这个按钮
U.MakeDraggable(cfgBtn, cfgBtn, {
  drop = function(pt, relf, rp, x, y)
    -- 直接存当前锚点（和动作条 1 一致），不做坐标二次换算，
    -- 否则换算误差会让按钮在松手时“跳”到别处
    DB.cfgAnchor = { pt, rp, x, y, relf == panel and "panel" or nil }
  end,
  onClick = toggleConfig,
})

-- 配置按钮默认就贴在动作条右上角，动作条可见它就可找得到。
-- 注意：贴完马上换算成屏幕绝对坐标并存档，否则移动动作条 1 时会把它一起带走。
local function cfgDefaultPoint()
  cfgBtn:ClearAllPoints()
  if panel then
    cfgBtn:SetPoint("BOTTOMLEFT", panel, "TOPRIGHT", 6, 0)
  else
    cfgBtn:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -104, 160)
  end
  -- 如果“贴着动作条”这个默认位置本身也在屏幕外（动作条被拖到边上时会发生），
  -- 再退到屏幕中下方，保证按钮一定看得见。
  local L, T = cfgBtn:GetLeft(), cfgBtn:GetTop()
  local W = cfgBtn:GetWidth() or 1
  local H = cfgBtn:GetHeight() or 1
  local UW, UH = U.VisibleRect()
  if not L or not T or L < 0 or L + W > UW or T - H < 0 or T > UH then
    cfgBtn:ClearAllPoints()
    cfgBtn:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)
  end
  -- 这里不写档：登录那一瞬间坐标可能还没算好，写进去会把用户存的位置覆盖成默认值。
  -- 用户真拖过之后 drop 里会存成绝对坐标。
end

-- 默认布局：首次安装与“重置位置”都用它。
--   动作条 1 在底部居中；
--   动作条 2/3/4 右对齐竖排，2 在下、4 在上；
--   小按钮（职业 / 跳 / 目 / 配置 / RL）依次排在屏幕中线上。
-- 坐标按当前可见区域的比例算，换分辨率后重新执行一遍即可重新适配。
function U.ApplyDefaultLayout()
  local w, h = U.VisibleRect()
  if not w or w <= 0 then w = 1024 end
  if not h or h <= 0 then h = 768 end
  local right = -math.floor(w * 0.08)      -- 右边留 8%（保持原样，不再改动动作条位置）
  -- 图标默认 56；屏幕偏矮（<700）时按比例缩小，保证四条加把手放得下
  local icon = 56
  if h < 700 then icon = math.max(40, math.floor(56 * h / 768)) end
  local cell = icon + 8
  local barH = cell * 2 + 4
  local handleH = (U.TouchMode and 24 or 20) + 2   -- 把手高度：上面一条要避开它
  local gap = 10

  -- 动作条 1 贴屏幕底部，2/3/4 依次往上叠（以把手为锚点，避免压住上面那条）。
  -- 屏幕偏矮时按可用高度压缩间距，保证最上面那条连同把手也放得下。
  local y = 8
  local step = barH + handleH + gap
  local avail = h - y - handleH - barH      -- 从顶边倒推出来能用的高度
  if step * 3 > avail then step = math.floor(avail / 3) end
  if step < barH + 2 then step = barH + 2 end -- 再挤也不能让条互相压住
  DB.anchor = { "BOTTOMRIGHT", "BOTTOMRIGHT", right, y }
  DB.bar2Anchor = { "BOTTOMRIGHT", "BOTTOMRIGHT", right, y + step }
  DB.bar3Anchor = { "BOTTOMRIGHT", "BOTTOMRIGHT", right, y + step * 2 }
  DB.bar4Anchor = { "BOTTOMRIGHT", "BOTTOMRIGHT", right, y + step * 3 }

  -- 资源条默认放在屏幕中下部（用户 1.74 反馈的位置），不再顶到最上面
  DB.resAnchor = { "BOTTOM", "BOTTOM", 0, math.floor(h * 0.235) }
  -- 施法条（自己/目标）默认放在资源条上方，留出资源条高度，避免重叠
  local resY = math.floor(h * 0.235)
  DB.castTargetAnchor = { "BOTTOM", "BOTTOM", 0, resY + 96 }
  DB.castSelfAnchor = { "BOTTOM", "BOTTOM", 0, resY + 128 }

  -- 小按钮：RL / 配置放在资源条下方的中线空档里（不压资源条、不压施法条），
  -- 目 / 跳 / 职业继续在上面一排的中线上
  y = math.floor(h * 0.40)
  DB.rlAnchor = { "BOTTOM", "BOTTOM", 0, 84 }
  DB.cfgAnchor = { "BOTTOM", "BOTTOM", 0, 148 }
  y = y + 60
  DB.targetAnchor = { "BOTTOM", "BOTTOM", 0, y }
  y = y + 64 + handleH + gap
  DB.jumpAnchor = { "BOTTOM", "BOTTOM", 0, y }
  y = y + 64 + handleH + gap
  DB.classAnchor = { "BOTTOM", "BOTTOM", 0, y }
end

-- 把「相对动作条 1」摆放的副条 2~4 与配置按钮改成屏幕绝对坐标。
-- 拖动动作条 1 时调用，位置保持当下不变，但之后不再联动。
function U.DetachDeps()
  local i
  for i = 2, 4 do
    local fr = U.extraBars[i]
    if fr and fr:IsShown() and not U.IsDragging(fr) then
      local a = DB["bar" .. i .. "Anchor"]
      if (not a) or a[5] == "panel" then
        local b = U.BakeAnchor(fr)
        if b then
          fr:ClearAllPoints()
          fr:SetPoint(b[1], UIParent, b[2], b[3], b[4])
          DB["bar" .. i .. "Anchor"] = b
        end
      end
    end
  end
  if not U.IsDragging(cfgBtn) then
    local a = DB.cfgAnchor
    if (not a) or a[5] == "panel" then
      local b = U.BakeAnchor(cfgBtn)
      if b then
        cfgBtn:ClearAllPoints()
        cfgBtn:SetPoint(b[1], UIParent, b[2], b[3], b[4])
        DB.cfgAnchor = b
      end
    end
  end
end

function U.ApplyCfgBtn()
  if not U.IsDragging(cfgBtn) then
    if DB.cfgAnchor then
      local rel = (DB.cfgAnchor[5] == "panel") and panel or UIParent
      cfgBtn:ClearAllPoints()
      cfgBtn:SetPoint(DB.cfgAnchor[1], rel, DB.cfgAnchor[2],
                      DB.cfgAnchor[3], DB.cfgAnchor[4])
      -- 老存档里“相对动作条”的坐标先按原样摆；用户拖动动作条 1 时 DetachDeps 会处理
      -- 存的位置明显跑出屏幕才拉回默认位置。
      -- 放宽到 40% 余量：这个客户端的 UIParent 往往比可见画面小，
      -- 原来的 ±20 像素判定会把合法位置误判成越界，一登录就把存好的坐标清掉。
      -- 只在启动时修一次；进游戏后用户拖到哪就是哪，不再自动拉回
      if not U.LayoutReady and not U.BootSkip then
        local L, T = cfgBtn:GetLeft(), cfgBtn:GetTop()
        local W = cfgBtn:GetWidth() or 1
        local H = cfgBtn:GetHeight() or 1
        local UW, UH = U.VisibleRect()
        local M = 24
        -- 用四条边判断：只看顶边会漏掉“下半截在屏幕外”的情况
        if not L or not T or L < -M or T > UH + M or L + W > UW + M or T - H < -M then
          DB.cfgAnchor = nil
          DB.castSelfAnchor = nil
          DB.castTargetAnchor = nil
          cfgDefaultPoint()
        end
      end
    else
      cfgDefaultPoint()
    end
  end
  if DB.cfgBtn ~= false then cfgBtn:Show() else cfgBtn:Hide() end
end

function U.SetRL(on)
  DB.rlButton = on and true or false
  if on then rl:Show() else rl:Hide() end
end

-- ---------- 循环 ----------
-- 逐帧动画：冷却扇形与平砍条都在这里画，跟手不卡
local function paintSweep(b, now)
  local s, d = b.__cs, b.__cd
  if s and d and d > 0 then
    local left = s + d - now
    if left > 0 then
      setCdFrame(b, left / d)
      if not b.__cdOn then
        b.__cdOn = true
        if b.cdArt then b.cdArt:Show() end
      end
      return
    end
  end
  if b.__cdOn then
    b.__cdOn = false
    b.__cs, b.__cd = nil, nil
    if b.cdArt then b.cdArt:Hide() end
  end
end

local function swingSpeedNow()
  if swingSpeed then return swingSpeed end
  local sp = 2
  if type(UnitAttackSpeed) == "function" then
    local ok, v = pcall(UnitAttackSpeed, "player")
    if ok and type(v) == "number" and v > 0.2 then sp = v end
  end
  return sp
end

function U.UpdateAnim()
  local now = GetTime()
  local j
  for j = 1, COUNT do paintSweep(U.buttons[j], now) end
  local n
  for n = 2, 4 do
    local fr = U.extraBars[n]
    if fr and fr:IsShown() then
      local k
      for k = 1, COUNT do paintSweep(fr.buttons[k], now) end
    end
  end
  if DB.resSwing and resF:IsShown() then
    local speed = swingSpeedNow()
    local el = 0
    if swingOn then
      el = now - swingT
      if el < 0 then el = 0 end
      if el > speed then el = speed end
    end
    local bw = (DB.resWidth or 200) * FS() - 10
    if swingBar.__last ~= el then
      swingBar.__last = el
      swingBar:SetWidth(math.max(2, bw * (el / speed)))
    end
  end
end

do
  -- 图标贴图预加载：换到潜行页时 12 张新图标要在客户端里解码，手机上会卡好几秒。
  -- 这些贴图必须**真的在屏幕上渲染**才会触发加载（之前放到屏幕外+几乎透明，等于没预热），
  -- 所以用 2×2 像素的可见小贴图贴在左下角，肉眼就是一个点，不影响使用。
  U.preTex = {}
  local i
  for i = 1, 12 do
    local t = UIParent:CreateTexture(nil, "BACKGROUND")
    t:SetWidth(2); t:SetHeight(2)
    t:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    t:SetAlpha(1)
    t:Show()
    U.preTex[i] = t
  end
end

-- 每步预加载一个槽位：先预热潜行页 73~84（进潜行最容易卡），再预热正常页 1~12
function U.PreloadStep()
  local idx = (U.preIdx or 0) + 1
  if idx > 24 then return end
  U.preIdx = idx
  local slot
  if idx <= 12 then slot = idx + 72   -- 73 ~ 84
  else slot = idx - 12 end            -- 1 ~ 12
  local tex = GetActionTexture(slot)
  local t = U.preTex[((idx - 1) % 12) + 1]
  if t and tex then t:SetTexture(tex) end
  if idx == 24 then U.preDone = true end
end

-- 这个客户端没有 os 库（os 是 nil，不是 nil 的字段），
-- 所以不能写 os.clock 甚至 os.clock and ...，必须先用 type(os) 判一下。
function U.CpuNow()
  if type(os) == "table" and type(os.clock) == "function" then
    local ok, v = pcall(os.clock)
    if ok and type(v) == "number" then return v end
  end
  return 0
end

local acc, acc2, acc3, accX, acc4, acc5 = 0, 0, 0, 0, 0, 0
local wasStealth = false
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
  -- 卡顿自检：单帧明显超时（GetTime 或 CPU 时间任一超 1 秒）才打一行到聊天。
  -- 同时用 os.clock：万一这个客户端的 GetTime 是"按帧累加"，冻住时它不会动。
  local lagT0 = GetTime()
  local lagCpu0 = U.CpuNow()
  local lagMark = lagT0
  local dState, dRefresh, dExtra, dMods, dCast = 0, 0, 0, 0, 0

  U.tickN = (U.tickN or 0) + 1   -- 主循环帧计数，/abc save 会打印出来

  -- 帧间隔检测：卡顿若发生在两帧之间（客户端自己阻塞），帧内计时是看不见的。
  local gapT = GetTime()
  local gap = gapT - (U.lastTickT or gapT)
  U.lastTickT = gapT
  U.lastGap = gap   -- 只记录，不刷聊天（/abc save 里可以看到）

  -- 先存档：这段放在最前面，后面任何一段报错都不会把这次的设置改动丢掉
  acc3 = acc3 + (arg1 or 0)
  if acc3 > 5 then
    acc3 = 0
    U.Save()
  end

  -- 分帧推进原生潜游按钮扫描（每次 20 个框体，不再一口气冻住）
  if not U.utilScanDone and DB.modUtil ~= false then U.ScanUtilChunk(20) end

  -- 空闲时慢慢预热两个页面的图标贴图（战斗里不跑，避免影响手感）
  -- 客户端登录后会把原生姿态/形态栏重新显示出来，这里持续压住它，
  -- 避免“刚进游戏先看到原生条、一两秒后才换成自己的”那一下闪烁
  U.cbAcc = (U.cbAcc or 0) + (arg1 or 0)
  if U.cbAcc > 0.3 then
    U.cbAcc = 0
    if DB.classBar then
      local cbF = G("ShapeshiftBarFrame")
      if cbF and cbF.IsShown and cbF:IsShown() then pcall(cbF.Hide, cbF) end
    end
  end

  -- 职业栏：登录后前几秒 GetNumShapeshiftForms 可能还是 0，建不起来，
  -- 这里持续重试，避免要等 2 秒整刷才显示
  U.cbAcc = U.cbAcc or 0
  if DB.classBar and not U.classApplied then
    U.cbAccTry = (U.cbAccTry or 0) + (arg1 or 0)
    if U.cbAccTry > 0.2 then
      U.cbAccTry = 0
      U.ApplyClassBar()
    end
  end

  if U.tipHideAt and GetTime() >= U.tipHideAt then
    U.tipHideAt = nil
    if type(GameTooltip.Hide) == "function" then pcall(GameTooltip.Hide, GameTooltip) end
  end

  U.preAcc = (U.preAcc or 0) + (arg1 or 0)
  if U.preAcc > 0.15 and (U.preIdx or 0) < 24 then
    U.preAcc = 0
    if not UnitAffectingCombat("player") then U.PreloadStep() end
  end

  -- 动作条/技能变化：整帧只刷新一次，而且只换图标文字，不做宠物条/职业条重挂
  if U.barDirty then
    U.barDirty = false
    local bd0 = GetTime()
    resetTexCache()
    U.Refresh(true)
    updateExtra()
    U.UpdateStates()
    U.UpdateTint()
    U.lastBarRefreshMs = (GetTime() - bd0) * 1000
  end

  U.UpdateDrags()
  -- 动画帧率减半：手机上肉眼看不出差别，省一半每帧开销
  U.animTick = (U.animTick or 0) + 1
  if U.animTick % 2 == 0 then U.UpdateAnim() end
  local dt = arg1 or 0

  acc = acc + dt
  if acc > 0.1 then
    acc = 0
    U.UpdateStates()
    U.UpdateClassCd()
    -- 只有条子在显示时才每 0.1 秒推进，其余交给事件
    if U.previewSelf or U.previewTarget or U.castSelf:IsShown() or U.castTarget:IsShown() then
      U.UpdateCasts()
    end
  end
  local m = GetTime(); dState = m - lagMark; lagMark = m

  accX = accX + dt
  if accX > 0.3 then
    accX = 0
    updateExtra()
    U.UpdateTint()
    updateRes()
    local stNow, changed = U.RefreshStealth()
    if changed and stNow ~= wasStealth then
      wasStealth = stNow
      local sw0 = GetTime()
      if not U.stSkip then
        resetTexCache()
        U.Refresh(true)   -- 潜行换页只换图标，不做整条重排
      end
      -- 只在插件这段真的耗时超过 0.3 秒时才提示，平时静默
      U.lastStealthMs = (GetTime() - sw0) * 1000
    end
  end
  m = GetTime(); dExtra = m - lagMark; lagMark = m

  acc5 = acc5 + dt
  if acc5 > 0.5 then
    acc5 = 0
    U.UpdateCasts()
  end
  m = GetTime(); dCast = m - lagMark; lagMark = m

  acc2 = acc2 + dt
  if acc2 > 2 then
    acc2 = 0
    U.Refresh()
  end
  m = GetTime(); dRefresh = m - lagMark; lagMark = m

  if U.PendingClamp then
    local pc = U.PendingClamp
    U.PendingClamp = nil
    clampToScreen(pc)
  end

  acc4 = acc4 + dt
  if acc4 > 3 then
    acc4 = 0
    U.ApplyModules()
    if U.RestoreBagIcon then U.RestoreBagIcon() end
    if DB.modUtil ~= false then hideUtilNative() end
    U.Geo = true
  end
  m = GetTime(); dMods = m - lagMark; lagMark = m

  -- 整帧跑完再判定：之前这段放在模块段之前，模块段真卡了反而报不出来
  local spent = GetTime() - lagT0
  U.lastSpent = spent
  local cpu = U.CpuNow() - lagCpu0
  U.lastSpent = spent
  U.lastCpu = cpu
end)

-- ---------- 事件驱动刷新 ----------
-- 换技能 / 学新技能 / 切页 / 进世界时马上重扫图标，不再等 2 秒的兜底轮询。
-- 这些事件都不带参数，直接整条重扫最省事，而且频率很低。
do  -- 用 do 包起来：主块局部变量已接近 200 上限，块内的局部出了块就释放
local barEv = CreateFrame("Frame")
local BAR_EVENTS = { "ACTIONBAR_SLOT_CHANGED", "SPELLS_CHANGED", "PLAYER_LEVEL_UP",
                     "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
                     "PLAYER_ENTERING_WORLD" }
local bei
for bei = 1, #BAR_EVENTS do pcall(barEv.RegisterEvent, barEv, BAR_EVENTS[bei]) end
barEv:SetScript("OnEvent", function()
  if not U.Ready then return end      -- 登录前的事件先忽略，等 loader 初始化完
  -- 换页/换技能时客户端是按“每个格子一条”连发事件的（一页 12 条）。
  -- 以前每条都当场整条刷新，一次换页就重跑十几遍 ApplyPet/ApplyClassBar，
  -- 这些重挂在客户端侧要好几秒（就是潜行换页卡 2~4 秒的真凶）。
  -- 现在只打标记，主循环下一帧合并成一次轻量刷新。
  U.barDirty = true
  U.preIdx = 0                        -- 技能变了，预加载要重来
end)
end

-- ---------- 命令 ----------
SLASH_EVALBARCMD1 = "/abc"

local function say(t)
  DEFAULT_CHAT_FRAME:AddMessage("|cff7CECFFAiBar|r " .. t)
end

SlashCmdList["EVALBARCMD"] = function(msg)
  msg = string.lower(msg or "")
  if msg == "skin" then DB.skin = not DB.skin
  elseif msg == "move" then U.SetMovable(not DB.move)
  elseif msg == "macro" then
    U.DiagMacro()
  elseif msg == "pc" then
    if DB.pcMode == nil then DB.pcMode = "pc"
    elseif DB.pcMode == "pc" then DB.pcMode = "touch"
    else DB.pcMode = nil end
    U.Save(true)
    say("平台模式：" .. (DB.pcMode == "pc" and "电脑" or DB.pcMode == "touch" and "触屏" or "自动") ..
        "（尺寸需要 /reload 或点 RL 重载后生效）")
    return
  elseif msg == "icons" then
    U.stSkip = not U.stSkip
    say("换页图标刷新：" .. (U.stSkip and "已关闭（测试用）" or "已开启"))
    return
  elseif msg == "save" then
    -- 自检：确认存档到底有没有、主循环有没有在跑（顺手强制落盘一次）
    U.Save(true)
    local m = mirrorTable()
    local n = 0
    if m then
      local k
      for k in pairs(m) do n = n + 1 end
    end
    say("存档自检：账号=" .. tostring(DB.seq or 0) ..
        " 角色=" .. tostring((type(AIbarDBC) == "table" and AIbarDBC.seq) or 0) ..
        " 镜像=" .. (m and tostring(m.seq or 0) or "无") ..
        "，字段 " .. n .. "，落盘API=" .. (type(SaveVariables) == "function" and "有" or "无") ..
        "，主循环 " .. tostring(U.tickN or 0) .. " 帧，位置=" ..
        (DB.cfgAnchor and (tostring(DB.cfgAnchor[3]) .. "," .. tostring(DB.cfgAnchor[4])) or "无"))
    return
  elseif msg == "diag" then
    say("IsUsableAction=" .. type(IsUsableAction) .. "　IsActionInRange=" .. type(IsActionInRange))
    say(string.format("自身资源 %d / %d", UnitMana("player") or 0, UnitManaMax("player") or 1))
    local apiSp = "-"
    if type(UnitAttackSpeed) == "function" then
      local ok, sp = pcall(UnitAttackSpeed, "player")
      if ok and type(sp) == "number" then apiSp = string.format("%.2f", sp) end
    end
    say(string.format("平砍 事件=%d 实测=%s API=%s 来源=%s 状态=%s",
                      swingCount, swingSpeed and string.format("%.2f", swingSpeed) or "未知",
                      apiSp, swingSource, swingOn and "挥砍中" or "停"))
    local i
    for i = 1, COUNT do
      local a = U.SlotOf(i)
      if GetActionTexture(a) then
        local usable, noMana = U.Usable(a)
        local raw = "nil"
        if type(IsUsableAction) == "function" then
          local ok, u, nm = pcall(IsUsableAction, a)
          raw = tostring(u) .. "," .. tostring(nm)
        end
        say(string.format("格%d usable=%s noMana=%s 原始=%s",
                          i, tostring(usable), tostring(noMana), raw))
      end
    end
    return
  elseif msg == "help" or msg == "" then
    say("/ab　打开配置面板")
    say("/abc skin　背板开/关")
    say("/abc move　进入/退出移动模式")
    say("/abc diag　诊断技能可用性")
    say("/abc save　存档自检（镜像/主循环/配置按钮坐标）")
    say("/abc icons　临时关闭换页图标刷新（排查卡顿用）")
    say("/abc pc　平台模式：自动 / 电脑 / 触屏")
    return
  else
    say("/abc skin | move | save | icons | pc | diag | help")
    return
  end
  U.Refresh()
  say("已应用")
end

-- 进出潜行要立刻换页，不能等 0.2 秒节拍
local auraEv = CreateFrame("Frame")
pcall(auraEv.RegisterEvent, auraEv, "UNIT_AURA")
pcall(auraEv.RegisterEvent, auraEv, "UNIT_BUFF")
auraEv:SetScript("OnEvent", function()
  if arg1 ~= nil and arg1 ~= "player" then return end
  local t0 = GetTime()
  local st, changed = U.RefreshStealth()
  if changed and st ~= wasStealth then
    wasStealth = st
    if not U.stSkip then
      resetTexCache()
      U.Refresh(true)   -- 潜行换页只换图标，不做整条重排
    end
    U.lastStealthMs = (GetTime() - t0) * 1000
  end
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_LOGOUT")
loader:SetScript("OnEvent", function()
  -- 退出/重载前再落一次盘：手机端很可能等不到 5 秒的定时保存就被切掉
  if event == "PLAYER_LOGOUT" then U.Save(true); return end
  if event ~= "PLAYER_LOGIN" then return end
  U.Restore()
  -- 全新安装（一份存档都没有）才套用默认布局；老用户保留自己的摆位
  if (DB.seq or 0) == 0 and not DB.anchor and not DB.cfgAnchor and not DB.resAnchor and not DB.bar2Anchor then
    U.ApplyDefaultLayout()
    U.BootSkip = true          -- 默认坐标是可信的，跳过启动越界修正
    -- 动作条 2/3/4 的默认规格：6 列 × 2 行、图标 56
    DB.bars = DB.bars or {}
    local bn
    local ih = 56
    local _, hh = U.VisibleRect()
    if hh and hh > 0 and hh < 700 then ih = math.max(40, math.floor(56 * hh / 768)) end
    for bn = 1, 4 do
      DB.bars[bn] = { cols = 6, slots = 12, icon = ih, gap = 8 }
    end
    DB.cols, DB.icon, DB.gap = 6, ih, 8
  end
  if DB.rlAnchor then
    rl:ClearAllPoints()
    rl:SetPoint(DB.rlAnchor[1], UIParent, DB.rlAnchor[2], DB.rlAnchor[3], DB.rlAnchor[4])
  end
  U.SetRL(DB.rlButton)
  U.SetMovable(DB.move)
  U.ApplyCfgBtn()

  U.FixOffscreen()
  -- 登录时顺带报一下存档状态：配置不保存时，看这一行就能判断是镜像没了还是别的原因
  local savedMirror = mirrorTable()
  local pcSeq = (type(AIbarDBC) == "table" and AIbarDBC.seq) or 0
  local miSeq = savedMirror and (savedMirror.seq or 0) or 0
  DEFAULT_CHAT_FRAME:AddMessage("|cff7CECFFAiBar|r 已加载：账号存档 " .. tostring(DB.seq or 0) ..
    " / 角色存档 " .. tostring(pcSeq) ..
    " / 镜像 " .. (savedMirror and tostring(miSeq) or "无") ..
    "；/ab 打开控制面板")
  -- 三路都是 0：说明上一局的存档一点没读到，多半是进程被直接杀掉没写盘
  if (DB.seq or 0) == 0 and pcSeq == 0 and miSeq == 0 then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff88AIbar|r 没读到上一局的存档：改完设置先点界面的 RL（重载界面）或输入 /reload，再退游戏。直接杀进程不会写盘。")
  end

  -- 启动时若动作条在屏幕外，拉回屏幕内
  if panel then
    local L, T = panel:GetLeft(), panel:GetTop()
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    if not L or not T or L < -40 or T > H + 40 or L > W - 40 or T < -40 then
      DB.anchor = nil
      panel:ClearAllPoints()
      panel:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 8)
    end
  end
  U.ApplyNative()
  U.ApplyCastAnchors()
  U.Refresh()
  U.LayoutReady = true   -- 启动摆位结束：之后不再自动回位/吸附
  U.Ready = true         -- 之后才允许动作条事件触发刷新
end)
do  -- 施法条（自己 / 目标）
local CBW, CBH = 240, 18

-- 职业色（原版没有 RAID_CLASS_COLORS，自己带一份）
local CLASSCOL = {
  WARRIOR = { 0.78, 0.61, 0.43 },
  PALADIN = { 0.96, 0.55, 0.73 },
  HUNTER  = { 0.67, 0.83, 0.45 },
  ROGUE   = { 1.00, 0.96, 0.41 },
  PRIEST  = { 1.00, 1.00, 1.00 },
  SHAMAN  = { 0.00, 0.44, 0.87 },
  MAGE    = { 0.41, 0.80, 0.94 },
  WARLOCK = { 0.58, 0.51, 0.79 },
  DRUID   = { 1.00, 0.49, 0.04 },
}

local function unitColor(unit, fallback)
  if type(UnitClass) == "function" then
    local ok, _, class = pcall(UnitClass, unit)
    if ok and class and CLASSCOL[class] then return CLASSCOL[class] end
  end
  return fallback
end

local function readCast(unit)
  local fns = { UnitCastingInfo, UnitChannelInfo }
  local i
  for i = 1, 2 do
    local fn = fns[i]
    if type(fn) == "function" then
      local ret = { pcall(fn, unit) }
      if ret[1] then
        local name, tex, nums = nil, nil, {}
        local k
        for k = 2, #ret do
          local v = ret[k]
          if type(v) == "string" then
            if string.find(v, "Interface\\", 1, true) then
              if not tex then tex = v end
            elseif v ~= "" and not name then
              name = v
            end
          elseif type(v) == "number" then
            nums[#nums + 1] = v
          end
        end
        if name and #nums >= 2 then
          local st, sp = nums[1], nums[2]
          -- 有的客户端给毫秒：比当前时间大太多就是毫秒
          if sp > GetTime() + 300 then st, sp = st / 1000, sp / 1000 end
          if sp > st and sp - st > 0.05 then
            return { name = name, tex = tex, startT = st, stopT = sp }
          end
        end
      end
    end
  end
  return nil
end

local function makeBar(key, defY, r, g, b)
  local f = lowFrame(CreateFrame("Frame", "AIbarCast" .. key, UIParent))
  if f.SetFrameStrata then pcall(f.SetFrameStrata, f, "BACKGROUND") end
  f:SetWidth(CBW)
  f:SetHeight(CBH)
  f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, defY)
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  f:SetBackdropColor(0.04, 0.04, 0.05, 0.9)
  f:SetBackdropBorderColor(0.35, 0.33, 0.30, 1)

  f.fill = f:CreateTexture(nil, "ARTWORK")
  f.fill:SetHeight(CBH - 4)
  f.fill:SetWidth(2)
  f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
  f.fill:SetTexture(r, g, b, 0.85)

  f.icon = f:CreateTexture(nil, "OVERLAY")
  f.icon:SetWidth(CBH - 4)
  f.icon:SetHeight(CBH - 4)
  f.icon:SetPoint("LEFT", f, "LEFT", 2, 0)
  f.icon:Hide()

  f.txt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.txt:SetPoint("LEFT", f, "LEFT", 8, 0)
  f.txt:SetText("")

  f.time = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.time:SetPoint("RIGHT", f, "RIGHT", -4, 0)
  f.time:SetText("")

  f:EnableMouse(true)
  f.castKey = key
  U.MakeDraggable(f, f, {
    canDrag = function() return not DB.castLock end,
    drop = function(pt, relf, rp, x, y) DB["cast" .. key .. "Anchor"] = { pt, rp, x, y } end,
  })
  f:Hide()
  return f
end

U.castSelf = makeBar("Self", 470, 0.95, 0.80, 0.25)
U.castSelf.castDefCol = { 0.95, 0.80, 0.25 }
U.castSelf.castDefY = 470
U.castTarget = makeBar("Target", 500, 0.85, 0.25, 0.25)
U.castTarget.castDefCol = { 0.85, 0.25, 0.25 }
U.castTarget.castDefY = 500

-- 隐藏原生施法条（自己 / 目标 / 宠物），由我们的代替
local NATIVE_CAST = { "CastingBarFrame", "TargetFrameSpellBar", "PetCastingBarFrame",
                      "FocusFrameSpellBar" }
local nci
for nci = 1, #NATIVE_CAST do
  local nf = G(NATIVE_CAST[nci])
  if nf then U.Kill(nf) end
end

local function paintBar(f, unit, info)
  if not info then
    f:Hide()
    return
  end
  local now = GetTime()
  local left = info.stopT - now
  if left <= 0 then
    f:Hide()
    return
  end
  local dur = info.stopT - info.startT
  if dur <= 0 then dur = 0.01 end
  -- 消耗式：条一开始是满的，随时间变短
  local frac = left / dur
  if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
  local sc = math.max(0.6, math.min(2.0, DB.castScale or 1))
  local W = math.max(120, math.min(520, DB.castW or CBW))
  local H = math.max(10, math.min(40, DB.castH or CBH))
  local rev = DB.castReverse
  if unit == "target" then
    sc = math.max(0.6, math.min(2.0, DB.castTScale or 1))
    W = math.max(120, math.min(520, DB.castTW or CBW))
    H = math.max(10, math.min(40, DB.castTH or CBH))
    rev = DB.castTReverse
  end
  f:SetScale(sc)
  f:SetWidth(W)
  f:SetHeight(H)
  f.fill:SetHeight(H - 4)
  f.fill:ClearAllPoints()
  f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
  -- 默认消耗式（满→空）；反转后从左往右填充（空→满）
  local fw2 = rev and (1 - frac) or frac
  f.fill:SetWidth(math.max(2, (W - 4) * fw2))
  f.icon:SetWidth(H - 4)
  f.icon:SetHeight(H - 4)
  local col = unitColor(unit, f.castDefCol)
  f.fill:SetTexture(col[1], col[2], col[3], 0.85)
  if f.SetBackdropBorderColor then
    f:SetBackdropBorderColor(col[1] * 0.8, col[2] * 0.8, col[3] * 0.8, 1)
  end
  f.icon:SetTexture(info.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
  f.icon:Show()
  f.txt:SetPoint("LEFT", f, "LEFT", H + 2, 0)
  f.txt:SetText(info.name)
  f.time:SetText(string.format("%.1f", left))
  -- 位置
  if not U.IsDragging(f) then
    local anch = DB["cast" .. f.castKey .. "Anchor"]
    f:ClearAllPoints()
    if anch then
      f:SetPoint(anch[1], UIParent, anch[2], anch[3], anch[4])
    else
      f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, f.castDefY)
    end
  end
  f:Show()
end

local function idleBar(f, label, unit)
  local W = math.max(120, math.min(520, (unit == "target" and DB.castTW or DB.castW) or CBW))
  local H = math.max(10, math.min(40, (unit == "target" and DB.castTH or DB.castH) or CBH))
  local rev = (unit == "target") and DB.castTReverse or DB.castReverse
  f:SetWidth(W)
  f:SetHeight(H)
  f.fill:SetHeight(H - 4)
  f.fill:ClearAllPoints()
  f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
  f.icon:SetWidth(H - 4)
  f.icon:SetHeight(H - 4)
  f:SetScale(math.max(0.6, math.min(2.0, (unit == "target" and DB.castTScale or DB.castScale) or 1)))
  if U.IsDragging(f) then return end
  f:ClearAllPoints()
  local anch = DB["cast" .. f.castKey .. "Anchor"]
  if anch then
    f:SetPoint(anch[1], UIParent, anch[2], anch[3], anch[4])
  else
    f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, f.castDefY)
  end
  f.fill:SetWidth(math.max(2, W - 4))
  f.icon:Hide()
  f.txt:SetPoint("LEFT", f, "LEFT", 8, 0)
  f.txt:SetText(label)
  f.time:SetText("")
  f:Show()
end

-- 施法相关事件：一有变化就刷，省掉空闲轮询
local castEv = CreateFrame("Frame", "AIbarCastEv")
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_SUCCEEDED",
  "PLAYER_TARGET_CHANGED" }
local cei
for cei = 1, #CAST_EVENTS do
  castEv:RegisterEvent(CAST_EVENTS[cei])
end
castEv:SetScript("OnEvent", function()
  if DB.castOn then U.UpdateCasts() end
end)

-- 施法条位置：拖动时存进 DB，但以前没有任何地方读回来，重登就回到默认位置。
function U.ApplyCastAnchors()
  local list = { { U.castSelf, DB.castSelfAnchor }, { U.castTarget, DB.castTargetAnchor } }
  local i
  for i = 1, #list do
    local f, a = list[i][1], list[i][2]
    if f and a and not U.IsDragging(f) then
      f:ClearAllPoints()
      f:SetPoint(a[1], UIParent, a[2], a[3], a[4])
    end
  end
end

function U.UpdateCasts()
  if not DB.castOn or DB.modCast == false then
    U.castSelf:Hide()
    U.castTarget:Hide()
    return
  end
  local sp, st = readCast("player"), readCast("target")
  -- 预览：模拟一次 3 秒施法
  local now2 = GetTime()
  if U.previewSelf then
    local ph = now2 % 3
    sp = { name = "预览", startT = now2 - ph, stopT = now2 - ph + 3 }
  end
  if U.previewTarget then
    local ph2 = now2 % 3
    st = { name = "预览", startT = now2 - ph2, stopT = now2 - ph2 + 3 }
  end
  paintBar(U.castSelf, "player", sp)
  paintBar(U.castTarget, "target", st)
end


end

do  -- 选择器
-- AIbar 选择器：技能 / 宏 / 物品
local U = AIbar
local COLS, ROWS = 7, 5
local PAGE_SIZE = COLS * ROWS

local f = CreateFrame("Frame", "AIbarPicker", UIParent)
f:SetWidth(COLS * 66 + 16)
f:SetHeight(ROWS * 66 + 134)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
f:SetFrameStrata("DIALOG")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function() this:StartMoving() end)
f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
f:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 12,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
f:SetBackdropColor(0.05, 0.05, 0.06, 0.96)
f:SetBackdropBorderColor(0.6, 0.5, 0.32, 1)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", f, "TOP", 0, -10)
title:SetText("|cffFFD200选择一个技能 / 宏 / 物品|r")

local state = { mode = "spell", page = 1, slot = 1, list = {} }

local function mkBtn(parent, text, x, y, w, h, fn)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(w); b:SetHeight(h)
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  b:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  b:SetBackdropColor(0.18, 0.16, 0.12, 0.92)
  b:SetBackdropBorderColor(0.5, 0.42, 0.28, 1)
  local l = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  l:SetPoint("CENTER", b, "CENTER", 0, 0)
  l:SetText(text)
  b.lbl = l
  b:SetScript("OnClick", fn)
  return b
end

local tabs = {}
local function setMode(m)
  state.mode = m
  state.page = 1
  local i
  for i = 1, #tabs do
    if tabs[i].key == m then
      tabs[i]:SetBackdropColor(0.3, 0.26, 0.16, 0.95)
    else
      tabs[i]:SetBackdropColor(0.18, 0.16, 0.12, 0.92)
    end
  end
  U.RefreshPicker()
end

local tabDefs = { { "spell", "技能" }, { "macro", "宏" }, { "item", "物品" } }
local t
for t = 1, 3 do
  local d = tabDefs[t]
  tabs[t] = mkBtn(f, d[2], 8 + (t - 1) * 86, -30, 80, 28, function()
    setMode(this.key)
  end)
  tabs[t].key = d[1]
end

local cells = {}
local c
for c = 1, PAGE_SIZE do
  local b = CreateFrame("Button", nil, f)
  b:SetWidth(60); b:SetHeight(60)
  local col = (c - 1) % COLS
  local row = math.floor((c - 1) / COLS)
  b:SetPoint("TOPLEFT", f, "TOPLEFT", 9 + col * 66, -(66 + row * 66))
  b.slotArt = b:CreateTexture(nil, "BACKGROUND")
  b.slotArt:SetAllPoints(b)
  b.slotArt:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.hl:SetAllPoints(b)
  b.hl:SetTexture(1, 1, 1, 0.2)
  b:SetScript("OnClick", function()
    if this.entry and this.entry.assign then
      this.entry.assign()
      U.Refresh()
      f:Hide()
    end
  end)
  b:SetScript("OnEnter", function()
    if this.entry and this.entry.label then
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(this.entry.label, 1, 1, 1)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  cells[c] = b
end

local pageLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pageLbl:SetPoint("TOP", f, "TOP", 0, -(66 + ROWS * 66 + 4))

mkBtn(f, "上一页", 9, -(66 + ROWS * 66 + 28), 104, 32, function()
  if state.page > 1 then state.page = state.page - 1; U.RefreshPicker() end
end)
mkBtn(f, "下一页", 119, -(66 + ROWS * 66 + 28), 104, 32, function()
  if state.page * PAGE_SIZE < #state.list then state.page = state.page + 1; U.RefreshPicker() end
end)
mkBtn(f, "清空", COLS * 66 - 208, -(66 + ROWS * 66 + 28), 92, 32, function()
  local slot = state and state.slot
  if not slot then return end
  if type(PickupAction) == "function" then
    pcall(PickupAction, slot)
    if type(ClearCursor) == "function" then pcall(ClearCursor) end
  end
  U.Refresh()
end)

mkBtn(f, "关闭", COLS * 66 - 100, -(66 + ROWS * 66 + 28), 92, 32, function() f:Hide() end)

-- ---- 数据 ----
local function collectSpells()
  local out = {}
  if not GetNumSpellTabs then return out end
  local tab = 1
  local n = GetNumSpellTabs()
  while tab <= n do
    local nm, tex, off, num = GetSpellTabInfo(tab)
    if num and off then
      local k
      for k = 1, num do
        local id = off + k
        local sname = GetSpellName(id, BOOKTYPE_SPELL)
        if sname then
          local ic = GetSpellTexture(id, BOOKTYPE_SPELL) or tex
          local nmLocal = sname
          out[#out + 1] = {
            icon = ic,
            label = nmLocal,
            assign = function()
              local bt = (type(BOOKTYPE_SPELL) == "string") and BOOKTYPE_SPELL or "spell"
              if type(PickupSpell) == "function" then pcall(PickupSpell, id, bt) end
              if type(PlaceAction) == "function" then pcall(PlaceAction, state.slot) end
              if type(ClearCursor) == "function" then pcall(ClearCursor) end
            end,
          }
        end
      end
    end
    tab = tab + 1
  end
  return out
end

local function collectMacros()
  local out = {}
  if type(GetNumMacros) ~= "function" or type(GetMacroInfo) ~= "function" then return out end
  -- EH_Bar 的写法：GetNumMacros 返回 通用数 + 角色专用数，两者要相加
  local okn, na, nc = pcall(GetNumMacros)
  local total = 0
  if okn then
    total = (tonumber(na) or 0) + (tonumber(nc) or 0)
  end
  -- 有的客户端把角色宏放在更大的下标上，直接扫到 72 个兜底
  if total < 72 then total = 72 end
  local seen = {}
  local i
  for i = 1, total do
    local oki, mn, mt = pcall(GetMacroInfo, i)
    if not (oki and type(mn) == "string" and mn ~= "") then
      -- 有的客户端角色宏要带第二个参数
      oki, mn, mt = pcall(GetMacroInfo, i, true)
    end
    if not (oki and type(mn) == "string" and mn ~= "") then
      oki, mn, mt = pcall(GetMacroInfo, i, 1)
    end
    if oki and type(mn) == "string" and mn ~= "" and not seen[mn] then
      seen[mn] = true
      local idx = i
      out[#out + 1] = {
        icon = mt or "Interface\\Icons\\INV_Misc_Note_01",
        label = mn,
        assign = function()
          if type(PickupMacro) == "function" then pcall(PickupMacro, idx) end
          if type(PlaceAction) == "function" then pcall(PlaceAction, state.slot) end
          if type(ClearCursor) == "function" then pcall(ClearCursor) end
        end,
      }
    end
  end
  return out
end

local function collectItems()
  local out = {}
  local bag
  for bag = 0, 4 do
    local slots = GetContainerNumSlots(bag) or 0
    local s
    for s = 1, slots do
      local tex, count = GetContainerItemInfo(bag, s)
      if tex then
        local link = GetContainerItemLink(bag, s)
        local nm = link or "物品"
        local b2, s2 = bag, s
        out[#out + 1] = {
          icon = tex,
          label = nm .. (count and count > 1 and (" x" .. count) or ""),
          assign = function()
            PickupContainerItem(b2, s2)
            PlaceAction(state.slot)
            ClearCursor()
          end,
        }
      end
    end
  end
  return out
end

function U.RefreshPicker()
  if state.mode == "spell" then state.list = collectSpells()
  elseif state.mode == "macro" then state.list = collectMacros()
  else state.list = collectItems() end

  local start = (state.page - 1) * PAGE_SIZE
  local c2
  for c2 = 1, PAGE_SIZE do
    local cell = cells[c2]
    local e = state.list[start + c2]
    if e then
      cell.entry = e
      cell.icon:SetTexture(e.icon)
      cell:Show()
    else
      cell.entry = nil
      cell.icon:SetTexture(nil)
      cell:Hide()
    end
  end
  local pages = math.ceil(#state.list / PAGE_SIZE)
  if pages < 1 then pages = 1 end
  if state.mode == "macro" and #state.list == 0 then
    pageLbl:SetText("|cffff8888客户端没有提供宏列表，直接用技能即可|r")
  else
    pageLbl:SetText("第 " .. state.page .. " / " .. pages .. " 页 · 共 " .. #state.list .. " 项")
  end
end

function U.OpenPicker(slot)
  state.slot = slot
  setMode(state.mode or "spell")
  f:Show()
end

f:Hide()

end

do  -- 背包整合（展示 + 长按拿起）
local U = AIbar
local COLS, ICON, GAP = 10, 44, 4
local CELL = ICON + GAP
local MAXCELL = 160         -- 最多 16 列 × 10 行
local KEYRING = -2          -- 原版钥匙栏的容器编号
local HOLD = 1.5            -- 长按出菜单（1.5 秒，留出手指点击延迟）
local merchantOpen, autoBag = false, false

local f = CreateFrame("Frame", "AIbarBag", UIParent)
-- 放低层级：原生对话框（帮助/GM/弹出提示）都盖在它上面
f:SetFrameStrata("LOW")
if f.SetFrameLevel then f:SetFrameLevel(1) end

-- 拖动层：必须最先创建，保证在所有按钮/格子之下
local dragAll = CreateFrame("Button", "AIbarBagDrag", f)
dragAll:SetAllPoints(f)
U.MakeDraggable(f, dragAll, {
  drop = function(pt, relf, rp, x, y) DB.bagAnchor = { pt, rp, x, y } end,
})

-- 标题栏整条也能拖（按钮在上面，不受影响）
local dragTop = CreateFrame("Button", "AIbarBagDragTop", f)
dragTop:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
dragTop:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
dragTop:SetHeight(44)
U.MakeDraggable(f, dragTop, {
  drop = function(pt, relf, rp, x, y) DB.bagAnchor = { pt, rp, x, y } end,
})
f:SetWidth(COLS * CELL + 12)
f:SetHeight(200)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
f:SetMovable(true)
f:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 12,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
f:SetBackdropColor(0.05, 0.05, 0.06, 0.96)
f:SetBackdropBorderColor(0.6, 0.5, 0.32, 1)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -8)
title:SetText("")

local gold = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
gold:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)

local sortBtn = CreateFrame("Button", nil, f)
sortBtn:SetWidth(U.TouchMode and 72 or 64)
sortBtn:SetHeight(U.TouchMode and 32 or 28)
sortBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", U.TouchMode and -86 or -78, -6)
sortBtn:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 8,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
sortBtn:SetBackdropColor(0.18, 0.16, 0.12, 0.92)
sortBtn:SetBackdropBorderColor(0.5, 0.42, 0.28, 1)
local sl = sortBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sl:SetPoint("CENTER", sortBtn, "CENTER")
sl:SetText("整理")
sortBtn:SetScript("OnClick", function()
  local ok = U.BagSort()
  U.BagRefresh()
  if DEFAULT_CHAT_FRAME then
    if ok then DEFAULT_CHAT_FRAME:AddMessage("|cff7CECFFAiBar|r 背包已整理")
    else DEFAULT_CHAT_FRAME:AddMessage("|cff7CECFFAiBar|r 有物品正在移动，稍后再试") end
  end
end)

local close = CreateFrame("Button", nil, f)
close:SetWidth(U.TouchMode and 72 or 64)
close:SetHeight(U.TouchMode and 32 or 28)
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
close:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 8,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
close:SetBackdropColor(0.18, 0.16, 0.12, 0.92)
close:SetBackdropBorderColor(0.5, 0.42, 0.28, 1)
local cl = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cl:SetPoint("CENTER", close, "CENTER")
cl:SetText("关闭")
close:SetScript("OnClick", function()
  if U.CloseBagMenu then U.CloseBagMenu() end
  f:Hide()
  U.RestoreBagIcon()
  U.bagClosedAt = GetTime()
end)

-- 顶部弹出的设置面板（点「设置」出现）
local cfgB = CreateFrame("Button", "AIbarBagCfgBtn", f)
cfgB:SetWidth(U.TouchMode and 72 or 64)
cfgB:SetHeight(U.TouchMode and 32 or 28)
cfgB:SetPoint("TOPRIGHT", f, "TOPRIGHT", U.TouchMode and -164 or -148, -6)
cfgB:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 8,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
cfgB:SetBackdropColor(0.18, 0.16, 0.12, 0.92)
cfgB:SetBackdropBorderColor(0.5, 0.42, 0.28, 1)
local cbl = cfgB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cbl:SetPoint("CENTER", cfgB, "CENTER")
cbl:SetText("设置")

local sp = CreateFrame("Frame", "AIbarBagOpt", f)
sp:SetWidth(268)
sp:SetHeight(112)
sp:SetPoint("BOTTOM", f, "TOP", 0, 2)
sp:SetFrameStrata("TOOLTIP")
if sp.SetFrameLevel then sp:SetFrameLevel(30) end
sp:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 10,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
sp:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
sp:SetBackdropBorderColor(0.6, 0.5, 0.32, 1)
sp:Hide()

local spCatcher = CreateFrame("Frame", nil, UIParent)
spCatcher:SetAllPoints(UIParent)
spCatcher:SetFrameStrata("TOOLTIP")
if spCatcher.SetFrameLevel then spCatcher:SetFrameLevel(29) end
spCatcher:EnableMouse(true)
spCatcher:Hide()
spCatcher:SetScript("OnMouseDown", function()
  sp:Hide()
  spCatcher:Hide()
end)

local spRefresh = {}
local function spBtn(parent, text, x, y, w, fn)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(w or 24)
  b:SetHeight(22)
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  b:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  b:SetBackdropColor(0.18, 0.16, 0.12, 0.92)
  b:SetBackdropBorderColor(0.5, 0.42, 0.28, 1)
  local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t:SetPoint("CENTER", b, "CENTER")
  t:SetText(text)
  b:SetScript("OnClick", fn)
  return b
end

local function spRow(n, label, key, min, max, suffix)
  local y = -10 - (n - 1) * 34
  local lb = sp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lb:SetPoint("TOPLEFT", sp, "TOPLEFT", 12, y)
  lb:SetText(label)
  local val = sp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  val:SetPoint("TOPLEFT", sp, "TOPLEFT", 128, y)
  local function refresh()
    val:SetText(tostring(DB[key]) .. (suffix or ""))
  end
  spRefresh[#spRefresh + 1] = refresh
  spBtn(sp, "-", 96, y - 5, 24, function()
    DB[key] = math.max(min, (DB[key] or min) - (key == "bagIcon" and 4 or 1))
    refresh()
    U.BagRefresh()
  end)
  spBtn(sp, "+", 192, y - 5, 24, function()
    DB[key] = math.min(max, (DB[key] or min) + (key == "bagIcon" and 4 or 1))
    refresh()
    U.BagRefresh()
  end)
  refresh()
end

spRow(1, "图标大小", "bagIcon", 28, 64, " px")
spRow(2, "横向格数", "bagCols", 4, 16, "")
spRow(3, "纵向格数", "bagRows", 2, 10, "")


cfgB:SetScript("OnClick", function()
  if sp:IsShown() then
    sp:Hide()
    spCatcher:Hide()
    return
  end
  local i
  for i = 1, #spRefresh do spRefresh[i]() end
  sp:ClearAllPoints()
  local top = f:GetTop()
  local H = UIParent:GetHeight() or 768
  if top and top + sp:GetHeight() + 4 <= H then
    sp:SetPoint("BOTTOM", f, "TOP", 0, 2)          -- 窗口上方
  else
    local bottom = f:GetBottom()
    if bottom and bottom - sp:GetHeight() - 4 >= 0 then
      sp:SetPoint("TOP", f, "BOTTOM", 0, -2)       -- 放不下就放窗口下方
    else
      sp:SetPoint("TOP", UIParent, "TOP", 0, -8)   -- 都放不下就贴屏幕上边
    end
  end
  spCatcher:Show()
  sp:Show()
end)

-- 顶部小背包栏：全部 / 背包 / 各包 / 钥匙（横排）
local bagTabs = {}
local function mkTab(label, key, idx)
  local b = CreateFrame("Button", nil, f)
  b:SetWidth(54)
  b:SetHeight(24)
  b:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + (idx - 1) * 56, -32)
  b:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  b:SetBackdropColor(0.16, 0.15, 0.14, 0.95)
  b:SetBackdropBorderColor(0.4, 0.37, 0.33, 1)
  local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t:SetPoint("CENTER", b, "CENTER")
  t:SetText(label)
  b.lbl = t
  b.key = key
  b:SetScript("OnClick", function()
    U.bagFilter = key
    U.bagPage = 1
    U.BagRefresh()
  end)
  bagTabs[#bagTabs + 1] = b
  return b
end

local tabAll = mkTab("全部", "all", 1)
local tabBags = {}
local tb
for tb = 0, 4 do
  tabBags[tb] = mkTab(tb == 0 and "背包" or ("包" .. tb), tb, tb + 2)
end
local tabKey = mkTab("钥匙", KEYRING, 7)


-- 分页
local pagePrev = CreateFrame("Button", nil, f)
pagePrev:SetWidth(58)
pagePrev:SetHeight(22)
pagePrev:SetPoint("TOPLEFT", f, "TOPLEFT", 150, -6)
local ppTxt = pagePrev:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ppTxt:SetPoint("CENTER", pagePrev, "CENTER")
ppTxt:SetText("上一页")

local pageTxt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pageTxt:SetPoint("TOPLEFT", f, "TOPLEFT", 196, -10)

local pageNext = CreateFrame("Button", nil, f)
pageNext:SetWidth(58)
pageNext:SetHeight(22)
pageNext:SetPoint("TOPLEFT", f, "TOPLEFT", 264, -6)
local pnTxt = pageNext:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pnTxt:SetPoint("CENTER", pageNext, "CENTER")
pnTxt:SetText("下一页")

pagePrev:SetScript("OnClick", function()
  U.bagPage = math.max(1, (U.bagPage or 1) - 1)
  U.BagRefresh()
end)
pageNext:SetScript("OnClick", function()
  U.bagPage = (U.bagPage or 1) + 1
  U.BagRefresh()
end)
pagePrev:Hide(); pageNext:Hide(); pageTxt:Hide()

local map = {}              -- cell -> {bag, slot}
local cells = {}

-- 右键菜单：3 列网格，和原生一致
local menu = CreateFrame("Frame", "AIbarBagMenu", UIParent)
menu:SetFrameStrata("TOOLTIP")
if menu.SetFrameLevel then menu:SetFrameLevel(20) end
menu:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 10,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
menu:SetBackdropColor(0.05, 0.05, 0.06, 0.96)
menu:SetBackdropBorderColor(0.6, 0.5, 0.32, 1)
menu:Hide()

function U.CloseBagMenu()
  local m = G("AIbarBagMenu")
  if m and m.Hide then pcall(m.Hide, m) end
end

local catcher = CreateFrame("Frame", nil, UIParent)
catcher:SetAllPoints(UIParent)
catcher:SetFrameStrata("TOOLTIP")
if catcher.SetFrameLevel then catcher:SetFrameLevel(10) end
catcher:EnableMouse(true)
catcher:Hide()
catcher:SetScript("OnMouseDown", function()
  menu:Hide(); catcher:Hide(); GameTooltip:Hide()
  U.tipHideAt = GetTime() + 0.15   -- 鼠标仍在格子上时会被重新弹出，稍后再关一次
end)

local MCOLS, MW, MH, MG = 3, (U.TouchMode and 120 or 104), (U.TouchMode and 42 or 34), (U.TouchMode and 5 or 4)
local mItems = {}
local function mAdd(i, text, fn)
  local b = mItems[i]
  if not b then
    b = CreateFrame("Button", nil, menu)
    b:SetWidth(MW)
    b:SetHeight(MH)
    b:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    b:SetBackdropColor(0.16, 0.15, 0.14, 0.95)
    b:SetBackdropBorderColor(0.45, 0.38, 0.28, 1)
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("CENTER", b, "CENTER")
    pcall(function()
      local fn, sz = t:GetFont()
      if fn then t:SetFont(fn, (sz or 12) + 2, "OUTLINE") end
    end)
    b.txt = t
    mItems[i] = b
  end
  b.txt:SetText(text)
  b:SetScript("OnClick", function()
    menu:Hide()
    catcher:Hide()
    GameTooltip:Hide()
    U.tipHideAt = GetTime() + 0.15
    fn()
  end)
  b:Show()
end

local function menuTip(bag, slot, anchor, width)
  if not bag then return end
  GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
  if type(GameTooltip.SetBagItem) == "function" then
    pcall(GameTooltip.SetBagItem, GameTooltip, bag, slot)
  elseif type(GameTooltip.SetHyperlink) == "function" then
    local link = GetContainerItemLink(bag, slot)
    if link then pcall(GameTooltip.SetHyperlink, GameTooltip, link) end
  end
  if type(GameTooltip.SetWidth) == "function" then
    pcall(GameTooltip.SetWidth, GameTooltip, width or anchor:GetWidth())
  end
  GameTooltip:ClearAllPoints()
  -- 提示框仍在物品格子上方（保持原来的位置）
  local vw2, vh2 = U.VisibleRect()
  local tw = math.max(200, math.min(width or 300, 300))
  if type(GameTooltip.SetWidth) == "function" then
    pcall(GameTooltip.SetWidth, GameTooltip, tw)
  end
  GameTooltip:SetPoint("BOTTOM", anchor, "TOP", 0, 2)
  -- 提示框和菜单都在 TOOLTIP 层，菜单会盖住装备信息；这里把提示框再抬高一层
  pcall(function()
    local lv = 40
    if anchor and anchor.GetFrameLevel then lv = (anchor:GetFrameLevel() or 20) + 20 end
    GameTooltip:SetFrameLevel(lv)
  end)
  GameTooltip:Show()
  -- 菜单靠屏幕上方时，提示框改放到菜单下面，避免顶出屏幕
  local tt
  if type(GameTooltip.GetTop) == "function" then tt = GameTooltip:GetTop() end
  local _, uh = U.VisibleRect()
  if tt and uh and tt > uh - 4 then
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
    pcall(function() GameTooltip:SetFrameLevel(40) end)
  end
end

local function showMenu(list, cell, bag, slot)
  local n = #list
  local i
  for i = 1, n do
    mAdd(i, list[i][1], list[i][2])
    local b = mItems[i]
    local col = (i - 1) % MCOLS
    local row = math.floor((i - 1) / MCOLS)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", menu, "TOPLEFT", 4 + col * (MW + MG), -(4 + row * (MH + MG)))
  end
  for i = n + 1, #mItems do mItems[i]:Hide() end
  local rows = math.max(1, math.ceil(n / MCOLS))
  menu:SetWidth((MW + MG) * MCOLS + 4)
  menu:SetHeight(rows * (MH + MG) + 8)
  menu:ClearAllPoints()
  local ch = (cell.GetHeight and cell:GetHeight()) or 40
  local mh = menu:GetHeight() or 89
  menu:SetPoint("CENTER", cell, "CENTER", 0, 0)   -- 先摆好只为量尺寸，稍后挂到提示框下边
  catcher:Show()
  menu:Show()
  menuTip(bag, slot, cell, (MW + MG) * MCOLS + 4)
  -- 菜单挂在提示框下沿，左对齐；不再跟着物品格子
  if type(GameTooltip.GetBottom) == "function" and GameTooltip:IsShown() then
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 0, -4)
  end
  -- 菜单贴着格子下沿摆好后，再按屏幕范围夹一下位置
  do
    local L, T = menu:GetLeft(), menu:GetTop()
    local vw, vh = U.VisibleRect()
    if L and T and mh and mh > 0 then
      local dx, dy = 0, 0
      local mw2 = menu:GetWidth() or 0
      if L < 4 then dx = 4 - L
      elseif L + mw2 > vw - 4 then dx = (vw - 4) - (L + mw2) end
      if T - mh < 4 then dy = 4 - (T - mh) end
      if dx ~= 0 or dy ~= 0 then
        menu:ClearAllPoints()
        if type(GameTooltip.GetBottom) == "function" and GameTooltip:IsShown() then
          menu:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", dx, -4 + dy)
        else
          menu:SetPoint("CENTER", cell, "CENTER", dx, dy)
        end
      end
    end
  end
end

local function firstEmptyAction()
  local i
  for i = 1, 12 do
    local a = U.SlotOf(i)
    if not GetActionTexture(a) then return a end
  end
end

-- 物品归类：equip 装备 / mat 材料（不能直接用）/ use 可用
local EQUIP_WORDS = { "INVTYPE_", "护甲", "武器", "Armor", "Weapon" }
local MAT_WORDS = { "材料", "商品", "Trade Goods", "Tradeskill", "配方", "Recipe",
                    "附魔", "Enchant", "制皮", "Leatherwork", "锻造", "Blacksmith",
                    "裁缝", "Tailor", "工程", "Engineer", "炼金", "Alchemy",
                    "草药", "Herb", "矿石", "Ore", "宝石", "Gem", "布", "线" }

-- 背包工具：分类 + 出售（合成一张表，避免局部变量超限）
local BU = {
  -- 装备：穿了才有意义的东西；背包（INVTYPE_BAG）不算装备
  equipWords = { "护甲", "武器", "Armor", "Weapon" },
  -- 材料：只能用/卖，没有“使用”动作
  matWords = { "材料", "商品", "Trade Goods" },
}

function BU.cat(bag, slot)
  local k = BU.kind(bag, slot)
  if k == "equip" then return "equip" end
  if k == "mat" then return "mat" end
  local link = GetContainerItemLink(bag, slot)
  if link and type(GetItemInfo) == "function" then
    local ret = { pcall(GetItemInfo, link) }
    local i
    for i = 2, #ret do
      local t = ret[i]
      if type(t) == "string" then
        if string.find(t, "任务", 1, true) or string.find(t, "Quest", 1, true) then return "quest" end
        if string.find(t, "消耗", 1, true) or string.find(t, "Consumable", 1, true) then return "use" end
      end
    end
  end
  return "use"
end

function BU.kind(bag, slot)
  local link = GetContainerItemLink(bag, slot)
  if not link or type(GetItemInfo) ~= "function" then return "use" end
  local ret = { pcall(GetItemInfo, link) }
  if not ret[1] then return "use" end
  local texts = {}
  local i
  for i = 2, #ret do
    if type(ret[i]) == "string" and ret[i] ~= "" then texts[#texts + 1] = ret[i] end
  end
  local k
  -- 装备位：以 INVTYPE_ 开头，但背包不算
  for k = 1, #texts do
    local t = texts[k]
    if string.find(t, "INVTYPE_") and not string.find(t, "INVTYPE_BAG") then return "equip" end
  end
  for k = 1, #texts do
    local j
    for j = 1, #BU.equipWords do
      if string.find(texts[k], BU.equipWords[j], 1, true) then return "equip" end
    end
  end
  for k = 1, #texts do
    local j
    for j = 1, #BU.matWords do
      if string.find(texts[k], BU.matWords[j], 1, true) then return "mat" end
    end
  end
  return "use"
end

-- 出售：模仿原生“在商店里右键点物品”
function BU.sell(bag, slot)
  if type(SellCursorItem) == "function" and type(PickupContainerItem) == "function" then
    pcall(PickupContainerItem, bag, slot)
    if pcall(SellCursorItem) then return true end
  end
  if type(SellItem) == "function" then
    if pcall(SellItem, bag, slot) then return true end
  end
  local nb = G("ContainerFrame" .. (bag + 1) .. "Item" .. slot)
  if nb then
    local h = nb.GetScript and nb:GetScript("OnClick")
    if h then
      local ok = pcall(function()
        local oldThis, oldArg = _G.this, _G.arg1
        _G.this, _G.arg1 = nb, "RightButton"
        h()
        _G.this, _G.arg1 = oldThis, oldArg
      end)
      if ok then return true end
    end
  end
  return false
end

-- 分类过滤行
BU.catBtns = {}
do
  local CATS = { { nil, "全部" }, { "equip", "装备" }, { "use", "消耗" },
                 { "mat", "材料" }, { "quest", "任务" } }
  local i
  for i = 1, #CATS do
    local c = CreateFrame("Button", nil, f)
    c:SetWidth(54)
    c:SetHeight(22)
    c:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + (i - 1) * 56, -58)
    c:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    c:SetBackdropColor(0.16, 0.15, 0.14, 0.95)
    c:SetBackdropBorderColor(0.4, 0.37, 0.33, 1)
    local t = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t:SetPoint("CENTER", c, "CENTER")
    t:SetText(CATS[i][2])
    c.key = CATS[i][1]
    c:SetScript("OnClick", function()
      U.bagCat = this.key
      U.BagRefresh()
    end)
    BU.catBtns[#BU.catBtns + 1] = c
  end
end

function U.BagMenu(cell, bag, slot)
  local list = {}
  local merchant = merchantOpen or (MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown())
  if merchant then
  end
  -- 装备显示“装备”，普通物品显示“使用”，材料两个都不给
  local kind = BU.kind(bag, slot)
  if kind ~= "mat" then
    local useLabel = (kind == "equip") and "装备" or "使用"
    list[#list + 1] = { useLabel, function()
      if type(UseContainerItem) == "function" then UseContainerItem(bag, slot) end
      U.BagRefresh()
    end }
  end
  list[#list + 1] = { "丢弃", function()
    local link = GetContainerItemLink(bag, slot)
    showMenu({
      { "确认丢弃", function()
        if type(PickupContainerItem) == "function" then pcall(PickupContainerItem, bag, slot) end
        if type(DeleteCursorItem) == "function" then
          pcall(DeleteCursorItem)
        else
          if type(ClearCursor) == "function" then pcall(ClearCursor) end
          if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff7CECFFAiBar|r 这个客户端不支持直接销毁，请用原生背包")
          end
        end
        U.BagRefresh()
      end },
      { "取消", function() end },
    }, cell, bag, slot)
    if link and DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cff7CECFFAiBar|r 要丢弃：" .. link)
    end
  end }
  list[#list + 1] = { "拿起", function()
    if type(PickupContainerItem) == "function" then PickupContainerItem(bag, slot) end
  end }
  if kind == "equip" then
    list[#list + 1] = { "试穿", function()
      local link = GetContainerItemLink(bag, slot)
      if link and type(DressUpItemLink) == "function" then pcall(DressUpItemLink, link) end
    end }
  end
  -- 链接放最后，避免和常用操作挤在一起误点
  list[#list + 1] = { "链接", function()
    local link = GetContainerItemLink(bag, slot)
    if link and type(ChatEdit_InsertLink) == "function" then pcall(ChatEdit_InsertLink, link) end
  end }
  showMenu(list, cell, bag, slot)
end
local function makeCell(k)
  local b = CreateFrame("Button", nil, f)
  b:SetWidth(ICON)
  b:SetHeight(ICON)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.icon:Hide()
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints(b)
  b.bg:SetTexture(0.10, 0.10, 0.11, 0.85)
  b.cnt = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.cnt:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  b.border = b:CreateTexture(nil, "OVERLAY")
  b.border:SetAllPoints(b)
  b.border:SetTexture(BORDER)
  b.border:Hide()

  b.qdotBg = b:CreateTexture(nil, "OVERLAY")
  b.qdotBg:SetWidth(12)
  b.qdotBg:SetHeight(12)
  b.qdotBg:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
  b.qdotBg:SetTexture(0, 0, 0, 0.9)
  b.qdotBg:Hide()

  b.qdot = b:CreateTexture(nil, "OVERLAY")
  b.qdot:SetWidth(8)
  b.qdot:SetHeight(8)
  b.qdot:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  b.qdot:SetTexture(1, 1, 1, 1)
  b.qdot:Hide()
  b:SetScript("OnEnter", function()
    local m = map[this.idx]
    if m and m.bag and m.tex then
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      if type(GameTooltip.SetBagItem) == "function" then
        pcall(GameTooltip.SetBagItem, GameTooltip, m.bag, m.slot)
      elseif type(GameTooltip.SetHyperlink) == "function" then
        local link = GetContainerItemLink(m.bag, m.slot)
        if link then pcall(GameTooltip.SetHyperlink, GameTooltip, link) end
      end
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnMouseDown", function() this.downT = GetTime() end)
  b:SetScript("OnClick", function()
    local m = map[this.idx]
    if not m or not m.bag then return end
    -- 手上有东西：点空格=放下，点物品=交换
    if type(CursorHasItem) == "function" and CursorHasItem() then
      if type(PickupContainerItem) == "function" then PickupContainerItem(m.bag, m.slot) end
      U.BagRefresh()
      return
    end
    -- 空格子不弹菜单
    if not m.tex then return end
    local held = this.downT and (GetTime() - this.downT) or 0
    this.downT = nil
    local btn = arg1
    if type(EVAL_RMB_BTN) == "function" then
      local ok, v = pcall(EVAL_RMB_BTN, btn)
      if ok and type(v) == "string" and v ~= "" then btn = v end
    end
    if U.bagSellMode then
      if type(UseContainerItem) == "function" then UseContainerItem(m.bag, m.slot) end
      U.BagRefresh()
      return
    end
    if btn == "RightButton" then
      if type(UseContainerItem) == "function" then UseContainerItem(m.bag, m.slot) end
      U.BagRefresh()
    elseif held > HOLD then
      -- 长按：拿起
      if type(PickupContainerItem) == "function" then PickupContainerItem(m.bag, m.slot) end
    else
      -- 点击：出菜单
      U.BagMenu(this, m.bag, m.slot)
    end
  end)
  b.idx = k
  return b
end

local QUALCOL = {
  [0] = { 0.62, 0.62, 0.62 },
  [1] = { 1.00, 1.00, 1.00 },
  [2] = { 0.12, 1.00, 0.00 },
  [3] = { 0.00, 0.44, 0.87 },
  [4] = { 0.64, 0.21, 0.93 },
  [5] = { 1.00, 0.50, 0.00 },
}

local QUAL = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2,
               ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }

local function itemMeta(bag, slot)
  local tex, count, locked, quality = GetContainerItemInfo(bag, slot)
  if not tex then return nil end
  local link = GetContainerItemLink(bag, slot) or ""
  local hex = string.lower(string.match(link, "|cff(%x%x%x%x%x%x)") or "ffffff")
  local name = string.match(link, "%[(.-)%]") or ("item" .. tostring(slot))
  return {
    q = QUAL[hex] or quality or 1,
    name = name,
    count = count or 1,
    locked = locked and true or false,
  }
end

-- 逐格搬运式整理：品质高的在前，再按名称，数量多的在前
function U.BagSort()
  if type(CursorHasItem) == "function" and CursorHasItem() then return false end
  local slots = {}
  local bag
  for bag = 0, 4 do
    local n = GetContainerNumSlots(bag) or 0
    local btype = 0
    if type(GetContainerNumFreeSlots) == "function" then
      local ok, _, t = pcall(GetContainerNumFreeSlots, bag)
      if ok and type(t) == "number" then btype = t end
    end
    if btype == 0 then          -- 只动普通包，特化包（矿石袋/灵魂袋等）不碰
      local s
      for s = 1, n do slots[#slots + 1] = { bag = bag, slot = s } end
    end
  end

  local items = {}
  local i
  for i = 1, #slots do
    local m = itemMeta(slots[i].bag, slots[i].slot)
    if m then
      m.id = i
      items[#items + 1] = m
    end
  end
  if #items < 2 then return true end

  table.sort(items, function(a, b)
    if a.q ~= b.q then return a.q > b.q end
    if a.name ~= b.name then return a.name < b.name end
    return a.count > b.count
  end)

  -- occ[槽位下标] = 该格现在的物品
  local occ, where = {}, {}
  for i = 1, #items do
    occ[items[i].id] = items[i]
    where[items[i].id] = items[i].id
  end

  for i = 1, #items do
    local want = items[i]
    if where[want.id] ~= i then
      local j = where[want.id]
      local a, b2 = slots[i], slots[j]
      if a.bag ~= b2.bag or a.slot ~= b2.slot then
        if type(PickupContainerItem) == "function" then
          -- 目标格是空的就从源格拿，否则两个都有东西才互换
          if GetContainerItemInfo(a.bag, a.slot) == nil then
            PickupContainerItem(b2.bag, b2.slot)
            PickupContainerItem(a.bag, a.slot)
          else
            PickupContainerItem(a.bag, a.slot)
            PickupContainerItem(b2.bag, b2.slot)
          end
          if type(ClearCursor) == "function" then ClearCursor() end
        end
      end
      occ[i], occ[j] = occ[j], occ[i]
      if occ[i] then where[occ[i].id] = i end
      if occ[j] then where[occ[j].id] = j end
    end
  end
  return true
end

function U.BagRefresh()
  if not f:IsShown() then return end
  local ICON = math.max(28, math.min(64, DB.bagIcon or 44))
  local cols = math.max(4, math.min(16, DB.bagCols or 10))
  local vrows = math.max(2, math.min(10, DB.bagRows or 5))
  local CELL = ICON + GAP
  local size
  f:SetWidth(cols * CELL + 16)

  -- 收集所有槽位（背包 + 4 个包，钥匙栏另算）
  local filt = U.bagFilter
  if filt == nil then filt = "all" end

  local all = {}
  local used, keyUsed, bagSlots = 0, 0, 0
  local bag
  for bag = 0, 4 do
    local slots = GetContainerNumSlots(bag) or 0
    local s
    for s = 1, slots do
      bagSlots = bagSlots + 1
      local tex, count, _, q = GetContainerItemInfo(bag, s)
      if tex then used = used + 1 end
      local okCat = true
      if U.bagCat and tex then okCat = (BU.cat(bag, s) == U.bagCat) end
      if okCat and (filt == "all" or filt == bag) then
        all[#all + 1] = { bag = bag, slot = s, tex = tex, count = count, q = q }
      end
    end
  end

  local kn = (type(GetContainerNumSlots) == "function") and (GetContainerNumSlots(KEYRING) or 0) or 0
  if kn > 0 then
    local hasKey = false
    local s2
    for s2 = 1, kn do
      if GetContainerItemInfo(KEYRING, s2) then hasKey = true; break end
    end
    if hasKey then
      for s2 = 1, kn do
        local tex, count, _, q2 = GetContainerItemInfo(KEYRING, s2)
        if tex then keyUsed = keyUsed + 1 end
        -- 钥匙栏只在点「钥匙」标签时显示，不占背包主视图
        if filt == KEYRING then
          all[#all + 1] = { bag = KEYRING, slot = s2, tex = tex, count = count, q = q2, key = true }
        end
      end
    end
  end

  -- 不分页：按实际槽位铺满；切标签时窗口大小保持不变
  local total = #all
  size = math.max(#all, bagSlots, kn or 0)
  if size < cols * vrows then size = cols * vrows end

  map = {}
  local k
  for k = 1, size do
    local it = all[k]
    if it then map[k] = it end
  end

  for k = 1, MAXCELL do
    local b = cells[k]
    if k <= size and not b then
      b = makeCell(k)
      cells[k] = b
    end
    if k <= size and b then
      local col = (k - 1) % cols
      local row = math.floor((k - 1) / cols)
      b:SetWidth(ICON)
      b:SetHeight(ICON)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + col * CELL, -(64 + row * CELL))
      local m = map[k]
      if m and m.key then
        b.bg:SetTexture(0.22, 0.18, 0.10, 0.9)
      else
        b.bg:SetTexture(0.10, 0.10, 0.11, 0.85)
      end
      if m and m.tex then
        b:Show()
        b.icon:Show()
        b.icon:SetTexture(m.tex)
        b.cnt:SetText((m.count and m.count > 1) and tostring(m.count) or "")
        local q = m.q or 1
        local col = QUALCOL[q] or QUALCOL[1]
        b.border:SetVertexColor(col[1], col[2], col[3], 0.55)
        b.border:Show()
        b.qdot:SetTexture(col[1], col[2], col[3], 1)
        b.qdot:Show()
        b.qdotBg:Show()
      else
        b:Show()
        b.icon:Hide()
        b.cnt:SetText("")
        b.border:Hide()
        b.qdot:Hide()
        b.qdotBg:Hide()
      end
    elseif b then
      b:Hide()
    end
  end

  f:SetHeight(math.max(1, math.ceil(size / cols)) * CELL + 64 + 30)

  -- 标签行已收进「筛选」按钮，保持隐藏
  local tb2
  for tb2 = 0, 4 do
    local t = tabBags[tb2]
    if t then t:Hide() end
  end
  tabKey:Hide()
  tabAll:Hide()
  local sel = (filt == "all") and tabAll or (filt == KEYRING and tabKey or tabBags[filt])
  local i2
  for i2 = 1, #bagTabs do
    local b = bagTabs[i2]
    if b == sel then
      b:SetBackdropColor(0.55, 0.44, 0.18, 1)
      b:SetBackdropBorderColor(1, 0.86, 0.35, 1)
    else
      b:SetBackdropColor(0.16, 0.15, 0.14, 0.95)
      b:SetBackdropBorderColor(0.4, 0.37, 0.33, 1)
    end
  end

  -- 左上角只留数字：总格数/已用格数，有钥匙时再补一个数字（不写文字）
  title:SetText(tostring(bagSlots) .. "/" .. tostring(used) ..
                (keyUsed > 0 and ("  " .. tostring(keyUsed)) or ""))

  -- 顶部按钮显示当前选中的条目
  if BU.bagBtn then
    local bn = "背包"
    if U.bagFilter == KEYRING then bn = "钥匙"
    elseif type(U.bagFilter) == "number" then bn = (U.bagFilter == 0) and "背包" or ("包" .. U.bagFilter) end
    BU.bagBtn.txt:SetText(bn)
  end
  if BU.catBtn then
    local cn = "分类"
    if U.bagCat == "equip" then cn = "装备"
    elseif U.bagCat == "use" then cn = "消耗"
    elseif U.bagCat == "mat" then cn = "材料"
    elseif U.bagCat == "quest" then cn = "任务" end
    BU.catBtn.txt:SetText(cn)
  end

  -- 分类按钮也收起来了
  local cN
  for cN = 1, #BU.catBtns do BU.catBtns[cN]:Hide() end

  -- 商店里的出售按钮
  if merchantOpen and BU.sellBtn then
    BU.sellBtn:Show()
    if U.bagSellMode then
      BU.sellLbl:SetText("点击出售")
      BU.sellBtn:SetBackdropColor(0.55, 0.30, 0.20, 1)
      BU.sellBtn:SetBackdropBorderColor(1, 0.6, 0.4, 1)
    else
      BU.sellLbl:SetText("出售")
      BU.sellBtn:SetBackdropColor(0.16, 0.15, 0.14, 0.95)
      BU.sellBtn:SetBackdropBorderColor(0.45, 0.38, 0.28, 1)
    end
  elseif BU.sellBtn then
    BU.sellBtn:Hide()
    U.bagSellMode = false
  end

  -- 分页
  pagePrev:Hide()
  pageNext:Hide()
  pageTxt:Hide()

  local money = (type(GetMoney) == "function") and (GetMoney() or 0) or 0
  local g = math.floor(money / 10000)
  local s3 = math.floor((money % 10000) / 100)
  local c3 = money % 100
  gold:SetText(string.format("|cffffd700%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", g, s3, c3))
end

-- 背包按钮图标：钉死成标准背包图，客户端想切换就忽略
local BAGICON = "Interface\\Icons\\INV_Misc_Bag_08"

local function pinTexture(tex)
  if not tex or tex.__aiPinned or not tex.SetTexture then return end
  local orig = tex.SetTexture
  tex.__aiPinned = true
  tex.SetTexture = function(self, t, ...)
    if t and t ~= BAGICON then return end
    return orig(self, t, ...)
  end
  pcall(orig, tex, BAGICON)
end

-- 直接盖一张自己的图，客户端底下怎么换都看不见
local function coverBagIcon()
  local btn = G("MainMenuBarBackpackButton")
  if not btn then return end
  if btn.__aiCover then
    pcall(btn.__aiCover.Show, btn.__aiCover)
    return
  end
  local fr = CreateFrame("Frame", "AIbarBagIconCover", btn)
  fr:SetAllPoints(btn)
  if fr.SetFrameStrata then pcall(fr.SetFrameStrata, fr, "TOOLTIP") end
  if fr.SetFrameLevel then
    local lv = 0
    local ok, v = pcall(function() return btn:GetFrameLevel() end)
    if ok and type(v) == "number" then lv = v end
    pcall(fr.SetFrameLevel, fr, lv + 20)
  end
  local tex = fr:CreateTexture(nil, "ARTWORK")
  -- 有原始图标纹理就贴着它，没有就按按钮大小内缩一圈
  local it = G("MainMenuBarBackpackButtonIconTexture")
  if it and it.GetWidth then
    local ok, w = pcall(it.GetWidth, it)
    if ok and type(w) == "number" and w > 4 then
      tex:SetAllPoints(it)
    else
      tex:SetAllPoints(fr)
    end
  else
    local ok, w = pcall(function() return btn:GetWidth() end)
    local inset = (ok and type(w) == "number") and math.max(2, math.floor(w * 0.08)) or 2
    tex:SetPoint("TOPLEFT", fr, "TOPLEFT", inset, -inset)
    tex:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -inset, inset)
  end
  tex:SetTexture(BAGICON)
  tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  btn.__aiCover = fr
end

function U.RestoreBagIcon()
  coverBagIcon()
  pinTexture(G("MainMenuBarBackpackButtonIconTexture"))
  local btn = G("MainMenuBarBackpackButton")
  if btn then
    if btn.icon then pinTexture(btn.icon) end
    if btn.SetNormalTexture and not btn.__aiPinnedNorm then
      btn.__aiPinnedNorm = true
      local origN = btn.SetNormalTexture
      btn.SetNormalTexture = function(self, t, ...)
        if t and t ~= BAGICON then return end
        return origN(self, t, ...)
      end
    end
  end
end

f:SetScript("OnHide", function()
  U.RestoreBagIcon()
  -- 出售模式是“拿在手上”触发的，关背包就放下，避免再点东西被卖掉
  if type(ClearCursor) == "function" then pcall(ClearCursor) end
end)

-- 商店开着时的“出售模式”：背包里点击 = 右键
U.bagSellMode = false

function BU.mkSell(fr)
  local b = CreateFrame("Button", "AIbarBagSellBtn", fr)
  -- 和背包顶部那排按钮统一：72×32、同样的底色和描边
  b:SetWidth(U.TouchMode and 72 or 64)
  b:SetHeight(U.TouchMode and 32 or 28)
  b:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -8, 8)
  b:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  b:SetBackdropColor(0.16, 0.15, 0.14, 0.95)
  b:SetBackdropBorderColor(0.45, 0.38, 0.28, 1)
  local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t:SetPoint("CENTER", b, "CENTER")
  t:SetText("出售")
  b:SetScript("OnClick", function()
    U.bagSellMode = not U.bagSellMode
    U.BagRefresh()
  end)
  b:Hide()
  BU.sellBtn, BU.sellLbl = b, t
end
BU.mkSell(f)

-- 两个下拉：背包选择 / 分类筛选
function BU.mkSel(fr)
  local function mkBtnAt(text, x, w)
    local b = CreateFrame("Button", nil, fr)
    b:SetWidth(w)
    b:SetHeight(U.TouchMode and 32 or 28)
    b:SetPoint("TOPRIGHT", fr, "TOPRIGHT", x, -6)
    b:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    b:SetBackdropColor(0.18, 0.16, 0.12, 0.92)
    b:SetBackdropBorderColor(0.5, 0.42, 0.28, 1)
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t:SetPoint("CENTER", b, "CENTER")
    t:SetText(text)
    b.txt = t
    return b
  end

  local bagB = mkBtnAt("背包", U.TouchMode and -242 or -218, U.TouchMode and 72 or 64)
  local catB = mkBtnAt("分类", U.TouchMode and -320 or -288, U.TouchMode and 72 or 64)

  bagB:SetScript("OnClick", function()
    local list = {}
    local cur = (U.bagFilter == nil or U.bagFilter == "all") and "全部" or nil
    list[#list + 1] = { (cur == "全部" and "· " or "") .. "全部", function()
      U.bagFilter = "all"; U.BagRefresh()
    end }
    local i
    for i = 0, 4 do
      if (GetContainerNumSlots(i) or 0) > 0 then
        local nm = i == 0 and "背包" or ("包" .. i)
        if U.bagFilter == i then nm = "· " .. nm end
        list[#list + 1] = { nm, function()
          U.bagFilter = i
          U.BagRefresh()
        end }
      end
    end
    if (GetContainerNumSlots(KEYRING) or 0) > 0 then
      list[#list + 1] = { (U.bagFilter == KEYRING and "· " or "") .. "钥匙", function()
        U.bagFilter = KEYRING; U.BagRefresh()
      end }
    end
    BU.showDrop(list)
  end)

  catB:SetScript("OnClick", function()
    local cats = { { nil, "全部" }, { "equip", "装备" }, { "use", "消耗" },
                   { "mat", "材料" }, { "quest", "任务" } }
    local list = {}
    local k
    for k = 1, #cats do
      local nm = cats[k][2]
      if U.bagCat == cats[k][1] then nm = "· " .. nm end
      list[#list + 1] = { nm, function()
        U.bagCat = cats[k][1]
        U.BagRefresh()
      end }
    end
    BU.showDrop(list)
  end)

  BU.bagBtn = bagB
  BU.catBtn = catB
  U.bagSelBtn = bagB
  U.bagCatBtn = catB

  -- 横向铺开的选项条（在标题与格子之间那条空带里）
  local drop = CreateFrame("Frame", "AIbarBagDrop", fr)
  drop:SetHeight(28)
  drop:SetPoint("TOPLEFT", fr, "TOPLEFT", 8, -30)
  drop:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -8, -30)
  drop:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  drop:SetBackdropColor(0.08, 0.08, 0.09, 0.97)
  drop:SetBackdropBorderColor(0.5, 0.42, 0.28, 1)
  drop.btns = {}
  drop:Hide()

  function BU.showDrop(list)
    local i
    for i = 1, #list do
      local b = drop.btns[i]
      if not b then
        b = CreateFrame("Button", nil, drop)
        b:SetHeight(24)
        b:SetPoint("TOPLEFT", drop, "TOPLEFT", 4 + (i - 1) * 68, -2)
        b:SetBackdrop({
          bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
          edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
          tile = true, tileSize = 16, edgeSize = 8,
          insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        b:SetBackdropColor(0.18, 0.16, 0.12, 0.96)
        b:SetBackdropBorderColor(0.45, 0.38, 0.28, 1)
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        t:SetPoint("CENTER", b, "CENTER")
        b.txt = t
        drop.btns[i] = b
      end
      b:SetWidth(64)
      b.txt:SetText(list[i][1])
      b:SetScript("OnClick", function()
        drop:Hide()
        list[i][2]()
      end)
      b:Show()
    end
    local j
    for j = #list + 1, #drop.btns do drop.btns[j]:Hide() end
    drop:Show()
  end

  BU.drop = drop
  U.bagDrop = drop
end
BU.mkSel(f)

f:SetScript("OnShow", function() U.BagRefresh() end)
f:RegisterEvent("BAG_UPDATE")
f:SetScript("OnEvent", function() U.BagRefresh() end)
f:Hide()

local mf = CreateFrame("Frame")
mf:RegisterEvent("MERCHANT_SHOW")
mf:RegisterEvent("MERCHANT_CLOSED")
mf:SetScript("OnEvent", function()
  if event == "MERCHANT_SHOW" then
    merchantOpen = true
    -- 打开商店时自动把整合背包一起打开
    if DB.modBag ~= false and not f:IsShown() then
      f:Show()
      autoBag = true
      U.BagRefresh()
    end
  else
    merchantOpen = false
    if autoBag then
      autoBag = false
      f:Hide()
      U.RestoreBagIcon()
    end
  end
end)

function U.ToggleBag()
  if DB.modBag == false then
    f:Hide()
    if type(OpenAllBags) == "function" then pcall(OpenAllBags) end
    return false
  end
  if f:IsShown() then
    if U.CloseBagMenu then U.CloseBagMenu() end
    if type(GameTooltip.Hide) == "function" then pcall(GameTooltip.Hide, GameTooltip) end
    f:Hide()
    U.RestoreBagIcon()
    if sp then sp:Hide() end
    if spCatcher then spCatcher:Hide() end
  else
    if DB.bagAnchor and not U.IsDragging(f) then
      f:ClearAllPoints()
      f:SetPoint(DB.bagAnchor[1], UIParent, DB.bagAnchor[2],
                 DB.bagAnchor[3], DB.bagAnchor[4])
    end
    f:Show()
    U.BagRefresh()
  end
  return f:IsShown()
end

-- 点原生背包按钮时打开我们的整合背包
local BAGBTNS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot",
                  "CharacterBag2Slot", "CharacterBag3Slot" }
local bi
for bi = 1, #BAGBTNS do
  local nb = G(BAGBTNS[bi])
  if nb and nb.GetScript and not nb.__aibarHooked then
    nb:SetScript("OnClick", function()
      -- 接管：只开整合背包，不再弹原生那几个小包
      if U.bagClosedAt and GetTime() - U.bagClosedAt < 0.45 then
        U.bagClosedAt = nil
        return
      end
      U.ToggleBag()
    end)
    nb.__aibarHooked = true
  end
end

local cf
for cf = 1, 5 do
  local c = G("ContainerFrame" .. cf)
  if c then U.Kill(c) end
end

-- 诊断：客户端到底有哪些出售/对比接口
-- 诊断：宏接口能不能读到
function U.DiagMacro()
  local txt = "GetNumMacros="
  if type(GetNumMacros) == "function" then
    local ok, a, b = pcall(GetNumMacros)
    txt = txt .. (ok and (tostring(a) .. "," .. tostring(b)) or "错误")
  else
    txt = txt .. "无"
  end
  txt = txt .. "  GetMacroInfo="
  if type(GetMacroInfo) == "function" then
    local ok2, n1 = pcall(GetMacroInfo, 1)
    local ok3, n2 = pcall(GetMacroInfo, 1, true)
    local ok4, n3 = pcall(GetMacroInfo, 1, 1)
    txt = txt .. (ok2 and tostring(n1) or "错误") ..
          " / 真:" .. (ok3 and tostring(n2) or "错误") ..
          " / 1:" .. (ok4 and tostring(n3) or "错误")
  else
    txt = txt .. "无"
  end
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff7CECFFAiBar|r 宏接口：" .. txt) end
end

SLASH_AIBARBAG1 = "/bag"
SlashCmdList["AIBARBAG"] = function() U.ToggleBag() end
end

do  -- 配置面板
local U = AIbar
local DB = AIbarDB

local W, H = 360, 526
local p = CreateFrame("Frame", "AIbarConfig", UIParent)
p:SetWidth(360)
p:SetHeight(560)
p:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
p:SetFrameStrata("DIALOG")
p:SetMovable(true)
p:EnableMouse(true)
p:RegisterForDrag("LeftButton")
p:SetScript("OnDragStart", function() this:StartMoving() end)
p:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
p:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 12,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
-- 配置页整体放大：在设备自适应系数上再乘 1.15，按钮和文字一起变大，手机上更好点
p:SetScale(math.min(1.4, (DEV_S or 1) * (U.TouchMode and 1.15 or 1.0)))
p:SetBackdropColor(0.05, 0.05, 0.06, 0.96)
p:SetBackdropBorderColor(0.42, 0.39, 0.34, 1)

local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -10)
title:SetText("|cffd8c081AiBar 配置|r |cff888888v1.94|r")

-- ===== 布局常量 =====
local PADX = 16          -- 左右内边距
local ROW = 36           -- 行高
local SGAP = 26          -- 分区标题到下一行的距离
local TOP = -84          -- 内容起始 y
local pages = { {}, {}, {}, {}, {} }
local curTab = 1
local tabBtns = {}

local function reg(o) if o then table.insert(pages[curTab], o) end return o end

local function mkBtn(text, x, y, w, h, fn, noReg)
  local b = CreateFrame("Button", nil, p)
  b:SetWidth(w); b:SetHeight(h)
  b:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
  b:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  b:SetBackdropColor(0.16, 0.15, 0.14, 0.95)
  b:SetBackdropBorderColor(0.4, 0.37, 0.33, 1)
  b.lbl = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.lbl:SetPoint("CENTER", b, "CENTER")
  b.lbl:SetText(text)
  b:SetScript("OnClick", fn)
  b:SetScript("OnEnter", function() this:SetBackdropColor(0.24, 0.22, 0.19, 0.98) end)
  b:SetScript("OnLeave", function()
    if b.isSel then return end
    this:SetBackdropColor(0.16, 0.15, 0.14, 0.95)
  end)
  if not noReg then reg(b) end
  return b
end

local widgets = {}
local function syn()
  local i
  for i = 1, #widgets do widgets[i]() end
  -- 配置面板每次改完立刻存档并落盘：手机端可能来不及等到 5 秒的定时保存
  if U.Save then U.Save(true) end
end
local function touch()
  U.Geo = true
  local bf = G("AIbarBag")
  if bf and bf:IsShown() then U.BagRefresh() end
  syn()
  U.ApplyNative()
  U.Refresh()
end

local function section(text, y)
  local fs = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("TOPLEFT", p, "TOPLEFT", PADX, y - 8)
  fs:SetText("|cffb99a55" .. text .. "|r")
  reg(fs)
  return fs
end

local function stepper(y, label, key, min, max, step, suffix)
  local lb = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lb:SetPoint("TOPLEFT", p, "TOPLEFT", PADX, y - 20)
  lb:SetText(label)
  reg(lb)
  local val = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  val:SetPoint("TOPLEFT", p, "TOPLEFT", 186, y - 20)
  reg(val)
  local bM = mkBtn("-", 232, y - 8, 40, 30, function()
    DB[key] = math.max(min, DB[key] - step); touch()
  end)
  local bP = mkBtn("+", 276, y - 8, 40, 30, function()
    DB[key] = math.min(max, DB[key] + step); touch()
  end)
  widgets[#widgets + 1] = function()
    val:SetText(tostring(DB[key]) .. (suffix or ""))
  end
  return bM, bP
end

-- ===== 第 1 页:动作条 =====
curTab = 1
local y = TOP

section("显示", y); y = y - SGAP

local bMove = mkBtn("移动", 14, y - 8, 104, 30, function() U.SetMovable(not DB.move); touch() end)
local bSkin = mkBtn("背板", 124, y - 8, 104, 30, function() DB.skin = not DB.skin; touch() end)
y = y - ROW

local bRL = mkBtn("RL", 14, y - 8, 104, 30, function() U.SetRL(not DB.rlButton); touch() end)
local bPet = mkBtn("宠物条", 124, y - 8, 104, 30, function() DB.petBar = not DB.petBar; touch() end)
y = y - ROW
section("布局", y); y = y - SGAP
local barSel = {}
local bi
for bi = 1, 4 do
  barSel[bi] = mkBtn("第" .. bi .. "条", 14 + (bi - 1) * 82, y - 12, 78, 28, function()
    DB.curBar = bi
    touch()
  end)
end
y = y - ROW

widgets[#widgets + 1] = function()
  local cb = DB.curBar or 1
  local i2
  for i2 = 1, 4 do
    local bt = barSel[i2]
    if i2 == cb then
      bt.isSel = true
      bt:SetBackdropColor(0.55, 0.44, 0.18, 1)
      bt:SetBackdropBorderColor(1, 0.86, 0.35, 1)
      bt.lbl:SetText("|cffffe08a▶ 第" .. i2 .. "条|r")
    else
      bt.isSel = false
      bt:SetBackdropColor(0.14, 0.13, 0.12, 0.95)
      bt:SetBackdropBorderColor(0.4, 0.37, 0.33, 1)
      bt.lbl:SetText("第" .. i2 .. "条")
    end
  end
end

local function stepperCfg(yy, label, field, min, max, step)
  local lb = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lb:SetPoint("TOPLEFT", p, "TOPLEFT", PADX, yy - 20)
  lb:SetText(label)
  reg(lb)
  local val = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  val:SetPoint("TOPLEFT", p, "TOPLEFT", 186, yy - 20)
  reg(val)
  mkBtn("-", 232, yy - 8, 40, 30, function()
    local c = U.BarCfg(DB.curBar or 1)
    c[field] = math.max(min, c[field] - step)
    touch()
  end)
  mkBtn("+", 276, yy - 8, 40, 30, function()
    local c = U.BarCfg(DB.curBar or 1)
    c[field] = math.min(max, c[field] + step)
    touch()
  end)
  widgets[#widgets + 1] = function()
    val:SetText(tostring(U.BarCfg(DB.curBar or 1)[field]))
  end
end

stepperCfg(y, "每行几个", "cols", 1, 12, 1); y = y - ROW
stepperCfg(y, "格子数量", "slots", 1, 12, 1); y = y - ROW
stepperCfg(y, "图标尺寸", "icon", 44, 96, 4); y = y - ROW
stepperCfg(y, "格子间距", "gap", 0, 20, 2); y = y - ROW
local bBar2 = mkBtn("第2条", 14, y - 8, 104, 30, function() DB.bar2 = not DB.bar2; touch() end)
local bBar3 = mkBtn("第3条", 124, y - 8, 104, 30, function() DB.bar3 = not DB.bar3; touch() end)
local bBar4 = mkBtn("第4条", 234, y - 8, 104, 30, function() DB.bar4 = not DB.bar4; touch() end)
y = y - ROW
section("组件", y); y = y - SGAP
stepper(y, "职业栏大小", "classScale", 0.6, 2.4, 0.1, ""); y = y - ROW
stepper(y, "宠物条大小", "petScale", 0.6, 2.4, 0.1, ""); y = y - ROW

local PAGE1_H = -y + 70

widgets[#widgets + 1] = function()
  bMove.lbl:SetText("移动 " .. (DB.move and "|cff55ff55开|r" or "|cff888888关|r"))
  bSkin.lbl:SetText("背板 " .. (DB.skin and "|cff55ff55显|r" or "|cff888888隐|r"))
  bRL.lbl:SetText("RL " .. (DB.rlButton and "|cff55ff55开|r" or "|cff888888关|r"))
  bPet.lbl:SetText("宠物条 " .. (DB.petBar and "|cff55ff55开|r" or "|cff888888关|r"))
  bBar2.lbl:SetText("第2条 " .. (DB.bar2 and "|cff55ff55开|r" or "|cff888888关|r"))
  bBar3.lbl:SetText("第3条 " .. (DB.bar3 and "|cff55ff55开|r" or "|cff888888关|r"))
  bBar4.lbl:SetText("第4条 " .. (DB.bar4 and "|cff55ff55开|r" or "|cff888888关|r"))
end

-- ===== 第 2 页:资源 =====
curTab = 2
y = TOP

local bRBg = mkBtn("资源背景", 14, y - 8, 104, 30, function() DB.resBg = not DB.resBg; touch() end)
local bRCb = mkBtn("仅战斗显示", 124, y - 8, 104, 30, function() DB.resCombatOnly = not DB.resCombatOnly; touch() end)
local bCfg = mkBtn("配置按钮", 234, y - 8, 104, 30, function()
  DB.cfgBtn = not (DB.cfgBtn ~= false)
  U.ApplyCfgBtn()
  touch()
end)
widgets[#widgets + 1] = function()
  bCfg.lbl:SetText("配置按钮 " .. ((DB.cfgBtn ~= false) and "|cff55ff55开|r" or "|cff888888关|r"))
end
y = y - ROW

local bLock = mkBtn("资源锁定", 14, y - 8, 104, 30, function()
  DB.resLocked = not (DB.resLocked ~= false)
  U.ApplyRes()
  touch()
end)
widgets[#widgets + 1] = function()
  bLock.lbl:SetText("资源锁定 " .. ((DB.resLocked ~= false) and "|cff55ff55开|r" or "|cff888888关|r"))
end
y = y - ROW

stepper(y, "资源大小", "resScale", 0.6, 1.6, 0.1, ""); y = y - ROW
stepper(y, "资源宽度", "resWidth", 160, 420, 20, " px"); y = y - ROW
stepper(y, "资源透明度", "resAlpha", 0.3, 1, 0.1, ""); y = y - ROW

section("模块", y); y = y - SGAP

local MODS = {
  { k = "power",  on = "resPower",  label = "资源条" },
  { k = "swing",  on = "resSwing",  label = "平砍"   },
  { k = "combo",  on = "resCombo",  label = "连击点" },
  { k = "self",   on = "resSelf",   label = "自己血" },
  { k = "target", on = "resTarget", label = "目标血" },
  { k = "pet",    on = "resPet",    label = "宠物血" },
  { k = "shard",  on = "resShard",  label = "碎片"   },

}

local mi
for mi = 1, #MODS do
  local m = MODS[mi]
  local bT = mkBtn(m.label, 14, y - 8, 96, 30, function()
    DB[m.on] = not DB[m.on]; touch()
  end)
  mkBtn("上", 114, y - 8, 30, 30, function()
    U.FixResData()
    local o = DB.resOrder
    local i
    for i = 2, #o do
      if o[i] == m.k then o[i], o[i - 1] = o[i - 1], o[i]; touch(); return end
    end
  end)
  mkBtn("下", 148, y - 8, 30, 30, function()
    U.FixResData()
    local o = DB.resOrder
    local i
    for i = 1, #o - 1 do
      if o[i] == m.k then o[i], o[i + 1] = o[i + 1], o[i]; touch(); return end
    end
  end)

  if m.k ~= "shard" then
    local hTxt = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hTxt:SetPoint("TOPLEFT", p, "TOPLEFT", 186, y - 20)
    reg(hTxt)
    widgets[#widgets + 1] = function()
      hTxt:SetText(tostring((DB.resH and DB.resH[m.k]) or 12))
    end
    mkBtn("-", 232, y - 8, 40, 30, function()
      DB.resH = DB.resH or {}
      DB.resH[m.k] = math.max(4, (DB.resH[m.k] or 12) - 2); touch()
    end)
    mkBtn("+", 276, y - 8, 40, 30, function()
      DB.resH = DB.resH or {}
      DB.resH[m.k] = math.min(40, (DB.resH[m.k] or 12) + 2); touch()
    end)
  end

  widgets[#widgets + 1] = function()
    bT.lbl:SetText(m.label .. " " .. (DB[m.on] and "|cff55ff55开|r" or "|cff888888关|r"))
  end

  y = y - ROW
end

widgets[#widgets + 1] = function()
  bRCb.lbl:SetText("仅战斗 " .. (DB.resCombatOnly and "|cff55ff55开|r" or "|cff888888关|r"))
  bRBg.lbl:SetText("背景 " .. (DB.resBg and "|cff55ff55显|r" or "|cff888888隐|r"))
end

local PAGE2_H = -y + 70

-- ===== 第 5 页:说明 =====
curTab = 5
y = TOP

section("操作", y); y = y - SGAP

local function helpLine(txt)
  local fs = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("TOPLEFT", p, "TOPLEFT", PADX + 8, y - 6)
  fs:SetWidth(316)
  fs:SetJustifyH("LEFT")
  fs:SetText(txt)
  reg(fs)
  y = y - 26
end

helpLine("· 空格子 左键 → 选技能 / 宏 / 物品")
helpLine("· 有技能 短按 → 直接施放")
helpLine("· 有技能 长按 3 秒 或 右键 → 换技能")

y = y - 10
section("界面", y); y = y - SGAP

helpLine("· 打开「移动」后拖动各组件")
helpLine("· 「配置」按钮随时可拖，不用开移动")
helpLine("· 任何改动即时生效")
helpLine("· 「模块」页关掉哪块就还回原生")

y = y - 10
section("命令", y); y = y - SGAP

helpLine("/ab 面板　　/abc move 移动")
helpLine("/abc skin 背板　　/abc diag 诊断")
helpLine("/abc help 全部　/bag 背包")

local PAGE3_H = -y + 70

-- ===== 第 3 页:施法条 =====
curTab = 3
y = TOP

section("施法条", y); y = y - SGAP

local bRev = mkBtn("反转", 14, y - 8, 104, 30, function()
  DB.castReverse = not DB.castReverse
  touch()
end)
local bPrev = mkBtn("预览", 124, y - 8, 104, 30, function()
  U.previewSelf = not U.previewSelf
  U.UpdateCasts()
  syn()   -- 立刻刷新按钮上的“中/关”字样
end)
local bLock = mkBtn("锁定", 234, y - 8, 104, 30, function()
  DB.castLock = not DB.castLock
  touch()
end)
y = y - ROW
stepper(y, "宽度", "castW", 120, 520, 20, " px"); y = y - ROW
stepper(y, "高度", "castH", 10, 40, 2, " px"); y = y - ROW

section("目标施法条", y); y = y - SGAP
local bTRev = mkBtn("目标反转", 14, y - 8, 104, 30, function()
  DB.castTReverse = not DB.castTReverse
  touch()
end)
local bPrev2 = mkBtn("预览目标", 124, y - 8, 104, 30, function()
  U.previewTarget = not U.previewTarget
  U.UpdateCasts()
  syn()
end)
y = y - ROW
stepper(y, "目标宽度", "castTW", 120, 520, 20, " px"); y = y - ROW
stepper(y, "目标高度", "castTH", 10, 40, 2, " px"); y = y - ROW

local bCastReset = mkBtn("重置施法条位置", 14, y - 8, 170, 30, function()
  DB.castSelfAnchor = nil
  DB.castTargetAnchor = nil
  U.UpdateCasts()
end)
y = y - ROW - 6

local PAGE4_H = -y + 70

widgets[#widgets + 1] = function()
  bRev.lbl:SetText("反转 " .. (DB.castReverse and "|cff55ff55开|r" or "|cff888888关|r"))
  bTRev.lbl:SetText("目标反转 " .. (DB.castTReverse and "|cff55ff55开|r" or "|cff888888关|r"))
  bPrev.lbl:SetText(U.previewSelf and "预览 |cff55ff55中|r" or "预览")
  bLock.lbl:SetText("锁定 " .. (DB.castLock and "|cff55ff55开|r" or "|cff888888关|r"))
  bPrev2.lbl:SetText(U.previewTarget and "预览目标 |cff55ff55中|r" or "预览目标")
end

-- ===== 第 4 页:模块开关 =====
curTab = 4
y = TOP

section("模块开关", y); y = y - SGAP

local function modBtn(label, key, x, w)
  local b = mkBtn(label, x, y - 8, w, 30, function()
    DB[key] = not DB[key]
    -- 老字段跟着同步，避免两个开关说法不一
    if key == "modCast" then DB.castOn = DB.modCast end
    if key == "modRes" then DB.resOn = DB.modRes end
    if key == "classBar" then U.classApplied = nil end
    U.Geo = true
    U.ApplyModules()
    touch()
  end)
  widgets[#widgets + 1] = function()
    b.lbl:SetText(label .. " " .. (DB[key] ~= false and "|cff55ff55开|r" or "|cff888888关|r"))
  end
  return b
end

local mBar = modBtn("动作条", "modBar", 14, 104)
local mRes = modBtn("资源条", "modRes", 124, 104)
modBtn("施法条", "modCast", 234, 104)
y = y - ROW
local mBag = modBtn("背包整合", "modBag", 14, 104)
local mUtil = modBtn("辅助按钮", "modUtil", 124, 104)
modBtn("职业栏", "classBar", 234, 104)
y = y - ROW - 4

-- 微调：先选组件，再用方向键一点一点挪
section("微调", y); y = y - SGAP

U.NUDGE = {
  { "第1条", "AIbarPanel", "anchor" },
  { "第2条", "AIbarExtra2", "bar2Anchor" },
  { "第3条", "AIbarExtra3", "bar3Anchor" },
  { "第4条", "AIbarExtra4", "bar4Anchor" },
  { "职业栏", "AIbarClass", "classAnchor" },
  { "资源条", "AIbarRes", "resAnchor" },
  { "跳", "AIbarUtiljump", "jumpAnchor" },
  { "目", "AIbarUtiltarget", "targetAnchor" },
  { "RL", "AIbarRL", "rlAnchor" },
  { "背包", "AIbarBag", "bagAnchor" },
  { "自己条", "AIbarCastSelf", "castSelfAnchor" },
  { "目标条", "AIbarCastTarget", "castTargetAnchor" },
}

function U.NudgeFrame(fr, key, dx, dy)
  if not fr then return end
  local L, B = fr:GetLeft(), fr:GetBottom()
  if not L or not B then return end
  L, B = L + dx, B + dy
  DB[key] = { "BOTTOMLEFT", "BOTTOMLEFT", L, B }
  fr:ClearAllPoints()
  fr:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", L, B)
  U.Geo = true
end

function U.DoNudge(dx, dy)
  local t = U.NUDGE[DB.nudgeSel or 1]
  if not t then return end
  local fr = getglobal(t[2])
  if not fr then return end
  local L, B = fr:GetLeft(), fr:GetBottom()
  if not L or not B then return end
  L, B = L + dx, B + dy
  DB[t[3]] = { "BOTTOMLEFT", "BOTTOMLEFT", L, B }
  fr:ClearAllPoints()
  fr:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", L, B)
  U.Geo = true
end

U.nudgeBtns = {}
local nvi
for nvi = 1, #U.NUDGE do
  local b = mkBtn(U.NUDGE[nvi][1], 14 + ((nvi - 1) % 4) * 84, y - 8, 76, 28, function()
    DB.nudgeSel = nvi
    syn()
  end)
  U.nudgeBtns[nvi] = b
  if nvi % 4 == 0 then y = y - 32 end
end
y = y - 32

widgets[#widgets + 1] = function()
  local k
  for k = 1, #U.nudgeBtns do
    local b = U.nudgeBtns[k]
    if (DB.nudgeSel or 1) == k then
      b:SetBackdropColor(0.55, 0.44, 0.18, 1)
      b:SetBackdropBorderColor(1, 0.86, 0.35, 1)
    else
      b:SetBackdropColor(0.16, 0.15, 0.14, 0.95)
      b:SetBackdropBorderColor(0.4, 0.37, 0.33, 1)
    end
  end
end

mkBtn("←", 14, y - 8, 64, 30, function() U.DoNudge(-2, 0) end)
mkBtn("→", 84, y - 8, 64, 30, function() U.DoNudge(2, 0) end)
mkBtn("↑", 154, y - 8, 64, 30, function() U.DoNudge(0, 2) end)
mkBtn("↓", 224, y - 8, 64, 30, function() U.DoNudge(0, -2) end)
y = y - ROW

section("辅助", y); y = y - SGAP
local bJump = mkBtn("跳跃", 14, y - 8, 104, 30, function() DB.jumpOn = not DB.jumpOn; touch() end)
local bTgt = mkBtn("目标", 124, y - 8, 104, 30, function() DB.targetOn = not DB.targetOn; touch() end)
y = y - ROW
stepper(y, "跳跃大小", "jumpScale", 0.6, 2.4, 0.1, ""); y = y - ROW
stepper(y, "目标大小", "targetScale", 0.6, 2.4, 0.1, ""); y = y - ROW

widgets[#widgets + 1] = function()
  bJump.lbl:SetText("跳跃 " .. (DB.jumpOn and "|cff55ff55开|r" or "|cff888888关|r"))
  bTgt.lbl:SetText("目标 " .. (DB.targetOn and "|cff55ff55开|r" or "|cff888888关|r"))
end

local PAGE5_H = -y + 70

-- ===== 选项卡(无关闭按钮) =====
local TABS = { "动作条", "资源条", "施法条", "模块", "说明" }
local TAB_H = { PAGE1_H, PAGE2_H, PAGE4_H, PAGE5_H, PAGE3_H }

local function switchTab(i)
  -- 离开施法条页就把预览关掉，别让假进度条一直挂在屏幕上
  if i ~= 3 and (U.previewSelf or U.previewTarget) then
    U.previewSelf, U.previewTarget = false, false
    U.UpdateCasts()
  end
  curTab = i
  if p.SetHeight then p:SetHeight(TAB_H[i] or 560) end
  local n, k
  for n = 1, 5 do
    local list = pages[n]
    for k = 1, #list do
      local o = list[k]
      if n == i then
        if o.Show then pcall(o.Show, o) end
      else
        if o.Hide then pcall(o.Hide, o) end
      end
    end
  end
  for n = 1, 5 do
    local tb = tabBtns[n]
    if tb then
      if n == i then tb:SetBackdropColor(0.32, 0.27, 0.15, 0.98)
      else tb:SetBackdropColor(0.14, 0.13, 0.12, 0.95) end
    end
  end
end

local ti
for ti = 1, 5 do
  local b = mkBtn(TABS[ti], 14 + (ti - 1) * 67, -46, 62, 32, function()
    switchTab(ti)
  end, true)
  tabBtns[ti] = b
end

-- 底部按钮
local bReset = mkBtn("重置位置", 14, 0, 150, 34, function()
  -- 重置 = 回到默认布局（和首次安装一致）：动作条 1 底部居中、2/3/4 右侧竖排、小按钮排中线
  DB.petAnchor = nil
  DB.utilAnchor = nil
  DB.castSelfAnchor = nil
  DB.castTargetAnchor = nil
  U.ApplyDefaultLayout()
  U.Geo = true
  U.ApplyCfgBtn()
  U.ApplyUtil()
  U.ApplyClassBar()
  U.ApplyPet()
  U.ApplyCastAnchors()   -- 施法条也回到默认位置
  U.Refresh()
  syn()
end, true)
bReset:ClearAllPoints()
bReset:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 14, 12)

local bClose = mkBtn("关闭", 0, 0, 150, 34, function() p:Hide() end, true)
bClose:ClearAllPoints()
bClose:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -14, 12)

switchTab(1)
p:SetScript("OnShow", function()
  syn()
  switchTab(curTab or 1)
end)
p:SetScript("OnHide", function()
  -- 面板关掉后预览必须停，否则会一直有两条“预览”进度条挂在屏幕上
  if U.previewSelf or U.previewTarget then
    U.previewSelf, U.previewTarget = false, false
    U.UpdateCasts()
  end
end)


SLASH_EVALBARCFG1 = "/ab"

SlashCmdList["EVALBARCFG"] = function()
  if p:IsShown() then
    p:Hide()
  else
    syn()
    p:Show()
  end
end

p:Hide()
end
