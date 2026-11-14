local T = 100000
function time_global() return T end
AC_ID = 0
function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
local move = {}
function IsMoveState(s) return move[s] or false end
function IsStalker() return true end
function printf() end
function log(m) end
local cbs = {}
function RegisterScriptCallback(n,f) cbs[n]=f end
ini_sys = { section_exist=function() return false end, line_count=function() return 0 end, r_line_ex=function() return false end,
  r_string_ex=function(_,s,k) return k=="kind" and "o_light" or nil end, r_float_ex=function() return nil end }
stealth_mcm = { get_config=function() return 1 end }
redone_foliage_detection = { get_factor=function() return 1 end }
local function obj(sec,id) return { section=function() return sec end, id=function() return id end, alive=function() return true end, name=function() return "n" end } end
db = { actor = { iterate_belt=function(self,f) f(self,obj("ghillie_wrap",9)) end, item_in_slot=function(_,i) return i==7 and obj("o",6) or nil end,
  get_total_weight=function() return 0 end, id=function() return 0 end } }
function get_player_hud() return nil end
visual_memory_manager = { get_visible_value=function() return 1 end }
assert(loadstring(io.open("gamedata/scripts/ghillie_gud.script"):read("*a")))()
on_game_start(); cbs.actor_on_first_update(); T=T+7000; cbs.actor_on_update()
local npc=obj("x",1)
local function v(vel) return visual_memory_manager.get_visible_value(npc, db.actor,0,0,0,0,vel,100,60,0) end
-- Light armor and 0 kg: both armor terms floor at 1, so only the camo counts.
local function check(label, vel, expected)
	local got = v(vel)
	print(("  %-22s %s"):format(label, tostring(got)))
	assert_close(got, expected, label)
end
print("REDONE defaults (strength 0.8, still 0.95), light armor, 60 m")
check("still:", 0, 0.05)
move.mcCrouch=true
check("crouch speed 0.05:", 0.05, 0.05)  -- <= STILL_SPEED counts as still
check("crouch speed 0.1:", 0.1, 0.05)
check("crouch speed 0.15:", 0.15, 0.28) -- creep: 1 - 0.8*0.9
check("crouch speed 1:", 1, 0.28)
check("crouch speed 2:", 2, 0.28)
check("crouch speed 3:", 3, 0.36)       -- blend: 1 - 0.8*0.8
check("crouch speed 4:", 4, 0.44)       -- blend: 1 - 0.8*0.7
check("crouch speed 6:", 6, 0.60)       -- crouch-run: 1 - 0.8*0.5
check("crouch speed 9:", 9, 0.60)
move.mcCrouch=nil
check("walk:", 2, 0.68)                 -- 1 - 0.8*0.4
move.mcSprint=true; check("sprint:", 7, 1); move.mcSprint=nil
