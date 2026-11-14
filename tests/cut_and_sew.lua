-- Cut a ghillie_outfit into a wrap and sew it back: condition carries over,
-- upgraded suits are blocked, a wrap on the belt can't be sewn.
local T = 1000
function time_global() return T end
AC_ID = 0
function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
function IsMoveState() return false end
function IsStalker() return true end
function printf() end
function log(m) end
local cbs = {}
function RegisterScriptCallback(n,f) cbs[n]=f end
ini_sys = { section_exist=function() return false end, line_count=function() return 0 end, r_line_ex=function() return false end,
  r_string_ex=function() return nil end, r_float_ex=function() return nil end }
game = { translate_string=function(s) return s end }
local msgs = {}
actor_menu = { set_msg=function(_,m) msgs[#msgs+1]=m end }
function get_player_hud() return nil end
visual_memory_manager = { get_visible_value=function() return 1 end }

local actor = { id=function() return 0 end }
local inv, belt, worn = {}, {}, nil   -- id -> item; belt list; worn outfit
local upgraded = {}
local next_id = 100
local online = true -- whether new items are online right away
local pending_online = {}

local function make(sec, cond)
	next_id = next_id + 1
	local id = next_id
	local it = { _sec=sec, _cond=cond or 1 }
	function it:id() return id end
	function it:section() return self._sec end
	function it:parent() return inv[id] and actor or nil end
	function it:condition() return self._cond end
	function it:set_condition(c) self._cond = c end
	return it
end
local function give(it) inv[it:id()] = it; return it end

utils_item = { has_upgrades=function(o) return upgraded[o:id()] == true end }
zz_item_artefact = { cond_t = {} }
level = { object_by_id=function(id) return inv[id] end }
function alife_release(o) inv[o:id()] = nil; for i,b in ipairs(belt) do if b==o then table.remove(belt,i) end end end
local created = {}
function alife_create_item(sec, parent, t)
	local it = make(sec, 1)
	-- Outfits take t.cond through GAMMA's spawner; the wrap's is set by the script.
	if t and t.cond then it._cond = t.cond end
	created[#created+1] = { sec=sec, t=t }
	if online then give(it) else pending_online[#pending_online+1] = it end
	return { id = it:id() }
end
actor.item_in_slot = function(_, i) return i==7 and worn or nil end
actor.iterate_belt = function(self, f) for _,o in ipairs(belt) do f(self,o) end end
actor.get_total_weight = function() return 0 end
db = { actor = actor }

assert(loadstring(io.open("gamedata/scripts/ghillie_gud.script"):read("*a")))()
on_game_start()
cbs.actor_on_first_update()
local function step(ms) T=T+ms; cbs.actor_on_update() end
local function find(sec) for _,it in pairs(inv) do if it:section()==sec then return it end end end
local function count(sec) local n=0 for _,it in pairs(inv) do if it:section()==sec then n=n+1 end end return n end

print("-- cut a 40% suit")
local suit = give(make("ghillie_outfit", 0.4))
assert_eq(menu_cut(suit), "st_ghillie_gud_cut", "cut option shown")
menu_cut_action(suit); step(16)
assert_eq(count("ghillie_outfit"), 0, "suit consumed")
local wrap = find("ghillie_wrap")
assert(wrap, "wrap created")
print("wrap condition:", wrap:condition())
assert_close(wrap:condition(), 0.4, "wrap keeps suit condition")
assert_close(zz_item_artefact.cond_t[wrap:id()], 0.4, "binder record matches")
assert_eq(msgs[#msgs], "st_ghillie_gud_cut_done", "cut message")

print("-- wrap on the belt can't be sewn")
belt = { wrap }
assert_eq(menu_sew(wrap), nil, "no sew option on belt")
menu_sew_action(wrap); step(16)
assert_eq(count("ghillie_wrap"), 1, "wrap still there")
belt = {}

print("-- sew it back")
assert_eq(menu_sew(wrap), "st_ghillie_gud_sew", "sew option in backpack")
local wrap_id = wrap:id()
menu_sew_action(wrap); step(16)
assert_eq(count("ghillie_wrap"), 0, "wrap consumed")
assert_eq(zz_item_artefact.cond_t[wrap_id], nil, "binder record cleared")
local back = find("ghillie_outfit")
print("suit condition:", back:condition())
assert_close(back:condition(), 0.4, "suit gets wrap condition")
assert_eq(msgs[#msgs], "st_ghillie_gud_sew_done", "sew message")

print("-- worn suit: no cut option")
worn = back
assert_eq(menu_cut(back), nil, "no cut option while worn")
menu_cut_action(back)
assert_eq(count("ghillie_outfit"), 1, "worn suit untouched")
worn = nil

print("-- upgraded suit is blocked")
upgraded[back:id()] = true
menu_cut_action(back); step(16)
assert_eq(count("ghillie_outfit"), 1, "upgraded suit kept")
assert_eq(count("ghillie_wrap"), 0, "no wrap from upgraded suit")
assert_eq(msgs[#msgs], "st_ghillie_gud_cut_upgraded", "upgrade message")
upgraded[back:id()] = nil

print("-- full-condition suit / old wrap stays at 100%")
alife_release(back)
local full = give(make("ghillie_outfit", 1))
menu_cut_action(full); step(16)
local w2 = find("ghillie_wrap")
assert_close(w2:condition(), 1, "100% wrap")
menu_sew_action(w2); step(16)
assert_close(find("ghillie_outfit"):condition(), 1, "sews back at 100%")
alife_release(find("ghillie_outfit"))

print("-- wrap comes online a few frames later")
online = false
local s3 = give(make("ghillie_outfit", 0.25))
menu_cut_action(s3); step(16); step(16)
for _,it in ipairs(pending_online) do give(it) end
pending_online = {}
step(16)
assert_close(find("ghillie_wrap"):condition(), 0.25, "condition set once online")
online = true

print("cut and sew OK")

-- Creation failure keeps the source and reports failure in both directions.
local create = alife_create_item
alife_create_item = function() return nil end
local kept_suit = give(make("ghillie_outfit", 0.4))
menu_cut_action(kept_suit)
assert_eq(inv[kept_suit:id()], kept_suit, "failed cut keeps source")
assert_eq(msgs[#msgs], "st_ghillie_gud_exchange_failed", "cut failure message")
local kept_wrap = give(make("ghillie_wrap", 0.3))
zz_item_artefact.cond_t[kept_wrap:id()] = 0.3
menu_sew_action(kept_wrap)
assert_eq(inv[kept_wrap:id()], kept_wrap, "failed sew keeps source")
assert_close(zz_item_artefact.cond_t[kept_wrap:id()], 0.3, "failed sew keeps binder")
alife_create_item = create
-- Sew before the first update must use the condition awaiting application.
for id in pairs(inv) do inv[id] = nil end
menu_cut_action(give(make("ghillie_outfit", 0.2)))
menu_sew_action(find("ghillie_wrap")); step(16)
assert_close(find("ghillie_outfit"):condition(), 0.2, "immediate sew keeps condition")
step(16)

-- Near-full damaged outfit survives both conversions without spawner cond support.
for id in pairs(inv) do inv[id] = nil end
menu_cut_action(give(make("ghillie_outfit", 0.98)))
step(16)
assert_close(find("ghillie_wrap"):condition(), 0.98, "98 percent wrap")
menu_sew_action(find("ghillie_wrap"))
step(16)
assert_close(find("ghillie_outfit"):condition(), 0.98, "98 percent outfit")
