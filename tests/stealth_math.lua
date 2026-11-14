local T = 0
function time_global() return T end
AC_ID = 0
function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
local move = {}
function IsMoveState(s) return move[s] or false end
function IsStalker(o) return true end
function printf() end
function log(m) print(m) end
local cbs = {}
function RegisterScriptCallback(n,f) cbs[n]=f end
local outfits = { heavy_outfit={kind="o_heavy"}, exo_outfit={kind="o_heavy"}, ghillie_outfit={kind="o_medium", npc_blindness_koeff=20}, stalker_outfit={kind="o_medium"} }
ini_sys = {
  section_exist=function(_,s) return s=="ghillie_gud_force_exo" end,
  line_count=function() return 1 end,
  r_line_ex=function() return true,"army_nosorog_outfit","" end,
  r_string_ex=function(_,s,k) return outfits[s] and outfits[s][k] end,
  r_float_ex=function(_,s,k) return outfits[s] and outfits[s][k] end,
}
stealth_mcm = { get_config=function() return 1 end }
local worn, belt = "stalker_outfit", true
local function obj(sec,id) return { section=function() return sec end, id=function() return id end, name=function() return "npc"..id end, alive=function() return true end } end
db = { actor = {
  iterate_belt=function(self,f) if belt then f(self,obj("ghillie_wrap",5)) end end,
  item_in_slot=function(_,i) return i==7 and worn and obj(worn,6) or nil end,
  get_total_weight=function() return 40 end,
  id=function() return 0 end } }
local upstream = 1 -- what the detection script itself returns
visual_memory_manager = { get_visible_value=function() return upstream end }
local src = io.open("gamedata/scripts/ghillie_gud.script"):read("*a")
assert(loadstring(src))()
on_game_start()
T=100000; cbs.actor_on_first_update(); T=T+7000; cbs.actor_on_update()
local npc, actor = obj("x",1), db.actor
local function v(vel,d) refresh(); return visual_memory_manager.get_visible_value(npc,actor,0,0,0,0,vel,100,d,0) end
local function check(label, vel, d, expected)
	local got = v(vel, d)
	print(label, got)
	assert_close(got, expected, label)
end
-- Plain defaults: strength 0.85, still 0.95, fade 5..25 m (smoothstep),
-- armor_reduction 0.5. Weight 40 kg -> wei = exp(0.4).
-- At 50 m both armor terms floor at 1, so only the camo counts.
check("medium, still, 50m:", 0, 50, 0.05)
-- 15 m: fade 0.5 -> camo 1-0.95*0.5 = 0.525; armor: jm 2 -> 1.5, both > 1 -> 0.75
check("medium, still, 15m:", 0, 15, 0.525 * 0.75)
check("medium, still, 3m:", 0, 3, 1)
move.mcCrouch=true; check("medium, creep 50m:", 1, 50, 1 - 0.85 * 0.9); move.mcCrouch=nil
check("medium, walk 50m:", 1, 50, 1 - 0.85 * 0.4)
move.mcSprint=true; check("medium, sprint 50m:", 1, 50, 1); move.mcSprint=nil
cbs.actor_on_weapon_fired(); check("just fired 50m:", 0, 50, 1); T=T+4000
-- 20 m walk: fade 0.84375, scale 0.3375 -> camo 0.713125; armor ratio 1-0.5*0.3375
worn="heavy_outfit"; check("heavy, walk 20m (armor factor):", 1, 20, 0.713125 * 0.83125)
worn="exo_outfit"; check("exo, still 50m:", 0, 50, 1)
worn="army_nosorog_outfit"; outfits.army_nosorog_outfit={kind="o_heavy"}; check("nosorog, still 50m:", 0, 50, 1)
-- Ghillie outfit (koeff 20) at 50 m: the detection script already applied its
-- own camo, 0.5. The wrap's 0.05 is stronger, so the final rate must be 0.05
-- (wrapper ratio 0.1), not 0.05 * 0.5 stacked.
worn="ghillie_outfit"; upstream=0.5
check("ghillie outfit+wrap still 50m (final):", 0, 50, 0.05)
-- Zero scale must hand back the upstream value untouched.
move.mcSprint=true; check("ghillie outfit+wrap sprint 50m:", 1, 50, 0.5); move.mcSprint=nil
upstream=1
worn="stalker_outfit"
move.mcSprint=true; check("medium, sprint 8m:", 5, 8, 1); move.mcSprint=nil
check("medium, still 3m:", 0, 3, 1)
-- 40 m: camo 0.05; armor: jm 4.5 -> 2.25, both > 1 -> 0.5
worn="heavy_outfit"; check("heavy, still 40m:", 0, 40, 0.025)
-- 15 m creep: scale 0.45 -> camo 0.6175; armor ratio 1-0.5*0.45
move.mcCrouch=true; check("heavy, creep 15m:", 1, 15, 0.6175 * 0.775); move.mcCrouch=nil
move.mcSprint=true; check("heavy, sprint 15m:", 5, 15, 1); move.mcSprint=nil
belt=false; worn="stalker_outfit"; upstream=0.3; check("no wrap (upstream 0.3):", 0, 50, 0.3)
