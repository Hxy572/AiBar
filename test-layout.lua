local W = dofile("/root/workspace/stub.lua")
assert(loadfile("/root/workspace/AIbar.lua"))()
local U = _G.AIbar
local DB = _G.AIbarDB
W:event("PLAYER_LOGIN")

DB.bar2, DB.bar3, DB.bar4 = true, true, true
DB.anchor = { "BOTTOM", "BOTTOM", 0, 10 }
DB.bar2Anchor = { "BOTTOMRIGHT", "BOTTOMRIGHT", -100, 200 }
DB.bar3Anchor = { "BOTTOMRIGHT", "BOTTOMRIGHT", -100, 350 }
DB.bar4Anchor = { "BOTTOMRIGHT", "BOTTOMRIGHT", -100, 500 }
U.ApplyExtra()
U.Refresh()

local function pt(fr)
  local a,b,c,d,e = fr:GetPoint(1)
  return tostring(a)..","..tostring(b)..","..tostring(d)..","..tostring(e)
end
print("B2", pt(U.extraBars[2]))
print("B3", pt(U.extraBars[3]))
print("B4", pt(U.extraBars[4]))

-- 主条换位置，副条不应变化
DB.anchor = { "BOTTOMLEFT", "BOTTOMLEFT", 40, 60 }
U.Refresh()
U.ApplyExtra()
print("after main move B2", pt(U.extraBars[2]))
print("main", pt(U.panel))

-- 清掉副条锚点，看默认值
DB.bar2Anchor, DB.bar3Anchor, DB.bar4Anchor = nil, nil, nil
U.extraBars[2].__anchSig = nil
U.extraBars[3].__anchSig = nil
U.extraBars[4].__anchSig = nil
U.ApplyExtra()
print("default B2", pt(U.extraBars[2]))
print("default B3", pt(U.extraBars[3]))
print("default B4", pt(U.extraBars[4]))
print("SavedAnchors", tostring(DB.bar2Anchor))
