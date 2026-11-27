-- AIbar 7.0 核心：自绘按钮（黑铁圆角边框）
AIbar = AIbar or {}
local U = AIbar

-- 同一个插件被装了两份（比如 AIbar 和 AIbar (1)）时，第二份直接退出：
-- 否则两个面板会叠在一起，出现按钮重复、中英文混排。
if U.__loaded then
  U.__dup = true
  return
end
U.__loaded = true

AIbarDB = AIbarDB or {}
-- 角色级存档：有些客户端只认 SavedVariablesPerCharacter（toc 里已声明），
-- 账号级 AIbarDB 不落盘时靠它兜底。
AIbarDBC = AIbarDBC or {}
local DB = AIbarDB
local D = { cols = 6, icon = 72, gap = 8, skin = false,
            move = true, bar2 = false, bar3 = false, bar4 = false, curBar = 1, classBar = true, classScale = 1,
            jumpOn = true, targetOn = true, utilScale = 1, jumpScale = 1, targetScale = 1, chatBar = true, chatX = 0, chatY = 0, skillLock = false, lang = "auto", targetClass = true, tcX = 0, tcY = 0, tcSize = 26, resTxt = {}, castOn = true, castScale = 1, castW = 240, castH = 18, castReverse = false, castTW = 240, castTH = 18, castTScale = 1, castTReverse = false, castLock = false, modBar = true, modCast = true, modRes = true, modUtil = true,
            petBar = true, petScale = 1,
            resOn = true, resScale = 1, resWidth = 200, resBg = true, resLocked = false, resCombatOnly = false, resAlpha = 1, 
            resOrder = { "power", "combo", "self", "target", "pet", "shard" },
            resH = { power = 12, combo = 14, self = 11, target = 11, pet = 11, shard = 14 },
            resPower = true, resCombo = true, resSelf = true, resTarget = true, resSwing = true, 
            resPet = true, resShard = true }
for k, v in pairs(D) do if DB[k] == nil then DB[k] = v end end
-- 职业标尺寸范围：默认 26 往下 2 级、往上 5 级（22~36），老存档（比如 44）拉回范围
do
  local v = tonumber(DB.tcSize)
  -- 超出范围（老存档 44）直接回默认 26，而不是贴到上限
  if not v or v < 22 or v > 36 then v = 26 end
  DB.tcSize = v
  -- 职业标位置回默认（目标头像右上角），老存档只做一次
  if (DB.tcPosVer or 0) < 1 then
    DB.tcPosVer = 1
    DB.tcX, DB.tcY = 0, 0
  end
end
-- 碎片那行默认就有数字（和以前行为一致）
if type(DB.resTxt) ~= "table" then DB.resTxt = {} end
if DB.resTxt.shard == nil then DB.resTxt.shard = true end

local KEYS = { "cols", "icon", "gap", "skin", "move", "bar2", "bar3", "bar4", "curBar", "bars", "bar2Anchor", "bar3Anchor", "bar4Anchor",
               "rlButton", "cfgBtn", "anchor", "rlAnchor",
               "classBar", "classScale", "classAnchor", "cfgScale",
               "jumpOn", "targetOn", "utilScale", "jumpScale", "targetScale", "chatBar", "chatX", "chatY", "skillLock", "lang", "targetClass", "tcX", "tcY", "tcSize", "resTxt", "jumpAnchor", "targetAnchor", "castOn", "castScale", "castW", "castH", "castReverse", "castTW", "castTH", "castTScale", "castTReverse", "castLock", "modBar", "modCast", "modRes", "modUtil", "castSelfAnchor", "castTargetAnchor",
               "petBar", "petScale", "petAnchor",
               "resOn", "resScale", "resWidth", "resBg", "resLocked", "resCombatOnly", "resAlpha", "resAnchor", "resOrder", "resH",
               "resPower", "resSwing", "resCombo", "resSelf", "resTarget",
               "resPet", "resShard", "nudgeSel", "finCache", "pcMode", "slotItem", "slotName", "itemNames", "lootAnchor",
               "markAnchor", "markOffX", "markOffY", "markScale", "markOn" }

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

-- ---------- 多语言（中 / 英 / 俄） ----------
-- 只翻配置面板/选择器这类界面文字；聊天框里的诊断与提示保持中文。
local LOC = {
  en = {
    ["动作条"] = "Action", ["资源条"] = "Power", ["施法条"] = "Cast",
    ["模块"] = "Modules", ["其他"] = "Misc", ["辅助"] = "Utility",
    ["显示"] = "Display", ["布局"] = "Layout", ["微调"] = "Tune",
    ["模块开关"] = "Modules", ["目标施法条"] = "Target cast",
    ["组件"] = "Parts",
    ["上"] = "Up", ["下"] = "Down", ["左"] = "Left", ["右"] = "Right",
    ["仅战斗"] = "Combat only", ["关闭"] = "Close", ["反转"] = "Reverse",
    ["宠物条"] = "Pet bar", ["归零"] = "Reset", ["放大"] = "Bigger",
    ["缩小"] = "Smaller", ["文"] = "Text", ["移动"] = "Move",
    ["背景"] = "Background", ["背板"] = "Panel", ["资源锁定"] = "Lock power",
    ["跳大"] = "Jump+", ["跳小"] = "Jump-", ["跳跃"] = "Jump",
    ["目大"] = "Target+", ["目小"] = "Target-", ["目标"] = "Target",
    ["目标反转"] = "Reverse target", ["锁定"] = "Lock",
    ["锁定技能"] = "Lock skills", ["预览"] = "Preview",
    ["预览目标"] = "Preview target", ["重置位置"] = "Reset position",
    ["重置施法条位置"] = "Reset cast pos",
    ["第1条"] = "Bar 1", ["第2条"] = "Bar 2", ["第3条"] = "Bar 3", ["第4条"] = "Bar 4",
    ["辅助按钮"] = "Utility", ["职业栏"] = "Class bar", ["配置按钮"] = "Config",
    ["聊天按钮"] = "Chat", ["RL 按钮"] = "RL",
    ["平砍"] = "Swing", ["连击点"] = "Combo", ["自己血"] = "Self HP",
    ["目标血"] = "Target HP", ["宠物血"] = "Pet HP", ["碎片"] = "Shards",
    ["技能"] = "Spells", ["宏"] = "Macros", ["物品"] = "Items",
    ["上一页"] = "Prev", ["下一页"] = "Next", ["清空"] = "Clear",
    ["资源大小"] = "Power size", ["资源宽度"] = "Power width",
    ["资源透明度"] = "Power alpha", ["宠物条大小"] = "Pet bar size",
    ["宽度"] = "Width", ["高度"] = "Height",
    ["目标宽度"] = "Target width", ["目标高度"] = "Target height",
    ["职业栏大小"] = "Class bar size",
    ["微调（选对象，再用方向键）"] = "Tune: pick a part, then arrows",
    ["选择一个技能 / 宏 / 物品"] = "Choose a spell / macro / item",
    ["AiBar 配置"] = "AiBar Config",
    ["左右"] = "X", ["上下"] = "Y",
    ["跳"] = "Jump", ["目"] = "Target", ["自己条"] = "Self", ["目标条"] = "Target",
    ["聊天"] = "Chat", ["跳按钮"] = "Jump button", ["目标按钮"] = "Target button",
    ["用方向键移动"] = "arrow keys to move",
    ["语言"] = "Language", ["自动"] = "Auto",
    ["每行几个"] = "Columns", ["格子数量"] = "Slots",
    ["图标尺寸"] = "Icon size", ["格子间距"] = "Grid gap",
    ["职业标"] = "Class mark", ["标记"] = "Marks",
    ["团队"] = "Group", ["就位"] = "Ready", ["倒计时"] = "Countdown",
    ["语言已切换"] = "Language changed",
    ["界面语言在重载后生效"] = "The interface language changes after reloading the UI.",
    ["立即重载"] = "Reload now", ["稍后"] = "Later",
  },
}

function U.CurLang()
  local pick = DB and DB.lang or "auto"
  if pick == "zh" or pick == "en" then return pick end
  if type(GetLocale) == "function" then
    local loc = GetLocale()
    if loc == "zhCN" or loc == "zhTW" then return "zh" end
  end
  return "en"
end
function U.L(s)
  local lang = U.CurLang()
  if lang == "zh" then return s end
  local t = LOC[lang]
  return (t and t[s]) or s
end
local L = U.L

-- 界面文字登记：面板/选择器在建好之后，存档里的语言可能才加载进来，
-- 登录后统一按当前语言重套一遍
U.i18nText = {}
function U.regI18n(fn) U.i18nText[#U.i18nText + 1] = fn end
function U.ReI18n()
  local i
  for i = 1, #U.i18nText do pcall(U.i18nText[i]) end
end

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
  U.dragCount = math.max(0, (U.dragCount or 1) - 1)
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
               noClamp = cfg.noClamp, idleMax = cfg.idleMax or 2 }
  DRAGS[#DRAGS + 1] = st

  source:SetScript("OnMouseDown", function()
    if cfg.canDrag and not cfg.canDrag() then return end
    local cx, cy = GetCursorPosition()
    if not cx then return end
    local pt, relf, rp, x, y = anchorOf(target)
    st.on = true
    U.dragCount = (U.dragCount or 0) + 1
    st.p, st.relf, st.rp = pt, relf, rp
    st.ox, st.oy = x, y
    st.cx, st.cy = cx, cy
    st.kx, st.ky = 1, 1
    st.lastX, st.lastY = x, y
    st.lastL, st.lastT = target:GetLeft(), target:GetTop()
    st.moved = 0
    st.idleTicks = 0
    st.__lcx, st.__lcy = nil, nil
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
      -- GetTime() 在这个客户端不可靠：可能一直返回同一个值，导致拖动永远结束不了，
      -- 之后光标一动组件就跟着跑（“动作条乱跑”的真因）。这里再加一道按帧计数的兜底。
      if GetTime() - idleFrom > (st.idleMax or 2) then endDrag(st) end
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
            st.idleTicks = 0
          else
            st.idleTicks = (st.idleTicks or 0) + 1
            if st.idleTicks > 20 then endDrag(st) end   -- 约 0.3~0.5 秒没动就算松手
          end
          local dx, dy = cx - st.cx, cy - st.cy
          -- 不做“跳得太远就重置起点”的判断：手机快速滑动时单帧位移很大，
          -- 重置起点会让组件丢跟、看起来被甩到一边
          if math.abs(dx) >= 1 or math.abs(dy) >= 1 then
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
local CDART = "Interface\\AddOns\\AIbar\\tex\\sweep.tga"
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

local BORDER = "Interface\\AddOns\\AIbar\\tex\\border.tga"
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
  U.Flush(force)
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
if DB.classBar then
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
-- ---------- 目标头像框：职业图标 ----------
-- 职业代表图标（都用原版技能图标，客户端一定有）
U.CLASS_ICON = {
  WARRIOR = "Interface\\Icons\\Ability_Warrior_Charge",
  PALADIN = "Interface\\Icons\\Spell_Holy_SealOfMight",
  HUNTER = "Interface\\Icons\\Ability_Hunter_SniperShot",
  ROGUE = "Interface\\Icons\\Ability_Stealth",
  PRIEST = "Interface\\Icons\\Spell_Holy_Heal",
  SHAMAN = "Interface\\Icons\\Spell_Nature_Lightning",
  MAGE = "Interface\\Icons\\Spell_Frost_FrostBolt02",
  WARLOCK = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
  DRUID = "Interface\\Icons\\Ability_Druid_Maul",
}

-- 自带职业图标（AIbar 目录 cls_<CLASS>.tga）；没有的客户端走文字缩写
U.CLASS_ICON = {
  WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
  SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true,
}
function U.BuildTargetClass()
  local tf = G("TargetFrame")
  if not tf or U.tcBadge then return end
  local anchor = G("TargetFramePortrait") or tf
  local fr = CreateFrame("Frame", "AIbarTargetClass", tf)
  fr:SetWidth(DB.tcSize or 26); fr:SetHeight(DB.tcSize or 26)
  fr:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", (DB.tcX or 0), (DB.tcY or 0))
  fr:SetFrameStrata("HIGH")
  if fr.SetFrameLevel then fr:SetFrameLevel((tf:GetFrameLevel() or 1) + 10) end
  local tex = fr:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints(fr)
  tex:Hide()
  U.tcTex = tex
  U.tcBadge = fr
  fr:Hide()
end

function U.UpdateTargetClass()
  if DB.targetClass == false then
    if U.tcBadge then U.tcBadge:Hide() end
    return
  end
  local isPlayer = true
  if type(UnitIsPlayer) == "function" then
    local okp, v = pcall(UnitIsPlayer, "target")
    isPlayer = okp and v and true or false
  end
  local _, cls = UnitClass("target")
  cls = cls and string.upper(cls) or nil
  if not isPlayer or not cls or not UnitExists("target") then
    if U.tcBadge then U.tcBadge:Hide() end
    return
  end
  U.BuildTargetClass()
  if not U.tcBadge or not U.tcTex then return end

  local sz = tonumber(DB.tcSize) or 26
  if sz < 22 then sz = 22 elseif sz > 36 then sz = 36 end
  DB.tcSize = sz
  U.tcBadge:SetWidth(sz)
  U.tcBadge:SetHeight(sz)
  U.tcBadge:ClearAllPoints()
  U.tcBadge:SetPoint("TOPRIGHT", G("TargetFramePortrait") or G("TargetFrame"),
                     "TOPRIGHT", (DB.tcX or 0), (DB.tcY or 0))
  U.tcTex:SetTexture("Interface\\AddOns\\AIbar\\tex\\cls_" .. cls .. ".tga")
  U.tcTex:Show()
  U.tcBadge:Show()
end


-- 通用：按组件名/存档键微调（供“微调”页统一使用）

-- 说明页统一微调：职业标 / 聊天按钮 / 跳 / 目
function U.MicroTarget()
  U.micro = U.micro or "tc"
  return U.micro
end

function U.MicroNudge(dx, dy)
  local t = U.MicroTarget()
  if t == "tc" then
    DB.tcX = (DB.tcX or 0) + dx
    DB.tcY = (DB.tcY or 0) + dy
    U.UpdateTargetClass()
  elseif t == "chat" then
    DB.chatX = (DB.chatX or 0) + dx
    DB.chatY = (DB.chatY or 0) + dy
    U.ApplyChatBar()
  elseif t == "mark" then
    DB.markOffX = (DB.markOffX or 0) + dx
    DB.markOffY = (DB.markOffY or 0) + dy
    if U.ApplyMarks then U.ApplyMarks() end
  end
end


U.SetTipWidth = (function()
local GameTooltip = GameTooltip
-- 强制提示框宽度 = 传入宽度（菜单宽度），文字行也一起设宽，保证换行和边框一致
local function SetTipWidth(w)
  w = tonumber(w) or 0
  if w < 160 then w = 160 end
  if type(GameTooltip) ~= "table" then return end
  if type(GameTooltip.SetWidth) == "function" then pcall(GameTooltip.SetWidth, GameTooltip, w) end
  if type(GameTooltip.SetScale) == "function" then pcall(GameTooltip.SetScale, GameTooltip, 1) end
  local i
  for i = 1, 16 do
    local fs = G("GameTooltipTextLeft" .. i)
    if fs and fs.SetWidth then pcall(fs.SetWidth, fs, w - 18) end
  end
end

return SetTipWidth
end)()

-- 开锁类技能：UseAction 在这个客户端不进选目标，改用 CastSpellByName（名字从提示框读）
function U.CastAction(slot)
  if not slot then return end
  local nm
  if type(GameTooltip) == "table" and GameTooltip.SetAction then
    pcall(GameTooltip.SetOwner, GameTooltip, UIParent, "ANCHOR_NONE")
    pcall(GameTooltip.SetAction, GameTooltip, slot)
    local fs = G("GameTooltipTextLeft1")
    local t = fs and fs.GetText and fs:GetText()
    if type(t) == "string" and t ~= "" then nm = t end
    pcall(GameTooltip.Hide, GameTooltip)
  end
  if nm == "开锁" or nm == "Pick Lock" then
    if type(CastSpellByName) == "function" then
      local okt = pcall(CastSpellByName, nm)
      if okt then
        if type(SpellIsTargeting) == "function" then
          local ok, targeting = pcall(SpellIsTargeting)
          if ok and targeting then return end
        else
          return
        end
      end
    end
  end
  if type(UseAction) == "function" then pcall(UseAction, slot, 0) end
end

-- ---------- 点击光效 ----------
-- 按下时给按钮铺一层加法混合的白光，0.25 秒内淡出，给点手感。
function U.AddFlash(b)
  if not b or b.flash then return end
  -- 三层都铺满按钮：贴图自带圆角，裁切/内缩会把圆角切掉才显成直角
  local function layer(r, g2, b2, pad)
    local t = b:CreateTexture(nil, "OVERLAY")
    if pad then
      t:SetPoint("TOPLEFT", b, "TOPLEFT", -pad, pad)
      t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", pad, -pad)
    else
      t:SetAllPoints(b)
    end
    t:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    if t.SetVertexColor then pcall(t.SetVertexColor, t, r, g2, b2) end
    if t.SetBlendMode then pcall(t.SetBlendMode, t, "ADD") end
    t:SetAlpha(0)
    return t
  end

  b.flash = layer(0.72, 0.9, 1)          -- 蓝白冷光
  b.flashEdge = layer(1, 1, 1)           -- 纯白提亮
  b.flashGold = layer(1, 0.82, 0.3, 1)   -- 金色外圈，只多 1 像素
  b.flash:SetAlpha(0)

  U.flashList = U.flashList or {}
  if not b.__flashReg then
    b.__flashReg = true
    U.flashList[#U.flashList + 1] = b
  end
end

-- 分项开销开关（false = 关掉该功能），用于二分定位卡顿

function U.LightMode(on)
  U.off = U.off or {}
  U.off.flash = on and true or false
  U.off.text = on and true or false
  U.off.mods = on and true or false
end

function U.Flash(b)
  if U.off and U.off.flash then return end
  if not b or not b.flash then return end
  b.flash:SetAlpha(1)
  if b.flashEdge then b.flashEdge:SetAlpha(1) end
  if b.flashGold then b.flashGold:SetAlpha(1) end
  if not b.__flashT then U.flashActive = (U.flashActive or 0) + 1 end
  b.__flashT = 0.4
end

function U.UpdateFlash()
  if U.off and U.off.flash then return end
  -- 没有正在闪的按钮时直接返回，不用每两帧扫一遍整张表
  if (U.flashActive or 0) <= 0 then return end
  local list = U.flashList
  if not list then return end
  local i
  for i = 1, #list do
    local b = list[i]
    if b and b.__flashT then
      b.__flashT = b.__flashT - 0.05
      if b.__flashT <= 0 then
        b.__flashT = nil
        U.flashActive = math.max(0, (U.flashActive or 1) - 1)
        if b.flash then b.flash:SetAlpha(0) end
        if b.flashEdge then b.flashEdge:SetAlpha(0) end
        if b.flashGold then b.flashGold:SetAlpha(0) end
      else
        local a = b.__flashT / 0.4
        if b.flash then b.flash:SetAlpha(a) end
        if b.flashEdge then b.flashEdge:SetAlpha(a) end
        if b.flashGold then b.flashGold:SetAlpha(a) end
      end
    end
  end
end

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
  btn:SetScript("OnClick", function()
    U.Flash(btn)
    fn()
  end)
  U.AddFlash(btn)

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
-- 碎片固定在条子顶上显示 “12/20”
resF.shardTxt = resF:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
resF.shardTxt:SetPoint("CENTER", shardBg, "CENTER", 0, 0)
resF.shardTxt:SetTextColor(1, 1, 1)
pcall(function()
  local f = resF.shardTxt:GetFont()
  if f then resF.shardTxt:SetFont(f, 10, "OUTLINE") end
end)
resF.shardTxt:Hide()
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

-- 每条资源条的数字文字（“文”开关控制）
U.resTxtFS = {}
do
  local keys = { "power", "swing", "self", "target", "pet", "shard" }
  local bgs = { power = powerBg, swing = swingBg, self = selfBg,
                target = targetBg, pet = petBg, shard = shardBg }
  local i
  for i = 1, #keys do
    local k = keys[i]
    local bg = bgs[k]
    if bg then
      local fs = resF:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      fs:SetPoint("CENTER", bg, "CENTER", 0, 0)
      if fs.SetTextColor then fs:SetTextColor(1, 1, 1) end
      if fs.SetFont then pcall(function()
        local f, sz = fs:GetFont()
        if f then fs:SetFont(f, 10, "OUTLINE") end
      end) end
      fs:Hide()
      fs.__bg = bg
      U.resTxtFS[k] = fs
    end
  end
end

function U.FitResTextFont(fs, h)
  if not fs or not fs.GetFont then return end
  local ok, f = pcall(fs.GetFont, fs)
  if not ok or type(f) ~= "string" then return end
  -- 不加描边：描边会把小字糊成一团，按条高直接给足字号更清楚
  -- 比条高大 2 号：资源条数字再放大两个字号
  local size = math.max(11, math.floor((tonumber(h) or 12)) + 2)
  pcall(fs.SetFont, fs, f, size)
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
  local cls = U.PlayerClass()
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
      if k == "shard" and resF.shardTxt then U.FitResTextFont(resF.shardTxt, h) end
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
          if U.resTxtFS and U.resTxtFS[k] then U.FitResTextFont(U.resTxtFS[k], h) end
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

  -- 数量：用客户端里现成的大号数字字体（这个客户端不能自由改字号）
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
  b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)

  -- 左上角白色栏位号（小一号，避免抢数量）
  b.slotNum = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.slotNum:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -1)
  b.slotNum:SetTextColor(1, 1, 1)
  b.slotNum:SetText(tostring(i))

  b.empty = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.empty:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.empty:SetText("")
  U.AddFlash(b)


  if b.RegisterForClicks then
    pcall(b.RegisterForClicks, b, "LeftButtonUp", "RightButtonUp")
  end
  b:SetScript("OnMouseDown", function()
    U.pressT = U.now or 0
    U.pressFresh = true
    if arg1 == "LeftButton" then U.pressSlot = U.SlotOf(this.idx) end
  end)
  b:SetScript("OnClick", function()
    local fresh = U.pressFresh
    U.pressFresh = nil
    if this.suppress then this.suppress = nil U.pressSlot = nil return end
    if U.pressSwapped then U.pressSwapped = nil U.pressSlot = nil return end
    local btn = arg1
    if type(EVAL_RMB_BTN) == "function" then
      local okb, vb = pcall(EVAL_RMB_BTN, btn)
      if okb and type(vb) == "string" and vb ~= "" then btn = vb end
    end
    U.Flash(this)
    local a = U.SlotOf(this.idx)
    -- 锁定技能：非空格不再响应右键/长按换技能，空位照常可以加技能
    local slotEmpty = (GetActionTexture(a) == nil)
    if DB.skillLock and not slotEmpty and btn == "RightButton" then
      return
    end
    -- 右键 = 换技能。触屏客户端的"右键"是长按换算出来的，按不满 3 秒不算；
    -- 电脑端右键照旧立刻换。空槽左键也是换技能。
    if btn == "RightButton" then
      -- 触屏下按住期间客户端可能先换算成右键：按不满 3 秒就忽略，
      -- 同时保留 pressSlot，交给主循环的 3 秒计时
      if not U.TouchMode or (fresh and ((U.now or 0) - (U.pressT or 0)) >= 3) then
        U.pressSlot = nil
        U.OpenPicker(a)
      end
      return
    end
    U.pressSlot = nil
    if GetActionTexture(a) then
      U.CastAction(a)
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
  if DB.modBar == false then
    if panel then panel:Hide() end
    return
  end
  local cfg = U.BarCfg(1)
  local cols = cfg.cols
  local slots = cfg.slots
  local m = FS()
  local icon = cfg.icon * m
  local cell = icon + cfg.gap * m
  local rows = math.ceil(slots / cols)
  panel:SetWidth(cols * cell + 4)
  panel:SetHeight(rows * cell + 4)
  local asig = DB.anchor and table.concat(DB.anchor, "|") or "default"
  if panel.__anchSig ~= asig or (panel:GetNumPoints() or 0) == 0 then
    panel.__anchSig = asig
    panel:ClearAllPoints()
    if DB.anchor then
      panel:SetPoint(DB.anchor[1], UIParent, DB.anchor[2], DB.anchor[3], DB.anchor[4])
    else
      panel:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 8)
    end
  end
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
  b.cnt = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
  b.cnt:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)

  b.slotNum = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.slotNum:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -1)
  b.slotNum:SetTextColor(1, 1, 1)
  b.slotNum:SetText(tostring((b.slot - 1) % 12 + 1))
  b.empty = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.empty:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.macro = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.macro:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  U.AddFlash(b)
  if b.RegisterForClicks then
    pcall(b.RegisterForClicks, b, "LeftButtonUp", "RightButtonUp")
  end
  b:SetScript("OnMouseDown", function()
    U.pressT = U.now or 0
    U.pressFresh = true
    if arg1 == "LeftButton" then U.pressSlot = this.slot end
  end)
  b:SetScript("OnClick", function()
    local fresh = U.pressFresh
    U.pressFresh = nil
    U.pressSlot = nil
    if U.pressSwapped then U.pressSwapped = nil U.pressSlot = nil return end
    local btn = arg1
    if type(EVAL_RMB_BTN) == "function" then
      local ok, v = pcall(EVAL_RMB_BTN, btn)
      if ok and type(v) == "string" and v ~= "" then btn = v end
    end
    U.Flash(this)
    if btn == "RightButton" then
      if DB.skillLock and GetActionTexture(this.slot) then return end
      if not U.TouchMode or (fresh and ((U.now or 0) - (U.pressT or 0)) >= 3) then
        U.pressSlot = nil
        U.OpenPicker(this.slot)
      end
      return
    end
    U.pressSlot = nil
    if not GetActionTexture(this.slot) then U.OpenPicker(this.slot); return end
    U.AutoTarget(this.slot)
    U.CastAction(this.slot)
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
      if DB.modBar == false then
        fr:Hide()
      else
        fr:Show()
      end
      fr:SetWidth(cols * cell + 4)
      fr:SetHeight(rows * cell + 4)
      if not U.IsDragging(fr) then
        local anch = DB["bar" .. n .. "Anchor"]
        local sig = anch and table.concat(anch, "|") or ("default" .. n)
        if fr.__anchSig == sig and (fr:GetNumPoints() or 0) > 0 then
          sig = nil   -- 位置没变：跳过重摆
        else
          fr.__anchSig = sig
          sig = true
        end
        if sig and fr.__anchSig then
        fr:ClearAllPoints()
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
          -- 默认贴动作条上沿；摆好后立刻固化成绝对坐标，之后不再跟着主条跑
          fr:SetPoint("BOTTOM", panel, "TOP", 0, 8 + (n - 2) * (rows * cell + 14))
          local ba0 = U.BakeAnchor(fr)
          if ba0 then
            fr:ClearAllPoints()
            fr:SetPoint(ba0[1], UIParent, ba0[2], ba0[3], ba0[4])
            DB["bar" .. n .. "Anchor"] = ba0
          end
        end
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
  if U.ScanBagItemTex then U.ScanBagItemTex() end
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
                b.__tint = nil
              end
              b.icon:Show()
            else
              b.icon:Hide()   -- 同主条：空格子不清纹理，切回时不用重新加载
            end
          end
          local emptyTxt = ""
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

          local cs = U.ActionCountText(b.slot, tex)
          if b.cntLast ~= cs then b.cntLast = cs; b.cnt:SetText(cs) end
        end
      end
      local k
      for k = 1, COUNT do
        local b = fr.buttons[k]
        local tex = b.lastTex

        if tex then
          U.TintIcon(b, U.ActionState(b.slot, tex))
          local txt, left, du, st = U.ActionCd(b.slot, now)
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

U.RefreshExtra = updateExtra   -- 选完技能/清空后立刻刷副条，不用等 0.3 秒节拍

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

  -- 第 2~4 条：启动时不自动搬运。
  -- 以前这里按“越界”清档重摆，但这个客户端的坐标/屏幕尺寸经常不一致，
  -- 会被误判成越界，导致 3/4 条在登录后自己跳位置。现在只处理“坐标完全取不到”。
  local nb
  for nb = 2, 4 do
    if not U.LayoutReady then
      local fr = U.extraBars[nb]
      if fr and fr:IsShown() and DB["bar" .. nb .. "Anchor"] and not U.IsDragging(fr) then
        local L, T = fr:GetLeft(), fr:GetTop()
        if not L or not T then
          DB["bar" .. nb .. "Anchor"] = nil
          fr:ClearAllPoints()
          fr:SetPoint("BOTTOM", panel, "TOP", 0, 8 + (nb - 2) * ((fr:GetHeight() or 60) + 14))
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
  local p = U.Page()
  if p ~= lastPage then lastPage = p; resetTexCache() end
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
        b.__tint = nil
      end
      b.icon:Show()
      if b.__emptyT ~= "" then b.__emptyT = ""; b.empty:SetText("") end
    else
      -- 空格子只隐藏、不清纹理：从空页（潜行第 7 页）切回来时
      -- 不用再让客户端重新加载 12 张图标，首次切回不会顿一下
      b.icon:Hide()
      if b.__emptyT ~= "" then b.__emptyT = ""; b.empty:SetText("") end
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

    local cs = U.ActionCountText(a, tex)
    if cs ~= cachedCnt[j] then cachedCnt[j] = cs; b.count:SetText(cs) end
  end
end

local classHooked = false

local classRestored = false



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
    end
  end
end

function U.ApplyClassBar()
  if not DB.classBar then
    U.classApplied = nil
    -- 只把按钮/框架放回原位，不 Show、不 Revive：
    -- 原生栏本来就有自己的隐藏开关，别让这里把它唤醒
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
  -- 有些客户端 GetNumShapeshiftForms 要等几秒才有值，但按钮其实早就有了：
  -- 用 GetShapeshiftFormInfo 逐个探，探到哪算哪
  if nForms < 1 and type(GetShapeshiftFormInfo) == "function" then
    local i2
    for i2 = 1, 10 do
      local ok2, icon = pcall(GetShapeshiftFormInfo, i2)
      if ok2 and icon then nForms = i2 end
    end
  end
  -- 还不行就数原生按钮：原生栏既然能立刻显示，这些按钮就已经存在
  if nForms < 1 then
    local i3
    for i3 = 1, 10 do
      local b3 = G("ShapeshiftButton" .. i3)
      if b3 and b3.GetWidth then
        local ok3, w = pcall(b3.GetWidth, b3)
        if ok3 and tonumber(w) and tonumber(w) > 1 then nForms = i3 end
      end
    end
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
          U.AddFlash(b)
          -- 没有形态冷却接口时，至少能显示 GCD
          local orig = b.GetScript and b:GetScript("OnClick")
          b:SetScript("OnClick", function()
            U.Flash(b)
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

-- 拾取/战利品窗口：可拖动，位置存进存档；每次打开都按存档位置摆
function U.ApplyLootFrame()
  local lf = G("LootFrame")
  if not lf or type(lf.SetPoint) ~= "function" then return end
  if not U.lootHooked then
    U.lootHooked = true
    pcall(function()
      U.MakeDraggable(lf, lf, {
        drop = function(pt, relf, rp, x, y) DB.lootAnchor = { pt, rp, x, y } end,
      })
    end)
  end
  lf:ClearAllPoints()
  local a = DB.lootAnchor
  if a and a[1] then
    lf:SetPoint(a[1], UIParent, a[2], a[3], a[4])
  else
    lf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -140)
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
  if on and DB.modUtil ~= false then
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
    -- 同样不再按“越界”清档：坐标取不到才回默认，避免误判把用户位置冲掉
    local rL, rT = resF:GetLeft(), resF:GetTop()
    if not rL or not rT then
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

-- 职业不常变：缓存一次，省掉每次刷新的 UnitClass 调用
function U.PlayerClass()
  if U.pClass == nil then
    local _, cls = UnitClass("player")
    U.pClass = cls and string.lower(cls) or ""
  end
  return U.pClass
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
    local t2 = shardN .. "/20"
    if resF.shardTxt.__t ~= t2 then resF.shardTxt.__t = t2; resF.shardTxt:SetText(t2) end
    if not resF.shardTxt:IsShown() then resF.shardTxt:Show() end
  elseif resF.shardTxt:IsShown() then
    resF.shardTxt:Hide()
  end

  -- “文”开关：每条资源条上显示数字
  if not (U.off and U.off.text) then
    local t = DB.resTxt or {}
    local function txt(k, val)
      local fs = U.resTxtFS and U.resTxtFS[k]
      if not fs then return end
      if not t[k] then
        if fs:IsShown() then fs:Hide() end
        return
      end
      if not fs:IsShown() then fs:Show() end
      if fs.__v ~= val then fs.__v = val; fs:SetText(val) end
    end
    txt("power", (UnitMana("player") or 0) .. "/" .. (UnitManaMax("player") or 0))
    if U.swingRemain and U.swingRemain > 0 then
      txt("swing", string.format("%.1f", U.swingRemain))
    else
      txt("swing", "")
    end
    txt("self", (UnitHealth("player") or 0) .. "/" .. (UnitHealthMax("player") or 0))
    txt("target", (UnitHealth("target") or 0) .. "/" .. (UnitHealthMax("target") or 0))
    txt("pet", (UnitHealth("pet") or 0) .. "/" .. (UnitHealthMax("pet") or 0))
    -- 碎片那行已经有顶部 12/20：模块关了或“文”关掉都要藏
    if resF.shardTxt then
      local shardOn = DB.resShard and U.PlayerClass() == "warlock" and (t.shard ~= false)
      if shardOn then
        if not resF.shardTxt:IsShown() then resF.shardTxt:Show() end
      elseif resF.shardTxt:IsShown() then
        resF.shardTxt:Hide()
      end
    end
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
function U.ClearFinCache()
  local k
  for k in pairs(FIN_CACHE) do FIN_CACHE[k] = nil end
end

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

-- 终结技图标兜底：tooltip 读不全时按图标直接认（盗贼/小德常用终结技）
local FIN_ICONS = {
  ["Interface\\Icons\\Ability_Rogue_Eviscerate"] = true,
  ["Interface\\Icons\\Ability_Rogue_Rupture"] = true,
  ["Interface\\Icons\\Ability_Rogue_KidneyShot"] = true,
  ["Interface\\Icons\\Ability_Rogue_ExposeArmor"] = true,
  ["Interface\\Icons\\Ability_Rogue_SliceDice"] = true,
  ["Interface\\Icons\\Ability_Druid_FerociousBite"] = true,
  ["Interface\\Icons\\Ability_GhoulFrenzy"] = true,
}

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
  local fin = FIN_ICONS[tex] and true or false
  local lines = tooltipTexts(slot)
  -- 名字兜底：提示里没带描述时按技能名判断
  local i
  for i = 1, #lines do
    local l = lines[i]
    -- 只认“终结技”这个词；不能匹配“连击点”，否则影袭/背刺这种“奖励连击点”的技能也会被误判
    if string.find(l, "Finishing move", 1, true)
       or string.find(l, "终结技", 1, true) then
      fin = true
    end
    for nm in pairs(FIN_NAMES) do
      if string.find(l, nm, 1, true) then fin = true end
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
  -- 更直接的判断：这个格子确认过物品 id，而背包里该物品数量为 0 → 用光
  -- （不依赖“曾经见过数量”，重登后也能立刻变暗）
  if tex and U.slotItem then
    local sid = U.slotItem[slot .. "|" .. tex]
    if sid then
      if U.ItemCount(sid) < 1 then return "no" end
    end
  end
  -- 物品格不做距离判断：客户端对物品的 IsActionInRange 常返回 0，会把图标染成红色
  local itemKey = tex and U.slotItem and U.slotItem[slot .. "|" .. tex] or nil
  local usable, noMana = U.Usable(slot)
  local rng = (not itemKey and not skipRange and type(IsActionInRange) == "function")
              and IsActionInRange(slot) or nil
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
  no    = { 0.4, 0.4, 0.4 },     -- 其它原因不可用/用光（和暴雪原生一致）
  range = { 1.0, 0.1, 0.1 },   -- 超出射程
}

-- 动作格冷却：返回 (显示文字, 剩余秒, 总时长, 开始时间)
-- 规则统一：客户端没进冷却也会返回一对 start/du 哨兵值，必须确认“真的在走”；
-- GCD 级（<=1.6 秒）只画扫光不显示数字；宏格子不显示数字。
function U.ActionCd(slot, now)
  local start, du = GetActionCooldown(slot)
  local left, dur, from = 0, 0, nil
  if start and du and du > 0.05 and start > 0 then
    local t = start + du - now
    local cooling = (start <= now - 0.1) or (t < du - 0.1)
    if cooling and t > 0 then left, dur, from = t, du, start end
  end
  local txt = ""
  if left > 0 and dur > 1.6 then
    if left >= 60 then txt = string.format("%dm", math.floor(left / 60))
    else txt = string.format("%.1f", left) end
    if txt == "0.0" then txt = "" end
  end
  return txt, left, dur, from
end

-- 共用：数量文字（宏格子不显示）
function U.ActionCountText(slot, tex)
  local c = U.ActionCount(slot, tex)
  if c and c >= 1 then return tostring(c) end
  return ""
end

function U.TintIcon(b, state)
  if state == b.__tint then return end
  b.__tint = state
  local c = TINT[state] or TINT.ok
  if b.icon and b.icon.SetVertexColor then
    pcall(b.icon.SetVertexColor, b.icon, c[1], c[2], c[3])
  end
end

function U.UpdateClassCd()
  local now = GetTime()
  local i
  for i = 1, 10 do
    local b = G("ShapeshiftButton" .. i)
    if b and b.__cdTxt and b:IsShown() then
      local left = 0
      if type(GetShapeshiftFormCooldown) == "function" then
        local ok, st, du = pcall(GetShapeshiftFormCooldown, i)
        if ok and type(st) == "number" and type(du) == "number" and du > 0 and st > 0 and du <= 3600 then
          local t = st + du - now
          -- 这个客户端没进冷却时也会返回 start/du，必须确认它真的在走
          local cooling = (st <= now - 0.1) or (t < du - 0.1)
          if cooling and t > 0 then left = t end
        end
      end
      -- 不再给职业栏模拟 GCD：客户端没有形态冷却接口时就留空，避免一直跳数字
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
  local base = (pg - 1) * 12   -- 本页起始槽位，循环内直接算，省掉 12 次 U.SlotOf
  local now = GetTime()        -- 同一次刷新里所有格子的冷却用同一个时间点
  local j
  for j = 1, COUNT do
    local b = U.buttons[j]
    local a = j + base
    local txt, left, dur, cdFrom = "", 0, 0, nil
    if cachedTex[j] ~= nil then
      txt, left, dur, cdFrom = U.ActionCd(a, now)
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

-- 移动轮盘（LeftThumbstick）：开背包时客户端把它 Hide 掉，轮盘就没了。
-- 两层兜底：
--   1) 挡掉它的 Hide —— Lua 层的隐藏就永远不会生效，零开销；
--   2) 只在开背包相关事件（BAG_OPEN / BAG_UPDATE / BAG_CLOSE）里补一次 Show，
--      平时不做任何轮询检查。
-- 层级不动：轮盘留在客户端原本的层里，任务/对话等窗口照常画在它上面，
-- 不会像之前抬到 DIALOG 那样盖住别的面板。
function U.KeepThumbstick()
  local f = G("LeftThumbstick")
  if not f then return false end
  U.thumbFrame = f
  if not U.thumbKept then
    U.thumbKept = true
    if f.Hide then f.Hide = function() end end
  end
  if f.IsShown and not f:IsShown() and f.Show then pcall(f.Show, f) end
  return true
end

do
  local ev = CreateFrame("Frame")
  local list = { "BAG_OPEN", "BAG_UPDATE", "BAG_CLOSE" }
  local i
  for i = 1, #list do pcall(ev.RegisterEvent, ev, list[i]) end
  ev:SetScript("OnEvent", function() U.KeepThumbstick() end)
  U.thumbEvent = ev
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
-- 只把 Show 换回原函数，不主动显示（避免把客户端本来隐藏的副条强行弹出来）
function U.Unkill(fr)
  if not fr then return end
  if fr.__aiOrigShow then
    fr.Show = fr.__aiOrigShow
    fr.__aiOrigShow = nil
  end
end

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

-- 文字加粗：这个客户端没有粗体字体，用 OUTLINE 描边模拟，数量更好认

-- 这个客户端的 GetActionCount 永远返回 0，靠它显示数量/判断“喝完”都不行。
-- 用袋子里的物品反查：贴图 → 物品 id → GetItemCount 拿真实数量。
U.itemByTex = {}

function U.ScanBagItemTex()
  if type(GetContainerItemLink) ~= "function" or type(GetContainerItemInfo) ~= "function" then return end
  local now = GetTime()
  if U.texScanAt and now - U.texScanAt < 1 then return end
  U.texScanAt = now
  local m = U.itemByTex or {}
  local names = {}
  local bag
  for bag = 0, 4 do
    local n = 0
    local okn, vn = pcall(GetContainerNumSlots, bag)
    if okn then n = tonumber(vn) or 0 end
    local s
    for s = 1, n do
      local link = GetContainerItemLink(bag, s)
      if link then
        local tex = GetContainerItemInfo(bag, s)
        if tex then
          local id = string.match(link, "item:(%d+)")
          if id then
            id = tonumber(id)
            m[tex] = id
            local nm = string.match(link, "%[(.-)%]")
            if nm then names[nm] = id end
          end
        end
      end
    end
  end
  U.itemByTex = m
  U.itemIdByName = names
  -- 持久化名字表：用光后背包里没有这件东西，但 tooltip 还能读到名字
  DB.itemNames = DB.itemNames or {}
  do
    local nm, id2
    for nm, id2 in pairs(names) do DB.itemNames[nm] = id2 end
  end
end

-- 用光判断（两条路都试）：
--   1) 之前看到过数量 > 0，现在变 0
--   2) 这个图标在背包里出现过，现在背包里没有了

-- 动作格的物品 ID：先按图标粗筛，再用 tooltip 第一行（物品名）确认，
-- 避免“制皮技能”和“轻型护甲片”同图标时把护甲片数量算到技能上。
U.actNameCache = U.actNameCache or {}
-- slot|tex -> 物品 id。必须写进存档：重登后背包已经空了，靠它才能继续判定“用光”
U.slotItem = U.slotItem or {}
if type(DB.slotItem) == "table" then
  local k, v
  for k, v in pairs(DB.slotItem) do U.slotItem[k] = v end
end
U.slotName = U.slotName or {}
if type(DB.slotName) == "table" then
  local k, v
  for k, v in pairs(DB.slotName) do U.slotName[k] = v end
end
function U.SaveSlotItem(k, v, nm)
  U.slotItem[k] = v
  DB.slotItem = DB.slotItem or {}
  DB.slotItem[k] = v
  if nm then
    U.slotName = U.slotName or {}
    DB.slotName = DB.slotName or {}
    U.slotName[k] = nm
    DB.slotName[k] = nm
  end
end

-- 读动作格的 tooltip 第一行（物品名/技能名），结果按槽位+图标缓存
function U.ActionName(slot, tex)
  local key = slot .. "|" .. tex
  local nm = U.actNameCache[key]
  if nm ~= nil then return nm end
  nm = false
  if type(GameTooltip) == "table" and type(GameTooltip.SetAction) == "function" then
    pcall(GameTooltip.SetOwner, GameTooltip, UIParent, "ANCHOR_NONE")
    local ok = pcall(GameTooltip.SetAction, GameTooltip, slot)
    if ok then
      local fs = G("GameTooltipTextLeft1")
      local t = fs and type(fs.GetText) == "function" and fs:GetText()
      if type(t) == "string" and t ~= "" then nm = t end
    end
    pcall(GameTooltip.Hide, GameTooltip)
  end
  U.actNameCache[key] = nm
  return nm
end

-- 动作格的物品 ID：
--   1) 背包里有同图标 → 直接给 id
--   2) 背包里没有了 → 用 tooltip 名字查“持久化的物品名→id 表”
--   3) 都没有 → 用这个格子以前记下的 id
function U.ActionItemId(slot, tex)
  if not tex or not slot then return nil end
  local key = slot .. "|" .. tex
  local quick = U.itemByTex and U.itemByTex[tex]
  local nm = U.ActionName(slot, tex)
  if nm then
    -- 读到名字：只认名字匹配的物品；像“制皮”这种技能就算图标和物品一样也不给数量
    local id = (U.itemIdByName and U.itemIdByName[nm])
               or (DB.itemNames and DB.itemNames[nm])
    if id then U.SaveSlotItem(key, id, nm) return id end
    -- 名字能读到但不是物品：只有“同一个名字”以前记过才沿用缓存（防制皮误标）
    if U.slotItem[key] and U.slotName[key] == nm then return U.slotItem[key] end
    return nil
  end
  -- 读不到名字才退回按图标匹配
  if quick then U.SaveSlotItem(key, quick) return quick end
  return U.slotItem[key]
end

-- 把所有动作格上“有货”的物品 id 记下来（登录/背包变动时跑一次）
function U.CacheActionItems()
  -- 每次读 tooltip 有成本：3 秒内只跑一次（登录时会先清掉时间戳强制跑）
  local now = GetTime()
  if U.cacheAt and now - U.cacheAt < 3 then return end
  U.cacheAt = now
  local a
  for a = 1, 48 do
    local tex = GetActionTexture(a)
    -- 背包里没有同图标也要试：靠 tooltip 名字 + 持久化名字表反查物品 id
    if tex then pcall(U.ActionItemId, a, tex) end
  end
end

-- 物品数量带 1 秒缓存：ActionState 每次染色都会问，不能每次都走 GetItemCount
function U.ItemCount(id)
  if not id or type(GetItemCount) ~= "function" then return 0 end
  local now = GetTime()
  local c = U.itemCnt
  if not c then c = {}; U.itemCnt = c end
  local e = c[id]
  if e and now - e.t < 1 then return e.v end
  local v = tonumber(GetItemCount(id)) or 0
  c[id] = { v = v, t = now }
  return v
end

function U.ActionCount(slot, tex)
  local n = 0
  if type(GetActionCount) == "function" then
    n = tonumber(GetActionCount(slot)) or 0
  end
  local id = U.ActionItemId and U.ActionItemId(slot, tex)
  if n == 0 and id and type(GetItemCount) == "function" then
    local m = tonumber(GetItemCount(id))
    if m and m > 0 then n = m end
  end
  return n, id
end

function U.ApplyModules()
  -- 动作条模块：关了就把原生还回去并隐藏我们自己的条；重新打开时应用保存的布局
  local barOn = (DB.modBar ~= false)
  if barOn then
    U.ApplyNative()
    if panel then panel:Show() end
    if U.modBarOn ~= true then
      U.modBarOn = true
      U.Geo = true
      if U.Refresh then pcall(U.Refresh) end   -- 有保存的锚点就用保存的，没有就默认
    end
  else
    -- 只解除压制，不强行 Show：客户端本来隐藏的副条不会再冒出来
    local j
    for j = 1, 12 do U.Unkill(G("ActionButton" .. j)) end
    collectPattern()
    local q
    for q = 1, #patFrames do U.Unkill(patFrames[q]) end
    local e
    for e = 1, #EXTRA do U.Unkill(G(EXTRA[e])) end
    -- 主条默认是显示的：把 1~12 格显出来即可
    for j = 1, 12 do
      local b = G("ActionButton" .. j)
      if b and b.Show then pcall(b.Show, b) end
    end
    U.modBarOn = false
    if panel then panel:Hide() end
    local e
    for e = 2, 4 do
      local fr = U.extraBars and U.extraBars[e]
      if fr then
        if fr.handle then pcall(fr.handle.Hide, fr.handle) end
        fr:Hide()
      end
    end
    local hd = G("AIbarHandle")
    if hd then pcall(hd.Hide, hd) end
    U.modBarOn = false
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

  -- 资源条
  -- 资源条显隐由它自己的刷新逻辑决定（战斗外只显隐一次），这里只负责强制关闭
  local rf = G("AIbarRes")
  if rf and (DB.modRes == false or DB.resOn == false) then rf:Hide() end

  -- 辅助按钮（跳 / 目标）：受“辅助按钮”模块和各自开关控制
  local uj, ut, rlb = G("AIbarUtiljump"), G("AIbarUtiltarget"), G("AIbarRL")
  local utilOn = DB.modUtil ~= false
  local function showUtil(x, on)
    if not x then return end
    if utilOn and on ~= false then x:Show() else x:Hide() end
  end
  showUtil(uj, DB.jumpOn)
  showUtil(ut, DB.targetOn)
  -- RL 独立：不再随“辅助按钮”模块一起关掉
  if rlb then
    if DB.rlButton ~= false then rlb:Show() else rlb:Hide() end
  end
end

-- ---------- 聊天快捷按钮 ----------
-- 聊天框上方一排频道按钮：点一下把频道前缀填进输入框（不直接发言，防误触）。
-- 频道号按游戏里的实际列表：3 本地防务、4 世界防务、5 寻求组队
U.CHATBTNS = {
  { "说", "/s ", nil, "说话  /s" },
  { "喊", "/y ", nil, "呼喊  /y" },
  { "会", "/g ", nil, "公会  /g" },
  { "队", "/p ", nil, "小队  /p" },
  { "团", "/ra ", nil, "团队  /ra" },
  { "本", "/3 ", nil, "本地防务  /3" },
  { "世", "/4 ", nil, "世界防务  /4" },
  { "组", "/5 ", nil, "寻求组队  /5" },
  { "骰", nil, "roll", "掷骰  /random 100" },
}

-- 触摸提示：手指按上去就弹说明（这个客户端没有鼠标悬停）
function U.ShowTip(b, txt)
  if not GameTooltip or type(GameTooltip.SetOwner) ~= "function" then return end
  pcall(GameTooltip.SetOwner, GameTooltip, b, "ANCHOR_TOP")
  if type(GameTooltip.SetText) == "function" then pcall(GameTooltip.SetText, GameTooltip, txt) end
  if type(GameTooltip.Show) == "function" then pcall(GameTooltip.Show, GameTooltip) end
end

function U.HideTip()
  if GameTooltip and type(GameTooltip.Hide) == "function" then pcall(GameTooltip.Hide, GameTooltip) end
end

-- 骰子：能直接掷就直接掷，不行就退回“把 /random 100 填进输入框”
function U.ChatRoll()
  if type(RandomRoll) == "function" then
    local ok = pcall(RandomRoll, 1, 100)
    if ok then return end
  end
  U.ChatOpen("/random 100 ")
end

function U.ChatOpen(cmd)
  -- 优先用客户端自带的“打开聊天并填内容”，没有就退回输入框
  if type(ChatFrame_OpenChat) == "function" then
    local ok = pcall(ChatFrame_OpenChat, cmd)
    if ok then return end
  end
  local eb = G("ChatFrame1EditBox")
  if not eb then return end
  if type(eb.Show) == "function" then pcall(eb.Show, eb) end
  if type(eb.SetText) == "function" then pcall(eb.SetText, eb, cmd) end
  if type(eb.SetFocus) == "function" then pcall(eb.SetFocus, eb) end
end

-- 建一个频道按钮：文字、点击、按下说明都挂好
function U.AddChatBtn(bar, d, i)
  local b = CreateFrame("Button", nil, bar)
  b:SetWidth(40)
  b:SetHeight(32)
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
  t:SetText(d[1])
  b.lbl = t
  local tip = d[4] or d[1]
  b:SetScript("OnClick", function()
    if d[3] == "roll" then U.ChatRoll() else U.ChatOpen(d[2]) end
  end)
  b:SetScript("OnEnter", function()
    this:SetBackdropColor(0.26, 0.24, 0.2, 0.98)
    U.ShowTip(b, tip)
  end)
  b:SetScript("OnLeave", function()
    this:SetBackdropColor(0.16, 0.15, 0.14, 0.9)
    U.HideTip()
  end)
  b:SetScript("OnMouseDown", function() U.ShowTip(b, tip) end)
  b:SetScript("OnMouseUp", function() U.HideTip() end)
  return b
end

-- 大文本窗口（物品说明书的 ItemTextFrame）打开时，把聊天快捷栏收起来，别浮在上面
-- 聊天快捷栏不再挂到 ChatFrame1：独立浮层，聊天框隐藏/移动都不影响它，可自由拖
function U.ApplyChatBar()
  local cf = G("ChatFrame1")
  local bar = U.chatBar
  if not bar then
    bar = CreateFrame("Frame", "AIbarChatBar", UIParent)
    U.chatBar = bar
    bar:SetHeight(34)
    bar:SetWidth(#U.CHATBTNS * 44)
    -- 压在宏/背包等原生窗口下面，避免聊天快捷按钮盖住它们
    bar:SetFrameStrata("LOW")
    if bar.SetFrameLevel then bar:SetFrameLevel(1) end
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() bar:StartMoving() end)
    bar:SetScript("OnDragStop", function()
      bar:StopMovingOrSizing()
      local pt, rp, x, y = bar:GetPoint()
      if pt then
        DB.chatAnchor = { pt, rp or pt, x or 0, y or 0 }
        DB.chatX, DB.chatY = 0, 0
        U.Save()
      end
    end)
    local i
    for i = 1, #U.CHATBTNS do
      U.AddChatBtn(bar, U.CHATBTNS[i], i)
    end
    -- 默认放在聊天框左上角上方；聊天框还没建好就放屏幕左下
    if not (type(DB.chatAnchor) == "table" and DB.chatAnchor[1]) then
      local l, t
      if cf and cf.GetLeft and cf.GetTop then
        l, t = cf:GetLeft(), cf:GetTop()
      end
      if type(l) ~= "number" or type(t) ~= "number" then l, t = 40, 150 end
      DB.chatAnchor = { "BOTTOMLEFT", "BOTTOMLEFT", l, t + 4 }
    end
  end
  local a = DB.chatAnchor
  if type(a) == "table" and a[1] then
    bar:ClearAllPoints()
    bar:SetPoint(a[1], UIParent, a[2] or a[1],
      (a[3] or 0) + (DB.chatX or 0), (a[4] or 0) + (DB.chatY or 0))
  end
  if bar.SetScale then pcall(bar.SetScale, bar, DB.chatScale or 1) end
  if DB.chatBar == false then bar:Hide() else bar:Show() end
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

-- 配置按钮：做成小地图旁边那种圆形图标按钮，点开配置面板
local cfgBtn = CreateFrame("Button", "AiBarCfgBtn", UIParent)
cfgBtn:SetWidth(32)
cfgBtn:SetHeight(32)
cfgBtn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
cfgBtn.icon = cfgBtn:CreateTexture(nil, "BACKGROUND")
cfgBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
cfgBtn.icon:SetAllPoints(cfgBtn)
if cfgBtn.SetHighlightTexture then pcall(cfgBtn.SetHighlightTexture, cfgBtn, "Interface\\Buttons\\ButtonHilight-Square", "ADD") end
-- 配置面板是 DIALOG 层：按钮如果被拖到屏幕中间，打开面板后会正好被面板盖住，
-- 看起来就像“按钮不见了”。把按钮提到面板之上，永远看得见也点得到。
-- 配置图标压在原生背包/聊天等界面下面：LOW 层，避免盖住背包窗口
if cfgBtn.SetFrameStrata then pcall(cfgBtn.SetFrameStrata, cfgBtn, "LOW") end
if cfgBtn.SetFrameLevel then pcall(cfgBtn.SetFrameLevel, cfgBtn, 1) end
-- 图标按钮不再写字（小地图那块地方小），鼠标悬停给个提示
if cfgBtn.SetScript and GameTooltip then
  cfgBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(cfgBtn, "ANCHOR_RIGHT")
    GameTooltip:SetText("AiBar 配置")
    GameTooltip:Show()
  end)
  cfgBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
local function toggleConfig()
  local cf = G("AIbarConfig")
  if cf then
    if cf:IsShown() then cf:Hide() else cf:Show() end
  end
end

-- 固定在小地图正上方：不能拖动，按下出说明、点一下开关面板
cfgBtn:SetScript("OnMouseDown", function() U.ShowTip(cfgBtn, "AiBar 配置｜点一下打开面板") end)
cfgBtn:SetScript("OnMouseUp", function() U.HideTip() end)
cfgBtn:SetScript("OnClick", toggleConfig)

-- 角度：0 度 = 正右，逆时针为正；90 度 = 正上方
U.CfgAngleDeg = 90

function U.ChatCfgRadius()
  local mm = Minimap
  if not mm then return nil end
  local w = tonumber(mm:GetWidth()) or 0
  local h = tonumber(mm:GetHeight()) or 0
  local base = math.max(w, h)
  -- 这个客户端有些框体的尺寸会返回离谱值（0 或整个屏幕），夹一下，免得按钮飞到天边
  if base < 40 or base > 600 then base = 150 end
  local r = base / 2 + 12
  if r < 30 then r = 30 elseif r > 200 then r = 200 end
  return r
end

-- 偏移只算一次并缓存：反复开关面板/显隐按钮时不再重算，按钮就不会一点点挪位
function U.CfgPlace()
  local mm = Minimap
  if not mm then return false end
  if not U.cfgOffX then
    local r = U.ChatCfgRadius() or 95
    local a = math.rad(U.CfgAngleDeg or 90)
    U.cfgOffX, U.cfgOffY = math.cos(a) * r, math.sin(a) * r
  end
  cfgBtn:ClearAllPoints()
  cfgBtn:SetPoint("CENTER", mm, "CENTER", U.cfgOffX, U.cfgOffY)
  return true
end

function U.CfgDefaultPoint()
  if U.CfgPlace() then return end
  cfgBtn:ClearAllPoints()
  cfgBtn:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -104, 160)
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
  local y = 2
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
  y = y + 60
  DB.targetAnchor = { "BOTTOM", "BOTTOM", 0, y }
  y = y + 64 + handleH + gap
  DB.jumpAnchor = { "BOTTOM", "BOTTOM", 0, y }
  y = y + 64 + handleH + gap
  DB.classAnchor = { "BOTTOM", "BOTTOM", 0, y }
end

-- 把「相对动作条 1」摆放的副条 2~4 改成屏幕绝对坐标。
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
end

function U.ApplyCfgBtn()
  -- 只有第一次（或重置后没摆过）才设锚点；单纯显隐不碰位置
  if not U.cfgPlaced then
    U.cfgPlaced = true
    U.CfgDefaultPoint()
  end
  if DB.cfgBtn ~= false then cfgBtn:Show() else cfgBtn:Hide() end
end

-- 切语言后的提示框：明确告诉玩家“已切到哪种语言”，重载后界面才变
U.LANG_TIP = {
  zh = { title = "语言已切换", l1 = "界面语言已切换为中文", l2 = "重载界面后生效。" },
  en = { title = "Language changed", l1 = "Interface language is now English.", l2 = "Reload the UI to apply." },
}
function U.LangReloadTip(code)
  code = code or U.CurLang()
  local tip = U.LANG_TIP[code] or U.LANG_TIP.en
  local f = _G.AIbarLangTip
  if not f then
    f = CreateFrame("Frame", "AIbarLangTip", UIParent)
    f:SetWidth(330)
    f:SetHeight(156)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(200)
    if f.SetToplevel then f:SetToplevel(true) end
    f:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.92)
    f:SetBackdropBorderColor(1, 0.82, 0, 1)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", f, "TOP", 0, -18)
    f.l1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.l1:SetPoint("TOP", f, "TOP", 0, -48)
    f.l2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.l2:SetPoint("TOP", f, "TOP", 0, -66)
    local function mk(text, x, fn)
      local b = CreateFrame("Button", nil, f)
      b:SetWidth(122)
      b:SetHeight(28)
      b:SetPoint("BOTTOM", f, "BOTTOM", x, 16)
      b:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
      })
      b:SetBackdropColor(0.18, 0.16, 0.12, 0.95)
      b:SetBackdropBorderColor(0.55, 0.46, 0.3, 1)
      b.lbl = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      b.lbl:SetPoint("CENTER", b, "CENTER", 0, 0)
      b:SetScript("OnClick", fn)
      return b
    end
    f.ok = mk("立即重载", -66, function() ReloadUI() end)
    f.cancel = mk("稍后", 66, function() f:Hide() end)
  end
  f.title:SetText(tip.title)
  f.l1:SetText(tip.l1)
  f.l2:SetText(tip.l2)
  f.ok.lbl:SetText(U.L("立即重载"))
  f.cancel.lbl:SetText(U.L("稍后"))
  f:Show()
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
  U.UpdateFlash()
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
    U.swingRemain = speed - el
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
end

-- 这个客户端没有 os 库（os 是 nil，不是 nil 的字段），
-- 所以不能写 os.clock 甚至 os.clock and ...，必须先用 type(os) 判一下。

local acc, acc2, acc3, accX, acc4, acc5 = 0, 0, 0, 0, 0, 0
local wasStealth = false
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
  -- 这一帧的时间戳只取一次，下面十几处条件判断共用
  local now = GetTime()

  -- 帧间隔只归一化一次：单帧值 > 1 视为毫秒（手机客户端可能是 16 左右）。
  -- 长按 3 秒、各处节拍累加都用这个 dt，避免毫秒单位把 5 秒存档算成每帧一次。
  local dt = arg1 or 0
  if dt > 1 then dt = dt / 1000 end
  U.now = (U.now or 0) + dt
  if U.pressSlot then
    if U.now - (U.pressT or 0) >= 3 then
      local ps = U.pressSlot
      U.pressSlot = nil
      if ps and GetActionTexture(ps) and not DB.skillLock then
        U.pressSwapped = true
        U.OpenPicker(ps)
      end
    end
  end


  -- 先存档：这段放在最前面，后面任何一段报错都不会把这次的设置改动丢掉
  acc3 = acc3 + dt
  if acc3 > 5 then
    acc3 = 0
    U.Save()
  end

  -- 分帧推进原生潜游按钮扫描（每次 20 个框体，不再一口气冻住）
  if not U.utilScanDone and DB.modUtil ~= false then U.ScanUtilChunk(20) end

  -- 空闲时慢慢预热两个页面的图标贴图（战斗里不跑，避免影响手感）
  -- 客户端登录后会把原生姿态/形态栏重新显示出来，这里持续压住它，
  -- 避免“刚进游戏先看到原生条、一两秒后才换成自己的”那一下闪烁
  U.cbAcc = (U.cbAcc or 0) + dt
  if U.cbAcc > 0.3 then
    U.cbAcc = 0
    if DB.classBar then
      local cbF = G("ShapeshiftBarFrame")
      if cbF and cbF.IsShown and cbF:IsShown() then pcall(cbF.Hide, cbF) end
    end
  end

  -- 职业栏：登录后前几秒 GetNumShapeshiftForms 可能还是 0，建不起来，
  -- 这里持续重试，避免要等 2 秒整刷才显示
  if DB.classBar then
    local watching = U.cbWatchUntil and (U.now or 0) < U.cbWatchUntil
    if watching or not U.classApplied then
      U.cbAccTry = (U.cbAccTry or 0) + dt
      local wait = U.classApplied and 0.5 or 0.2
      if U.cbAccTry > wait then
        U.cbAccTry = 0
        -- 主动催客户端把姿态/形态按钮建出来，别等它自己建
        if type(ShapeshiftBarFrame_Update) == "function" then pcall(ShapeshiftBarFrame_Update) end
        if type(UpdateShapeshiftBar) == "function" then pcall(UpdateShapeshiftBar) end
        U.ApplyClassBar()
      end
    end
  end

  if U.tipHideAt and now >= U.tipHideAt then
    U.tipHideAt = nil
    if type(GameTooltip.Hide) == "function" then pcall(GameTooltip.Hide, GameTooltip) end
  end

  U.preAcc = (U.preAcc or 0) + dt
  if U.preAcc > 0.15 and (U.preIdx or 0) < 24 then
    U.preAcc = 0
    if not UnitAffectingCombat("player") then U.PreloadStep() end
  end

  -- 动作条/技能变化：整帧只刷新一次，而且只换图标文字，不做宠物条/职业条重挂
  if U.barDirty then
    U.barDirty = false
    resetTexCache()
    U.Refresh(true)
    updateExtra()
    U.UpdateStates()
    U.UpdateTint()
  end

  if (U.dragCount or 0) > 0 then U.UpdateDrags() end
  -- 动画帧率减半：手机上肉眼看不出差别，省一半每帧开销
  U.animTick = (U.animTick or 0) + 1
  if U.animTick % 2 == 0 then U.UpdateAnim() end

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

  accX = accX + dt
  if accX > 0.3 then
    accX = 0
    -- 职业标每秒兜底刷新：尺寸/位置改了一定会跟上
    if U.UpdateTargetClass then pcall(U.UpdateTargetClass) end
    updateExtra()
    U.UpdateTint()
    updateRes()
    local stNow, changed = U.RefreshStealth()
    if changed and stNow ~= wasStealth then
      wasStealth = stNow
      if not U.stSkip then
        resetTexCache()
        U.Refresh(true)   -- 潜行换页只换图标，不做整条重排
      end
    end
  end

  acc5 = acc5 + dt
  if acc5 > 0.5 then
    acc5 = 0
    U.UpdateCasts()
  end

  acc2 = acc2 + dt
  if acc2 > 4 then
    acc2 = 0
    U.Refresh()
  end

  if U.PendingClamp then
    local pc = U.PendingClamp
    U.PendingClamp = nil
    clampToScreen(pc)
  end

  acc4 = acc4 + dt
  if acc4 > 3 then
    acc4 = 0
    -- 模块重设是重活（原生框体反复 Hide 会触发客户端布局重建），
    -- 统一放到 15 秒块里，3 秒块只做轻量的帧内判断
    if not (U.off and U.off.mods) and (U.modDirty or now >= (U.modNext or 0)) then
      U.modDirty = nil
      U.modNext = now + 15
      if DB.modUtil ~= false then hideUtilNative() end
      U.Geo = true
      U.ApplyModules()
    end
  end

end)

-- ---------- 事件驱动刷新 ----------
-- 换技能 / 学新技能 / 切页 / 进世界时马上重扫图标，不再等 2 秒的兜底轮询。
-- 这些事件都不带参数，直接整条重扫最省事，而且频率很低。
do  -- 用 do 包起来：主块局部变量已接近 200 上限，块内的局部出了块就释放
local barEv = CreateFrame("Frame")
local BAR_EVENTS = { "ACTIONBAR_SLOT_CHANGED", "SPELLS_CHANGED", "PLAYER_LEVEL_UP",
                     "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
                     "PLAYER_ENTERING_WORLD", "BAG_UPDATE", "BAG_UPDATE_COOLDOWN",
                     "UPDATE_SHAPESHIFT_FORMS", "UNIT_DISPLAYPOWER" }
local bei
for bei = 1, #BAR_EVENTS do pcall(barEv.RegisterEvent, barEv, BAR_EVENTS[bei]) end
barEv:SetScript("OnEvent", function()
  if not U.Ready then return end      -- 登录前的事件先忽略，等 loader 初始化完
  -- 换页/换技能时客户端是按“每个格子一条”连发事件的（一页 12 条）。
  -- 以前每条都当场整条刷新，一次换页就重跑十几遍 ApplyPet/ApplyClassBar，
  -- 这些重挂在客户端侧要好几秒（就是潜行换页卡 2~4 秒的真凶）。
  -- 现在只打标记，主循环下一帧合并成一次轻量刷新。
  -- 形态/资源类型变化：职业栏可能刚建好，立刻应用，别等 2 秒整刷
  if event == "UPDATE_SHAPESHIFT_FORMS" or event == "UNIT_DISPLAYPOWER" then
    U.cbAccTry = 0
    if U.ApplyClassBar then pcall(U.ApplyClassBar) end
    return
  end
  -- 背包变动（喝光/补货）要立刻重算数量和“用光变暗”，不能等 1 秒慢档
  if event == "BAG_UPDATE" or event == "BAG_UPDATE_COOLDOWN" then
    U.itemCnt = nil
    U.texScanAt = nil
    if U.ScanBagItemTex then pcall(U.ScanBagItemTex) end
    if U.CacheActionItems then pcall(U.CacheActionItems) end
    if U.RefreshExtra then pcall(U.RefreshExtra) end
    if U.UpdateTint then pcall(U.UpdateTint) end
    return
  end
  U.barDirty = true
  U.actNameCache = {}                 -- 换过技能，物品名缓存作废
  U.preIdx = 0                        -- 技能变了，预加载要重来
end)
end

-- ---------- 命令 ----------
SLASH_EVALBARCMD1 = "/abc"

local function say(t)
  DEFAULT_CHAT_FRAME:AddMessage("|cff7CECFFAiBar|r " .. t)
end

-- ---------- 触屏摇杆（移动轮盘）诊断 ----------
-- 客户端自带的移动轮盘不在 AIbar 里，开背包时是"被隐藏"还是"被盖住"、
-- 以及它到底有没有暴露成 Lua 框体，都只能到运行时去看：
-- 全帧枚举在这个客户端上要一两秒，所以只在手动敲命令时跑。

-- 统一的队伍角色判断：团队/小队、队长/团长、团队助理
function U.GroupRole()
  local raid = type(GetNumRaidMembers) == "function" and (GetNumRaidMembers() or 0) > 0
  local party = type(GetNumPartyMembers) == "function" and (GetNumPartyMembers() or 0) > 0
  local leader = false
  local officer = false
  if raid then
    leader = type(IsRaidLeader) == "function" and IsRaidLeader() and true or false
    officer = type(IsRaidOfficer) == "function" and IsRaidOfficer() and true or false
  elseif party then
    leader = type(IsPartyLeader) == "function" and IsPartyLeader() and true or false
  end
  return raid, party, leader, officer
end

-- ---------- 团队：就位确认 / 开怪倒计时 ----------
do
  local f = CreateFrame("Frame", "AIbarPull", UIParent)
  f:SetWidth(360)
  f:SetHeight(420)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 110)
  f:SetFrameStrata("TOOLTIP")
  local t = f:CreateTexture(nil, "ARTWORK")
  t:SetPoint("CENTER", f, "CENTER", 0, 0)
  t:SetWidth(240)
  t:SetHeight(300)
  f:Hide()
  U.pullF, U.pullTex = f, t
  local function pullShow(n)
    U.pullTex:SetTexture("Interface\\AddOns\\AIbar\\tex\\pull" .. tostring(n))
  end

  function U.PullSay(msg)
    local raid = type(GetNumRaidMembers) == "function" and (GetNumRaidMembers() or 0) > 0
    local party = type(GetNumPartyMembers) == "function" and (GetNumPartyMembers() or 0) > 0
    if not raid and not party then return end   -- 单人没有可喊的频道
    if type(SendChatMessage) == "function" then
      pcall(SendChatMessage, msg, raid and "RAID" or "PARTY")
    end
  end

  function U.PullTick()
    if not U.pullEnd then return end
    local left = math.ceil(U.pullEnd - (U.now or 0))
    if left > 0 then
      if left ~= U.pullLast then
        U.pullLast = left
        pullShow(left)
      end
    else
      if U.pullLast ~= 0 then
        U.pullLast = 0
        pullShow("go")
        U.PullSay("GO！")
      end
      if (U.now or 0) > U.pullEnd + 1.2 then
        U.pullEnd = nil
        f:Hide()
      end
    end
  end

  function U.PullStart(sec)
    sec = tonumber(sec) or 5
    U.pullEnd = (U.now or 0) + sec
    U.pullLast = nil
    pullShow(sec)
    f:Show()
    -- 只在结束时喊一次 GO，不逐秒刷屏
    U.PullTick()
  end

  f:SetScript("OnUpdate", function() U.PullTick() end)

  -- 队长发起 / 队员确认，一个按钮自动判断
  function U.ReadyAction()
    local raid, party, leader, officer = U.GroupRole()
    local isLeader = leader or (raid and officer)
    -- 结果打到聊天框，但 2 秒内只打一行，防止狂点刷屏
    local function tell(msg)
      local now = U.now or 0
      if U.lastReadyAt and now - U.lastReadyAt < 2 then return end
      U.lastReadyAt = now
      say(msg)
    end
    if not raid and not party then
      tell("就位确认：单人无效，需要先组队")
      return
    end
    if isLeader then
      if type(DoReadyCheck) == "function" then pcall(DoReadyCheck) end
      tell("就位确认：已发起")
    else
      if type(ConfirmReadyCheck) == "function" then pcall(ConfirmReadyCheck, 1) end
      tell("就位确认：已确认就位")
    end
  end
end

-- ---------- 快速标记条 ----------
-- 客户端自带 Interface\TargetingFrame\UI-RaidTargetingIcon_1..8 贴图；
-- 点同一个图标 = 取消标记。只有队长/助理能改标记，普通队员点了客户端会静默忽略。
-- 包成函数执行：主块局部变量已经到 200 上限
;(function()
  local N, STEP = 8, 52
  local f = CreateFrame("Frame", "AIbarMarks", UIParent)
  f:SetWidth((N + 1) * STEP + 4 + 4 + 46 + 4 + 60 + 2)
  f:SetHeight(54)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0.05, 0.05, 0.06, 0.85)
  f:SetBackdropBorderColor(0.42, 0.39, 0.34, 1)
  U.markF = f

  -- 单人随便标；组队/团队只允许队长（团队就是团长/助理）标
  local function canMark()
    local raid, party, leader, officer = U.GroupRole()
    if not raid and not party then return true end
    if raid then return leader or officer end
    return leader
  end
  local function markDenied()
    if not U.markWarned then
      U.markWarned = true
      say("标记：组队/团队里只有队长、团长和助理能打标记")
    end
  end

  -- 点击反馈：按下时叠一层白色高光，随后淡出
  local function feedback(b)
    if not b then return end
    if not b.__pick then
      local t = b:CreateTexture(nil, "OVERLAY")
      t:SetAllPoints(b)
      t:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
      if t.SetBlendMode then t:SetBlendMode("ADD") end
      t:SetAlpha(0)
      b.__pick = t
    end
    b.__pick:SetAlpha(0.85)
    if b.__pickFade then return end
    b.__pickFade = true
    b:SetScript("OnUpdate", function()
      local a = (b.__pick and b.__pick:GetAlpha() or 0) - 0.06
      if a <= 0 then
        if b.__pick then b.__pick:SetAlpha(0) end
        b.__pickFade = false
        b:SetScript("OnUpdate", nil)
      else
        b.__pick:SetAlpha(a)
      end
    end)
  end

  local btns = {}
  local function paint()
    local cur = 0
    if UnitExists("target") and type(GetRaidTargetIndex) == "function" then
      cur = tonumber(GetRaidTargetIndex("target")) or 0
    end
    if not canMark() then
      if f.SetAlpha then f:SetAlpha(0.45) end
    else
      if f.SetAlpha then f:SetAlpha(1) end
    end
    if cur == (U.markLast or -1) then return end
    U.markLast = cur
    local k
    for k = 1, N do
      if btns[k] then
        if k == cur then btns[k].hl:Show() else btns[k].hl:Hide() end
      end
    end
  end

  local i
  for i = 1, N do
    local b = CreateFrame("Button", nil, f)
    b:SetWidth(44)
    b:SetHeight(44)
    b:SetPoint("LEFT", f, "LEFT", 2 + (i - 1) * STEP, 0)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(b)
    t:SetTexture("Interface\\AddOns\\AIbar\\tex\\mark" .. i)
    local hl = b:CreateTexture(nil, "OVERLAY")
    hl:SetAllPoints(b)
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    if hl.SetBlendMode then hl:SetBlendMode("ADD") end
    hl:Hide()
    b.hl = hl
    b:SetScript("OnClick", function()
      feedback(b)
      if not UnitExists("target") then return end
      if not canMark() then markDenied(); return end
      local cur = type(GetRaidTargetIndex) == "function" and tonumber(GetRaidTargetIndex("target")) or 0
      if cur == i then
        SetRaidTarget("target", 0)
      else
        SetRaidTarget("target", i)
      end
      U.markLast = -1
      paint()
    end)
    btns[i] = b
  end
  U.markBtns = btns

  -- 清除按钮：把当前目标身上的标记去掉
  local clr = CreateFrame("Button", nil, f)
  clr:SetWidth(44)
  clr:SetHeight(44)
  clr:SetPoint("LEFT", f, "LEFT", 2 + N * STEP, 0)
  local cl = clr:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  cl:SetPoint("CENTER", clr, "CENTER", 0, 0)
  cl:SetText("|cffff5555清|r")
  clr:SetScript("OnClick", function()
    feedback(clr)
    if not canMark() then markDenied(); return end
    if UnitExists("target") then
      SetRaidTarget("target", 0)
      U.markLast = -1
      paint()
    end
  end)
  U.markClear = clr

  -- 就位确认 / 开怪倒计时：挂在标记条尾部
  local xTail = 2 + (N + 1) * STEP + 4
  local function mkTeamBtn(text, x, w, fn)
    local b = CreateFrame("Button", nil, f)
    b:SetWidth(w)
    b:SetHeight(44)
    b:SetPoint("LEFT", f, "LEFT", x, 0)
    b:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    b:SetBackdropColor(0.16, 0.15, 0.14, 0.95)
    b:SetBackdropBorderColor(0.55, 0.46, 0.3, 1)
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t:SetPoint("CENTER", b, "CENTER", 0, 0)
    t:SetText(U.L(text))
    b:SetScript("OnClick", function()
      feedback(b)
      fn()
    end)
    return b
  end
  U.markReadyBtn = mkTeamBtn("就位", xTail, 46, function() U.ReadyAction() end)
  U.markPullBtn = mkTeamBtn("倒计时", xTail + 50, 60, function() U.PullStart(5) end)

  -- 拖动统一交给 U.MakeDraggable：RL、跳跃、目标按钮都用这套，
  -- 它会自己算光标位移并在松手时回调 drop（不依赖坏掉的 StartMoving）
  do
    local kids = { f:GetChildren() }
    local i
    for i = 1, #kids do
      local b = kids[i]
      if b then
        U.MakeDraggable(f, b, {
          noClamp = true,   -- 标记条允许拖到任何位置（不做屏幕边缘夹取）
          drop = function(pt, relf, rp, x, y)
            DB.markAnchor = { pt, rp or pt, x or 0, y or 0 }
            DB.markOffX, DB.markOffY = 0, 0
            U.Save()
          end,
        })
      end
    end
  end

  function U.ApplyMarks()
    f:ClearAllPoints()
    local a = DB.markAnchor
    if type(a) == "table" and a[1] then
      f:SetPoint(a[1], UIParent, a[2] or a[1],
        (a[3] or 0) + (DB.markOffX or 0), (a[4] or 0) + (DB.markOffY or 0))
    else
      f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 176)
    end
    f:SetScale(DB.markScale or 1)
    if DB.markOn ~= false then f:Show() else f:Hide() end
    U.markLast = -1
    paint()
  end

  local acc = 0
  local ticker = CreateFrame("Frame")
  ticker:SetScript("OnUpdate", function()
    if not f:IsShown() then return end
    acc = acc + (arg1 or 0)
    if acc < 0.3 then return end
    acc = 0
    paint()
  end)
end)()

SlashCmdList["EVALBARCMD"] = function(msg)
  msg = string.lower(msg or "")
  if msg == "skin" then DB.skin = not DB.skin
  elseif msg == "move" then U.SetMovable(not DB.move)
  elseif msg == "macro" then
    local gen, char = 0, 0
    if type(GetNumMacros) == "function" then
      local ok, a, b = pcall(GetNumMacros)
      if ok then gen, char = tonumber(a) or 0, tonumber(b) or 0 end
    end
    say("宏：通用 " .. gen .. " / 角色 " .. char ..
        "；GetMacroInfo " .. (type(GetMacroInfo) == "function" and "可用" or "不可用"))
    return
  elseif msg == "pc" then
    if DB.pcMode == nil then DB.pcMode = "pc"
    elseif DB.pcMode == "pc" then DB.pcMode = "touch"
    else DB.pcMode = nil end
    U.TouchMode = U.IsTouchClient()
    U.Save(true)
    say("平台模式：" .. (DB.pcMode == "pc" and "电脑" or DB.pcMode == "touch" and "触屏" or "自动") ..
        "（尺寸需要 /reload 或点 RL 重载后生效）")
    return
  elseif msg == "light" then
    U.LightMode(true)
    say("轻量模式：关掉闪光/资源文字/周期重设")
    return
  elseif string.sub(msg, 1, 6) == "light " then
    local which = string.sub(msg, 7)
    if which == "all" then
      U.LightMode(true)
      say("全关")
    elseif which == "on" then
      U.LightMode(false)
      say("全开")
    else
      U.off = U.off or {}
      U.off[which] = not U.off[which]
      say(which .. "：" .. (U.off[which] and "关" or "开"))
    end
    return
  elseif string.sub(msg, 1, 4) == "lang" then
    local which = string.sub(msg, 6)
    if which == "zh" or which == "en" or which == "auto" then
      DB.lang = which
      U.Save(true)
      say("语言 / language: " .. which .. "（/reload 后界面生效）")
    else
      say("用法：/abc lang zh | en | auto")
    end
    return
  elseif msg == "lock" then
    DB.skillLock = not DB.skillLock
    U.Save(true)
    say("技能锁定：" .. (DB.skillLock and "开（非空格不能换技能，空位还能加）" or "关"))
    return
  elseif msg == "chatbar" then
    DB.chatBar = (DB.chatBar == false)
    U.ApplyChatBar()
    U.Save(true)
    say("聊天快捷按钮：" .. (DB.chatBar ~= false and "开" or "关"))
    return
  elseif msg == "help" or msg == "" then
    say("/ab　打开配置面板")
    say("/abc skin　背板开/关")
    say("/abc move　进入/退出移动模式")
    say("/abc pc　平台模式：自动 / 电脑 / 触屏")
    say("/abc chatbar　聊天框上方快捷频道按钮 开/关")
    say("/abc lock　技能锁定 开/关（非空格不能换，空位仍可加）")
    say("操作：空格子左键选技能/宏/物品；有技能短按施放，长按 3 秒或右键换技能")
    say("界面：打开「移动」后拖动各组件；「配置」按钮随时可拖；改动即时生效")
    say("界面：「模块」页关掉哪块就还回原生")
    return
  else
    say("/abc skin | move | pc | chatbar | lock | lang | macro | help")
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
    -- 进出潜行后立刻重算染色，别等 0.1/0.3 秒的节拍
    if U.UpdateTint then pcall(U.UpdateTint) end
    if U.RefreshExtra then pcall(U.RefreshExtra) end
  end
end)

U.lootEv = CreateFrame("Frame")
U.lootEv:RegisterEvent("LOOT_OPENED")
U.lootEv:SetScript("OnEvent", function()
  if U.Ready and U.ApplyLootFrame then pcall(U.ApplyLootFrame) end
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_LOGOUT")
loader:SetScript("OnEvent", function()
  -- 退出/重载前再落一次盘：手机端很可能等不到 5 秒的定时保存就被切掉
  if event == "PLAYER_LOGOUT" then U.Save(true); return end
  if event ~= "PLAYER_LOGIN" then return end
  U.Restore()
  U.cbWatchUntil = (U.now or 0) + 8
  if (DB.finVer or 0) < 3 then
    DB.finVer = 3
    DB.finCache = {}
    if U.ClearFinCache then pcall(U.ClearFinCache) end
  end
  -- 老存档：动作条整体往屏幕底部沉一次（用户反馈位置偏高）
  if (DB.sinkVer or 0) < 1 then
    DB.sinkVer = 1
    local keys = { "anchor", "bar2Anchor", "bar3Anchor", "bar4Anchor" }
    local i
    for i = 1, 4 do
      local a = DB[keys[i]]
      if type(a) == "table" and tonumber(a[4]) then
        a[4] = math.max(0, a[4] - 40)
      end
    end
  end
  U.ReI18n()
  if U.ApplyMarks then U.ApplyMarks() end
  -- 配置按钮已锁死在小地图右下：把老存档里的坐标/角度全部清掉（账号、角色、镜像三处）
  if (DB.btnVer or 0) < 3 then
    DB.btnVer = 3
    DB.cfgAnchor = nil
    DB.cfgAngle = nil
    if type(AIbarDBC) == "table" then
      AIbarDBC.cfgAnchor = nil
      AIbarDBC.cfgAngle = nil
    end
    local mt = mirrorTable()
    if type(mt) == "table" then
      mt.cfgAnchor = nil
      mt.cfgAngle = nil
    end
    -- 这里不落盘：登录时还没跑“首次安装”判断，提前 Save 会把 seq 抬起来误判成老用户
  end
  -- 面板在 Restore 之前就建好了，这里按真实存档重新套缩放和数值
  if AIbarConfig and DB.cfgScale then
    AIbarConfig:SetScale(DB.cfgScale)
  end
  if U.cfgScaleLabel then
    U.cfgScaleLabel:SetText(string.format("%.1f", DB.cfgScale or 1))
  end
  -- 全新安装（一份存档都没有）才套用默认布局；老用户保留自己的摆位
  if (DB.seq or 0) == 0 and not DB.anchor and not DB.resAnchor and not DB.bar2Anchor then
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
  -- 登录不再往聊天框打任何提示（用户要求干净）

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
  U.ApplyChatBar()
  U.KeepThumbstick()   -- 先挡掉轮盘的 Hide，之后只靠背包事件兜底
  U.UpdateTargetClass()
  if U.ScanBagItemTex then U.ScanBagItemTex() end
  U.Refresh()
  -- 动作条保持在 MEDIUM：比各种设置/对话框低，打开选项时不会被动作条压住
  do
    local names = { "AIbarPanel", "AIbarClass", "AIbarExtra2", "AIbarExtra3", "AIbarExtra4",
                    "AIbarUtiljump", "AIbarUtiltarget", "AIbarRL" }
    local i
    for i = 1, #names do
      local fr = G(names[i])
      if fr and fr.SetFrameStrata then pcall(fr.SetFrameStrata, fr, "MEDIUM") end
    end
  end
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
  if event == "PLAYER_TARGET_CHANGED" and U.UpdateTargetClass then U.UpdateTargetClass() end
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
-- 以前为了被背包盖住用 LOW；背包整合已删，这个面板要能压在其它窗口上面
f:SetFrameStrata("DIALOG")
if f.SetFrameLevel then f:SetFrameLevel(120) end
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
title:SetText("|cffFFD200" .. L("选择一个技能 / 宏 / 物品") .. "|r")
U.regI18n(function() title:SetText("|cffFFD200" .. L("选择一个技能 / 宏 / 物品") .. "|r") end)

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
  if state.mode ~= m then state.page = 1 end
  state.mode = m
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
  b.cnt = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.cnt:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  b.cnt:SetTextColor(1, 1, 1)
  if b.cnt.SetFont then
    local fn = b.cnt:GetFont()
    if fn then b.cnt:SetFont(fn, 12, "OUTLINE") end
  end

  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.hl:SetAllPoints(b)
  b.hl:SetTexture(1, 1, 1, 0.2)
  b:SetScript("OnClick", function()
    if this.entry and this.entry.assign then
      this.entry.assign()
      U.Refresh()
      if U.RefreshExtra then U.RefreshExtra() end
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
  if U.RefreshExtra then U.RefreshExtra() end
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
        local bt = (type(BOOKTYPE_SPELL) == "string") and BOOKTYPE_SPELL or "spell"
        local okn, sname = pcall(GetSpellName, id, bt)
        if not okn or type(sname) ~= "string" or sname == "" then
          okn, sname = pcall(GetSpellName, id)
        end
        if okn and type(sname) == "string" and sname ~= "" then
          local ic = nil
          if type(GetSpellTexture) == "function" then
            local okt, v = pcall(GetSpellTexture, id, bt)
            if okt and type(v) == "string" and v ~= "" then ic = v end
            if not ic then
              okt, v = pcall(GetSpellTexture, id)
              if okt and type(v) == "string" and v ~= "" then ic = v end
            end
          end
          ic = ic or tex
          local nmLocal = sname
          out[#out + 1] = {
            icon = ic,
            label = nmLocal,
            assign = function()
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

local macroCache, macroCacheAt = nil, 0
local function collectMacros()
  -- 宏很少变：30 秒内复用上一次的结果，避免每次切页签扫 72×3 次
  if macroCache and GetTime() - macroCacheAt < 30 then return macroCache end
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
  macroCache, macroCacheAt = out, GetTime()
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
        local nm = "物品"
        if type(link) == "string" then
          local n2 = string.match(link, "%[(.-)%]")
          if n2 and n2 ~= "" then nm = n2 end
        end
        local cnt = tonumber(count) or 1
        local b2, s2 = bag, s
        out[#out + 1] = {
          icon = tex,
          label = nm .. " x" .. cnt,
          count = cnt,
          assign = function()
            if type(PickupContainerItem) == "function" then pcall(PickupContainerItem, b2, s2) end
            if type(PlaceAction) == "function" then pcall(PlaceAction, state.slot) end
            if type(ClearCursor) == "function" then pcall(ClearCursor) end
            -- 放上去时就知道物品 id，顺手记住：以后背包空了也能判定“用光”
            local iid = type(link) == "string" and tonumber(string.match(link, "item:(%d+)"))
            if iid and tex then
              local k2 = state.slot .. "|" .. tex
              U.slotItem[k2] = iid
              DB.slotItem = DB.slotItem or {}
              DB.slotItem[k2] = iid
            end
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
      cell.cnt:SetText(e.count and tostring(e.count) or "")
      cell:Show()
    else
      cell.entry = nil
      cell.icon:SetTexture(nil)
      cell.cnt:SetText("")
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
title:SetText("|cffd8c081" .. L("AiBar 配置") .. "|r |cff888888v1.0.5|r")

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
  local key = text
  text = L(text)
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
  U.regI18n(function() b.lbl:SetText(L(key)) end)
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
-- 开关按钮统一排版：名字靠左、开关字样靠右，纵向对齐
-- 开关状态不再用「开/关」文字（手机上字挤在名字右边很难看），
-- 改成整块按钮的边框：开着是绿框，关掉是原来的灰框。
local TOGGLE_ON = { 0.25, 0.95, 0.45 }
local TOGGLE_OFF = { 0.4, 0.37, 0.33 }

local function setToggle(b, name, on)
  if not b then return end
  b.lbl:ClearAllPoints()
  b.lbl:SetPoint("CENTER", b, "CENTER", 0, 0)
  if b.lbl.SetJustifyH then b.lbl:SetJustifyH("CENTER") end
  b.lbl:SetText(L(name))
  local c = on and TOGGLE_ON or TOGGLE_OFF
  b:SetBackdropBorderColor(c[1], c[2], c[3], 1)
end

local function syn()
  local i
  for i = 1, #widgets do widgets[i]() end
  -- 配置面板每次改完立刻存档并落盘：手机端可能来不及等到 5 秒的定时保存
  if U.Save then U.Save(true) end
end
-- 面板缩放：右上角 - / +（记在 cfgScale，下次打开沿用）
local function applyPanelScale(v)
  v = math.max(0.7, math.min(2.0, v))
  v = math.floor(v * 10 + 0.5) / 10   -- 只保留一位小数，避免累加误差
  DB.cfgScale = v
  local cur = DB.cfgScale or 1.15
  local ds = v - cur
  -- 面板锚点通常是 CENTER：按尺寸差把锚点挪一半，视觉上左上角不动
  local pt, rel, rp, x, y = p:GetPoint(1)
  if pt ~= "CENTER" then pt, rel, rp, x, y = "CENTER", nil, UIParent, 0, 0 end
  x, y = x or 0, y or 0
  p:SetScale(v)
  if ds ~= 0 and pt == "CENTER" then
    local W2, H2 = p:GetWidth() or 0, p:GetHeight() or 0
    p:ClearAllPoints()
    p:SetPoint("CENTER", rp or UIParent, "CENTER", x + W2 * ds / 2, y - H2 * ds / 2)
  end
  U.Save(true)
end
if DB.cfgScale then
  p:SetScale(DB.cfgScale)
else
  -- 老存档里没有这个值：按默认缩放写回去，重载后就不会跳
  DB.cfgScale = math.min(1.4, (DEV_S or 1) * (U.TouchMode and 1.15 or 1.0))
end
local scLabel
U.cfgScaleLabel = nil
local function updateScaleLabel()
  if scLabel then
    scLabel:SetText(string.format("%.1f", DB.cfgScale or 1))
  end
end
do
  scLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  U.cfgScaleLabel = scLabel
  scLabel:SetPoint("RIGHT", p, "TOPRIGHT", -78, -19)
  scLabel:SetText(string.format("%.1f", DB.cfgScale or 1))
  local bSM = mkBtn("-", 0, 0, 28, 26, function()
    applyPanelScale((DB.cfgScale or 1.15) - 0.1)
    updateScaleLabel()
  end, true)
  bSM:ClearAllPoints(); bSM:SetPoint("TOPRIGHT", p, "TOPRIGHT", -42, -6)
  local bSP = mkBtn("+", 0, 0, 28, 26, function()
    applyPanelScale((DB.cfgScale or 1.15) + 0.1)
    updateScaleLabel()
  end, true)
  bSP:ClearAllPoints(); bSP:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -6)
end

local function touch()
  U.Geo = true
  U.modDirty = true
  syn()
  U.ApplyChatBar()
  U.ApplyNative()
  U.Refresh()
end

local function section(text, y)
  local fs = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("TOPLEFT", p, "TOPLEFT", PADX, y - 8)
  fs:SetText("|cffb99a55" .. L(text) .. "|r")
  U.regI18n(function() fs:SetText("|cffb99a55" .. L(text) .. "|r") end)
  reg(fs)
  return fs
end

local function stepper(y, label, key, min, max, step, suffix)
  local lb = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lb:SetPoint("TOPLEFT", p, "TOPLEFT", PADX, y - 20)
  lb:SetText(L(label))
  U.regI18n(function() lb:SetText(L(label)) end)
  reg(lb)
  local val = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  val:SetPoint("TOPLEFT", p, "TOPLEFT", 186, y - 20)
  reg(val)
  local bM = mkBtn("-", 246, y - 8, 40, 30, function()
    DB[key] = math.max(min, DB[key] - step); touch()
  end)
  local bP = mkBtn("+", 290, y - 8, 40, 30, function()
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
local bPet = mkBtn("宠物条", 234, y - 8, 104, 30, function() DB.petBar = not DB.petBar; touch() end)
y = y - ROW
local bLockSkill = mkBtn("锁定技能", 14, y - 8, 104, 30, function()
  DB.skillLock = not DB.skillLock
  touch()
end)
widgets[#widgets + 1] = function()
  setToggle(bLockSkill, "锁定技能", DB.skillLock)
end
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
      bt.lbl:SetText("|cffffe08a▶ " .. L("第" .. i2 .. "条") .. "|r")
    else
      bt.isSel = false
      bt:SetBackdropColor(0.14, 0.13, 0.12, 0.95)
      bt:SetBackdropBorderColor(0.4, 0.37, 0.33, 1)
      bt.lbl:SetText(L("第" .. i2 .. "条"))
    end
  end
end

local function stepperCfg(yy, label, field, min, max, step)
  label = L(label)
  local lb = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lb:SetPoint("TOPLEFT", p, "TOPLEFT", PADX, yy - 20)
  lb:SetText(label)
  U.regI18n(function() lb:SetText(L(label)) end)
  reg(lb)
  local val = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  val:SetPoint("TOPLEFT", p, "TOPLEFT", 186, yy - 20)
  reg(val)
  mkBtn("-", 246, yy - 8, 40, 30, function()
    local c = U.BarCfg(DB.curBar or 1)
    c[field] = math.max(min, c[field] - step)
    touch()
  end)
  mkBtn("+", 290, yy - 8, 40, 30, function()
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
  setToggle(bMove, "移动", DB.move)
  setToggle(bSkin, "背板", DB.skin, "显", "隐")
  setToggle(bPet, "宠物条", DB.petBar)
  setToggle(bBar2, "第2条", DB.bar2)
  setToggle(bBar3, "第3条", DB.bar3)
  setToggle(bBar4, "第4条", DB.bar4)
end

-- ===== 第 2 页:资源 =====
curTab = 2
y = TOP

local bRBg = mkBtn("背景", 14, y - 8, 104, 30, function() DB.resBg = not DB.resBg; touch() end)
local bRCb = mkBtn("仅战斗", 124, y - 8, 104, 30, function() DB.resCombatOnly = not DB.resCombatOnly; touch() end)
local bLock = mkBtn("资源锁定", 234, y - 8, 104, 30, function()
  DB.resLocked = not (DB.resLocked ~= false)
  U.ApplyRes()
  touch()
end)
widgets[#widgets + 1] = function()
  setToggle(bLock, "锁定", DB.resLocked ~= false)
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
  mkBtn("上", 118, y - 8, 30, 30, function()
    U.FixResData()
    local o = DB.resOrder
    local i
    for i = 2, #o do
      if o[i] == m.k then o[i], o[i - 1] = o[i - 1], o[i]; touch(); return end
    end
  end)
  mkBtn("下", 152, y - 8, 30, 30, function()
    U.FixResData()
    local o = DB.resOrder
    local i
    for i = 1, #o - 1 do
      if o[i] == m.k then o[i], o[i + 1] = o[i + 1], o[i]; touch(); return end
    end
  end)

  do
    local hTxt = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hTxt:SetPoint("TOPLEFT", p, "TOPLEFT", 196, y - 20)
    reg(hTxt)
    widgets[#widgets + 1] = function()
      hTxt:SetText(tostring((DB.resH and DB.resH[m.k]) or 12))
    end
    mkBtn("-", 236, y - 8, 36, 30, function()
      DB.resH = DB.resH or {}
      DB.resH[m.k] = math.max(4, (DB.resH[m.k] or 12) - 2); touch()
    end)
    mkBtn("+", 276, y - 8, 36, 30, function()
      DB.resH = DB.resH or {}
      DB.resH[m.k] = math.min(40, (DB.resH[m.k] or 12) + 2); touch()
    end)
  end

  -- 每条后面一个“文”开关：控制该条是否显示数字
  DB.resTxt = DB.resTxt or {}
  local bTxt = mkBtn("文", 316, y - 8, 34, 30, function()
    DB.resTxt[m.k] = not DB.resTxt[m.k]
    touch()
  end)
  widgets[#widgets + 1] = function()
    if DB.resTxt[m.k] then
      bTxt:SetBackdropColor(0.55, 0.44, 0.18, 1)
      bTxt:SetBackdropBorderColor(1, 0.86, 0.35, 1)
    else
      bTxt:SetBackdropColor(0.16, 0.15, 0.14, 0.95)
      bTxt:SetBackdropBorderColor(0.4, 0.37, 0.33, 1)
    end
  end

  widgets[#widgets + 1] = function()
    setToggle(bT, m.label, DB[m.on])
  end

  y = y - ROW
end

widgets[#widgets + 1] = function()
  setToggle(bRCb, "仅战斗", DB.resCombatOnly)
  setToggle(bRBg, "背景", DB.resBg, "显", "隐")
end

local PAGE2_H = -y + 70

-- ===== 第 5 页:其他 =====
curTab = 5
y = TOP



section("微调", y); y = y - SGAP

;(function()
y = y - 8
local tcl = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
tcl:SetPoint("TOPLEFT", p, "TOPLEFT", PADX, y - 6)
tcl:SetText(L("微调（选对象，再用方向键）"))
U.regI18n(function() tcl:SetText(L("微调（选对象，再用方向键）")) end)
reg(tcl)
y = y - 22

local microButtons = {}
local microVal
local function microRefresh()
  local t = U.MicroTarget()
  local i
  for i = 1, #microButtons do
    local b = microButtons[i]
    if b.key == t then
      b.btn:SetBackdropColor(0.55, 0.44, 0.18, 1)
      b.btn:SetBackdropBorderColor(1, 0.86, 0.35, 1)
    else
      b.btn:SetBackdropColor(0.18, 0.16, 0.12, 0.92)
      b.btn:SetBackdropBorderColor(0.5, 0.42, 0.28, 1)
    end
  end
  if microVal then
    if t == "tc" then
      microVal:SetText(L("职业标") .. "  X " .. tostring(DB.tcX or 0) .. "  Y " .. tostring(DB.tcY or 0))
    elseif t == "chat" then
      microVal:SetText(L("聊天按钮") .. "  X " .. tostring(DB.chatX or 0) .. "  Y " .. tostring(DB.chatY or 0))
    elseif t == "jump" then
      microVal:SetText(L("跳按钮") .. "  " .. L("用方向键移动"))
    else
      microVal:SetText(L("目标按钮") .. "  " .. L("用方向键移动"))
    end
  end
end

local mTargets = { { "tc", "职业标" }, { "chat", "聊天按钮" }, { "mark", "标记" } }
local mi2
for mi2 = 1, #mTargets do
  local mt = mTargets[mi2]
  local mb = mkBtn(mt[2], 14 + (mi2 - 1) * 106, y - 4, 98, 28, function()
    U.micro = mt[1]
    microRefresh()
  end)
  microButtons[#microButtons + 1] = { key = mt[1], btn = mb }
end
y = y - 32

local STEP = 5
mkBtn("左", 14, y - 4, 66, 28, function() U.MicroNudge(-STEP, 0); microRefresh(); touch() end)
mkBtn("右", 84, y - 4, 66, 28, function() U.MicroNudge(STEP, 0); microRefresh(); touch() end)
mkBtn("上", 154, y - 4, 66, 28, function() U.MicroNudge(0, STEP); microRefresh(); touch() end)
mkBtn("下", 224, y - 4, 66, 28, function() U.MicroNudge(0, -STEP); microRefresh(); touch() end)
y = y - 32

local function microScale(plus)
  local t = U.MicroTarget()
  if t == "mark" then
    DB.markScale = math.min(2.4, math.max(0.6, (DB.markScale or 1) + (plus and 0.1 or -0.1)))
    if U.ApplyMarks then U.ApplyMarks() end
  elseif t == "chat" then
    DB.chatScale = math.min(2.2, math.max(0.6, (DB.chatScale or 1) + (plus and 0.1 or -0.1)))
    U.ApplyChatBar()
  else
    -- 以默认 26 为基准：往下 2 级、往上 5 级（每级 2px）
    local base = 26
    DB.tcSize = math.min(base + 10, math.max(base - 4, (DB.tcSize or base) + (plus and 2 or -2)))
    U.UpdateTargetClass()
  end
  microRefresh(); touch()
end
local function microShow()
  local t = U.MicroTarget()
  if t == "mark" then
    DB.markOn = not (DB.markOn ~= false)
    if U.ApplyMarks then U.ApplyMarks() end
  elseif t == "chat" then
    DB.chatBar = not (DB.chatBar ~= false)
  else
    DB.targetClass = not DB.targetClass
    U.UpdateTargetClass()
  end
  microRefresh(); touch()
end
mkBtn("缩小", 14, y - 4, 90, 28, function() microScale(false) end)
mkBtn("放大", 108, y - 4, 90, 28, function() microScale(true) end)
mkBtn("显示", 202, y - 4, 90, 28, function() microShow() end)
y = y - 34


microVal = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
microVal:SetPoint("TOPLEFT", p, "TOPLEFT", PADX, y - 4)
reg(microVal)
widgets[#widgets + 1] = microRefresh
microRefresh()
y = y - 30


end)()

-- 配置快照

-- 语言放最底下
section("语言", y); y = y - SGAP
;(function()
  local opts = { { "zh", "ZH" }, { "en", "EN" } }
  local btns = {}
  local k
  for k = 1, #opts do
    local code, name = opts[k][1], opts[k][2]
    btns[k] = { code = code, b = mkBtn(name, 14 + (k - 1) * 86, y - 8, 80, 28, function()
      DB.lang = code
      U.Save(true)
      U.LangReloadTip(code)
    end) }
  end
  widgets[#widgets + 1] = function()
    local cur = U.CurLang()
    local m
    for m = 1, #btns do
      local e = btns[m]
      if e.code == cur then
        e.b:SetBackdropColor(0.55, 0.44, 0.18, 1)
        e.b:SetBackdropBorderColor(1, 0.86, 0.35, 1)
      else
        e.b:SetBackdropColor(0.14, 0.13, 0.12, 0.95)
        e.b:SetBackdropBorderColor(0.4, 0.37, 0.33, 1)
      end
    end
  end
end)()
y = y - ROW
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
  setToggle(bRev, "反转", DB.castReverse)
  setToggle(bTRev, "目标反转", DB.castTReverse)
  setToggle(bPrev, "预览", U.previewSelf, "中", "")
  setToggle(bLock, "锁定", DB.castLock)
  setToggle(bPrev2, "预览目标", U.previewTarget, "中", "")
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
    if key == "classBar" then
      U.classApplied = nil
      if U.ApplyClassBar then pcall(U.ApplyClassBar) end
    end
    if key == "cfgBtn" then U.ApplyCfgBtn() end
    U.Geo = true
    U.ApplyModules()
    touch()
  end)
  widgets[#widgets + 1] = function()
    setToggle(b, label, DB[key] ~= false)
  end
  return b
end

-- 四列两行，网格和下面「微调」的四列（14/98/182/266，宽 76）对齐，
-- 8 个开关刚好铺满，不再留中间空格
local MW = 76
local function modCell(label, key, col)
  return modBtn(label, key, 14 + (col - 1) * 84, MW)
end
modCell("动作条", "modBar", 1)
modCell("资源条", "modRes", 2)
modCell("施法条", "modCast", 3)
modCell("辅助按钮", "modUtil", 4)
y = y - ROW
modCell("职业栏", "classBar", 1)
modCell("配置按钮", "cfgBtn", 2)
modCell("聊天按钮", "chatBar", 3)
if DB.rlButton == nil then DB.rlButton = false end
modCell("RL 按钮", "rlButton", 4)
y = y - ROW

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
  { "自己条", "AIbarCastSelf", "castSelfAnchor" },
  { "目标条", "AIbarCastTarget", "castTargetAnchor" },
}


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

mkBtn("←", 14, y - 8, 64, 30, function() U.DoNudge(-5, 0) end)
mkBtn("→", 84, y - 8, 64, 30, function() U.DoNudge(5, 0) end)
mkBtn("↑", 154, y - 8, 64, 30, function() U.DoNudge(0, 5) end)
mkBtn("↓", 224, y - 8, 64, 30, function() U.DoNudge(0, -5) end)
y = y - ROW

section("辅助", y); y = y - SGAP
-- 跳跃 / 目标 平分整行；各自的大小按钮排在它们正下方
local bJump = mkBtn("跳跃", 14, y - 8, 162, 30, function() DB.jumpOn = not DB.jumpOn; touch() end)
local bTgt = mkBtn("目标", 180, y - 8, 162, 30, function() DB.targetOn = not DB.targetOn; touch() end)
y = y - ROW
mkBtn("跳小", 14, y - 6, 78, 28, function() DB.jumpScale = math.max(0.6, (DB.jumpScale or 1) - 0.1); touch() end)
mkBtn("跳大", 96, y - 6, 78, 28, function() DB.jumpScale = math.min(2.4, (DB.jumpScale or 1) + 0.1); touch() end)
mkBtn("目小", 180, y - 6, 78, 28, function() DB.targetScale = math.max(0.6, (DB.targetScale or 1) - 0.1); touch() end)
mkBtn("目大", 262, y - 6, 78, 28, function() DB.targetScale = math.min(2.4, (DB.targetScale or 1) + 0.1); touch() end)
y = y - ROW
widgets[#widgets + 1] = function()
  setToggle(bJump, "跳跃", DB.jumpOn)
  setToggle(bTgt, "目标", DB.targetOn)
end

local PAGE5_H = -y + 70

-- ===== 选项卡(无关闭按钮) =====
local TABS = { "动作条", "资源条", "施法条", "模块", "其他" }
local TAB_H = { PAGE1_H, PAGE2_H, PAGE4_H, PAGE5_H, PAGE3_H }

local function switchTab(i)
  -- 预览不随切页关闭，只能手动关
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
local function doResetLayout()
  -- 重置 = 回到默认布局（和首次安装一致）：动作条 1 底部居中、2/3/4 右侧竖排、小按钮排中线
  DB.petAnchor = nil
  DB.castSelfAnchor = nil
  DB.castTargetAnchor = nil
  U.ApplyDefaultLayout()
  U.Geo = true
  U.cfgOffX, U.cfgOffY, U.cfgPlaced = nil, nil, nil
  U.ApplyCfgBtn()
  U.ApplyUtil()
  U.ApplyClassBar()
  U.ApplyPet()
  U.ApplyCastAnchors()   -- 施法条也回到默认位置
  U.Refresh()
  -- 面板大小不属于“布局”，重置时不动它，避免点一次重置尺寸就变一下
  syn()
end

local resetArm = 0
local bReset
bReset = mkBtn("重置位置", 14, 0, 150, 34, function()
  -- 两步确认：第一次点只“上膛”，3 秒内再点一次才真的重置
  if resetArm == 0 or GetTime() - resetArm > 3 then
    resetArm = GetTime()
    bReset.lbl:SetText("|cffffcc55再点一次确认|r")
    return
  end
  resetArm = 0
  bReset.lbl:SetText("重置位置")
  doResetLayout()
end, true)
bReset:ClearAllPoints()
bReset:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 14, 12)
-- 3 秒没点第二次就把按钮文字改回去
p:SetScript("OnUpdate", function()
  if resetArm ~= 0 and GetTime() - resetArm > 3 then
    resetArm = 0
    bReset.lbl:SetText("重置位置")
  end
end)

local bClose = mkBtn("关闭", 0, 0, 150, 34, function() p:Hide() end, true)
bClose:ClearAllPoints()
bClose:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -14, 12)

switchTab(1)
p:SetScript("OnShow", function()
  syn()
  switchTab(curTab or 1)
end)
p:SetScript("OnHide", function()
  -- 预览保持开着（手动关）
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
