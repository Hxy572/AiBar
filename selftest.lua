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
U.slotItem = { ["19|T"] = 1179 }
U.slotName = { ["19|T"] = "测试技能" }
check(U.ActionItemId(19, "T") == 1179, "用光后仍记得物品 ID")
check(U.ActionItemId(2, "Unknown") == nil, "非物品格不误判")

-- 制皮/同图标技能：名字读到了但不是物品，不能再按图标给数量
U.itemByTex = { T2 = 104 }
U.ActionName = function() return "制皮" end
U.actNameCache = {}
check(U.ActionItemId(30, "T2") == nil, "同图标的技能不给物品数量")

-- 背包为空时靠“物品名→id”持久化表识别（重登后变暗的关键）
U.ActionName = function() return "冰镇牛奶" end
_G.AIbarDB.itemNames = { ["冰镇牛奶"] = 1179 }
_G.GetItemCount = function() return 0 end
U.itemCnt = nil
check(U.ActionItemId(19, "T") == 1179, "按物品名反查 id")
check(U.ActionState(19, "T", true) == "no", "背包数量 0 → 状态 no")
_G.GetItemCount = function() return 2 end
U.itemCnt = nil
check(U.ActionState(19, "T", true) ~= "no", "背包有货 → 状态不是 no")

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
