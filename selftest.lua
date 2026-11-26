-- AIbar 自检脚本（离线，不需要游戏客户端）
-- 用法：lua5.1 selftest.lua
-- 覆盖：加载/登录、物品数量与用光变暗、标记权限、倒计时、双语、技能锁定、命令

local okCount, failCount = 0, 0
local function check(cond, name)
  if cond then
    okCount = okCount + 1
    print("  ok   " .. name)
  else
    failCount = failCount + 1
    print("  FAIL " .. name)
  end
end

-- 加载测试桩与插件
local W = dofile("/root/workspace/aibar/stub.lua")
local okLoad, errLoad = pcall(function()
  assert(loadfile("/root/workspace/aibar/AIbar.lua"))()
end)
check(okLoad, "插件加载" .. (okLoad and "" or ("：" .. tostring(errLoad))))

local U = _G.AIbar
check(U ~= nil, "全局 AIbar 存在")

local okLogin = pcall(function() W:event("PLAYER_LOGIN") end)
check(okLogin, "登录事件")
for i = 1, 10 do W:tick(0.1) end

-- 1) 物品数量 / 用光变暗
U.itemByTex = {}
U.slotItem = { ["1|T"] = 104 }
U.texKnown = { T = true }
U.texInBag = {}
check(U.ActionItemId(1, "T") == 104, "用光后仍记得物品 ID")
check(U.ItemGone(1, "T", 0) == true, "用光后判定为已用完")
check(U.ActionItemId(2, "Unknown") == nil, "非物品格不误判")

-- 2) 标记权限
_G.UnitExists = function() return 1 end
_G.GetRaidTargetIndex = function() return 0 end
local calls = {}
_G.SetRaidTarget = function(unit, i) calls[#calls + 1] = i end
_G.GetNumPartyMembers = function() return 0 end
_G.GetNumRaidMembers = function() return 0 end
_G.IsPartyLeader = function() return nil end
_G.IsRaidLeader = function() return nil end
_G.IsRaidOfficer = function() return nil end
U.ApplyMarks()
calls = {}
W:clickButton(U.markBtns[1], "LeftButton")
check(#calls == 1, "单人可标记")
_G.GetNumPartyMembers = function() return 1 end
calls = {}
W:clickButton(U.markBtns[1], "LeftButton")
check(#calls == 0, "小队队员不能标记")
_G.IsPartyLeader = function() return 1 end
calls = {}
W:clickButton(U.markBtns[1], "LeftButton")
check(#calls == 1, "小队队长可标记")
_G.GetNumRaidMembers = function() return 10 end
_G.IsPartyLeader = function() return 1 end
_G.IsRaidLeader = function() return nil end
_G.IsRaidOfficer = function() return nil end
calls = {}
W:clickButton(U.markBtns[1], "LeftButton")
check(#calls == 0, "团队里小队长不能标记")
_G.IsRaidOfficer = function() return 1 end
calls = {}
W:clickButton(U.markBtns[1], "LeftButton")
check(#calls == 1, "团队助理可标记")

-- 3) 倒计时
_G.GetNumRaidMembers = function() return 0 end
_G.GetNumPartyMembers = function() return 0 end
U.PullStart(5)
check(U.pullF:IsShown(), "倒计时开始显示")
for i = 1, 3 do W:tick(1.0) end
check(U.pullLast == 2, "倒计时递减（剩 2 秒）")
for i = 1, 3 do W:tick(1.0) end
check(U.pullLast == 0, "倒计时到点")
for i = 1, 2 do W:tick(1.0) end
check(not U.pullF:IsShown(), "倒计时结束自动隐藏")

-- 4) 双语
_G.AIbarDB.lang = "en"
check(U.L("技能") == "Spells", "英文：技能 → Spells")
_G.AIbarDB.lang = "zh"
check(U.L("技能") == "技能", "中文：技能 → 技能")
U.ReI18n()

-- 5) 技能锁定
local b1 = U.buttons[1]
_G.AIbarDB.skillLock = true
_G.AIbarPicker:Hide()
U.TouchMode = false
W:clickButton(b1, "RightButton")
check(not _G.AIbarPicker:IsShown(), "锁定后非空格右键不换技能")
_G.AIbarDB.skillLock = false
W:clickButton(b1, "RightButton")
check(_G.AIbarPicker:IsShown(), "解锁后右键可换技能")

-- 6) 命令
local S = _G.SlashCmdList["EVALBARCMD"]
for _, c in ipairs({ "help", "skin", "move", "pc", "chatbar", "lock", "lang", "macro" }) do
  local okC, errC = pcall(S, c)
  check(okC, "命令 /abc " .. c .. (okC and "" or ("：" .. tostring(errC))))
end

-- 7) 面板能开、能切页
local okPanel = pcall(function()
  _G.SlashCmdList["EVALBARCMD"]("")
end)
check(okPanel, "配置面板打开")

print(string.format("\n通过 %d 项，失败 %d 项", okCount, failCount))
if failCount > 0 then os.exit(1) end
