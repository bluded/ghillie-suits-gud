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
local outfits = { stalker_outfit={kind="o_medium", player_hud_section="actor_hud_stalker"}, exo_outfit={kind="o_heavy", player_hud_section="actor_hud_exo"} }
local sections = { actor_hud_ghillie=true, ghillie_gud_hands_split=true }
local hudsec = { actor_hud_ghillie={visual="hands/ghillie"}, actor_hud_stalker={visual="hands/stalker"} }
local bracer=false
wd_slots={is_bracer_worn=function() return bracer end}
local written={}
function system_ini() return {set_readonly=function() end,set_override_names=function() end,w_string=function(_,s,k,v) written[#written+1]=k.."="..v end} end
ini_sys = {
  section_exist=function(_,s) return sections[s] or false end,
  line_count=function() return 0 end,
  r_line_ex=function() return false end,
  r_string_ex=function(_,s,k) return (outfits[s] and outfits[s][k]) or (hudsec[s] and hudsec[s][k]) end,
  r_float_ex=function(_,s,k) return outfits[s] and outfits[s][k] end,
}
stealth_mcm = { get_config=function() return 1 end }
game = { translate_string=function(s) return s end }
actor_menu = { set_msg=function(_,m) print("  MSG:", m) end }
local hud_log = {}
local hud = { set_hands=function(_,s) hud_log[#hud_log+1]="set:"..s end, reset_hands=function() hud_log[#hud_log+1]="reset" end }
function get_player_hud() return hud end
wd_hands_left = { reset=function() hud_log[#hud_log+1]="wd_reset" end }
local worn, belt = "stalker_outfit", {}
local function obj(sec,id) return { section=function() return sec end, id=function() return id end } end
db = { actor = {
  iterate_belt=function(self,f) for _,o in ipairs(belt) do f(self,o) end end,
  item_in_slot=function(_,i) return i==7 and worn and obj(worn,6) or nil end,
  move_to_ruck=function(_,o) for i,b in ipairs(belt) do if b==o then table.remove(belt,i) print("  moved to ruck:", o:section()) end end end,
  get_total_weight=function() return 40 end, id=function() return 0 end } }
visual_memory_manager = { get_visible_value=function() return 1 end }
assert(loadstring(io.open("gamedata/scripts/ghillie_gud.script"):read("*a")))()
on_game_start()
local function step(ms) T=T+ms; cbs.actor_on_update() end
-- Prints the arm calls since the last check and asserts them.
local function expect(label, expected)
	local got = table.concat(hud_log," | ")
	hud_log={}
	print(label, got == "" and "(nothing)" or got)
	assert_eq(got, expected, label)
end
local GH, SPLIT = "set:actor_hud_ghillie", "set:ghillie_gud_hands_split"

-- A replacement installed at five seconds must be captured at six seconds.
T=1000; cbs.actor_on_first_update()
step(5000)
local patched = function() return 0.73 end
visual_memory_manager.get_visible_value = patched
step(1000)
assert_close(visual_memory_manager.get_visible_value(nil,nil), 0.73, "captures late upstream")
-- Reload the script to exercise the missing-target lifecycle independently.
assert(loadstring(io.open("gamedata/scripts/ghillie_gud.script"):read("*a")))()
on_game_start()
visual_memory_manager.get_visible_value = nil
T=1000; cbs.actor_on_first_update()
step(6000)
local upstream_calls = 0
local upstream = function() upstream_calls=upstream_calls+1; return 0.42 end
visual_memory_manager.get_visible_value = upstream
step(1000)
assert(visual_memory_manager.get_visible_value ~= upstream, "missing hook retries")
assert_close(visual_memory_manager.get_visible_value(nil,nil), 0.42, "upstream retained")
local hooked = visual_memory_manager.get_visible_value
cbs.actor_on_first_update(); step(7000)
assert_eq(visual_memory_manager.get_visible_value, hooked, "reload avoids double install")
assert_eq(upstream_calls, 1, "upstream called once")
