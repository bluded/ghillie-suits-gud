local T = 0
function time_global() return T end
AC_ID = 0
function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
function IsMoveState() return false end
function IsStalker() return true end
function printf() end
function log(m) print(m) end
local cbs = {}
function RegisterScriptCallback(n,f) cbs[n]=f end
local outfits = { stalker_outfit={kind="o_medium", player_hud_section="actor_hud_stalker"} }
ini_sys = {
  section_exist=function(_,s) return s=="actor_hud_ghillie" end,
  line_count=function() return 0 end, r_line_ex=function() return false end,
  r_string_ex=function(_,s,k) return outfits[s] and outfits[s][k] end,
  r_float_ex=function(_,s,k) return outfits[s] and outfits[s][k] end,
}
stealth_mcm = { get_config=function() return 1 end }
local mcm_calls, mcm = 0, {}
ui_mcm = { get=function(path) mcm_calls = mcm_calls + 1; return mcm[path] end }
local hud_log = {}
local hud = { set_hands=function(_,s) hud_log[#hud_log+1]="set:"..s end, reset_hands=function() hud_log[#hud_log+1]="reset" end }
function get_player_hud() return hud end
local belt = {}
local function obj(sec,id) return { section=function() return sec end, id=function() return id end, alive=function() return true end, name=function() return "npc" end } end
db = { actor = {
  iterate_belt=function(self,f) for _,o in ipairs(belt) do f(self,o) end end,
  item_in_slot=function(_,i) return i==7 and obj("stalker_outfit",6) or nil end,
  get_total_weight=function() return 40 end, id=function() return 0 end } }
local upstream = 1 -- what the detection script itself returns
visual_memory_manager = { get_visible_value=function() return upstream end }
assert(loadstring(io.open("gamedata/scripts/ghillie_gud.script"):read("*a")))()
on_game_start()
local function step(ms) T=T+ms; cbs.actor_on_update() end
local function expect(label, expected)
	local got = table.concat(hud_log," | ")
	hud_log={}
	print(label, got == "" and "(nothing)" or got)
	assert_eq(got, expected, label)
end
local npc = obj("x",1)
local STILL, WALK = 0, 1 -- WALK is above STILL_SPEED; IsMoveState is always false here
local function see(vel) return visual_memory_manager.get_visible_value(npc, db.actor, 0,0,0,0, vel or STILL, 100, 50, 0) end
local function check(label, vel, expected)
	local got = see(vel)
	print(label, got)
	assert_close(got, expected, label)
end

print("-- no Wearable Devices: load with wrap on")
belt={obj("ghillie_wrap",9)}
T=1000; cbs.actor_on_first_update(); expect("first update:", "set:actor_hud_ghillie")
step(600); step(1000); expect("load-window re-applies:", "set:actor_hud_ghillie | set:actor_hud_ghillie")
step(5000); belt={}; cbs.actor_item_to_ruck(); step(16); expect("wrap off:", "set:actor_hud_stalker | reset")
belt={obj("ghillie_wrap",9)}; cbs.actor_item_to_belt(); step(16); expect("wrap on later:", "set:actor_hud_ghillie")
step(600); step(1000); expect("later re-applies (none outside load window):", "")

print("-- MCM cache")
step(7000) -- install hook
mcm_calls = 0
for i=1,1000 do see() end
print("MCM reads during 1000 vision checks:", mcm_calls)
assert_eq(mcm_calls, 0, "MCM reads during vision checks")
-- 50 m, medium armor, 40 kg: both armor terms floor at 1, only the camo counts.
check("default, still:", STILL, 0.05)
check("default, walk:", WALK, 1 - 0.85 * 0.4)

-- Moving strength 0: walking loses the camo, standing still keeps strength_still.
mcm["ghillie_gud/strength"] = 0; step(1100)
check("strength=0, walk:", WALK, 1)
check("strength=0, still:", STILL, 0.05)
mcm["ghillie_gud/strength"] = nil

-- strength_still 0: standing still loses the camo, walking keeps strength.
mcm["ghillie_gud/strength_still"] = 0; step(1100)
check("strength_still=0, still:", STILL, 1)
check("strength_still=0, walk:", WALK, 1 - 0.85 * 0.4)
mcm["ghillie_gud/strength_still"] = nil; step(1100)
check("restored, still:", STILL, 0.05)

upstream = 0.7
mcm["ghillie_gud/enabled"] = false; step(1100)
check("enabled=false returns upstream:", STILL, 0.7)
mcm["ghillie_gud/enabled"] = nil; step(1100)
check("enabled again:", STILL, 0.7 * 0.05)
upstream = 1
ui_mcm = nil; step(1100)
check("no MCM, defaults still:", STILL, 0.05)
check("no MCM, defaults walk:", WALK, 1 - 0.85 * 0.4)
