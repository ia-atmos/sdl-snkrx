-- Dumps tables of the original as Atmos source, for `src/data.atm`.
-- Run by `bench.lua` when SNKRX_DUMP=file is set, after `init()`.
--
-- Conversion:
--   a Color is an integer 0xRRGGBBAA (rounded as `rgba` of the port);
--   a table of scalars with keys 1..n is a vector, from index 0;
--   any other table keeps its keys (numbers as `@n=`, strings as fields);
--   a function of a level (descriptions) is called for levels 1 to 3;
--   numeric keys above 150 are left out (the loops past level 150).

-- The tables of the original, grouped by entity: one record per
-- character, class, passive, and level, from the parallel tables of the
-- original (`character_colors[c]`, `character_classes[c]`, ...). Lists
-- whose order matters (the characters of a tier, drawn at random) stay
-- lists.
local function contains (t, x)
  for _, v in ipairs(t) do if v == x then return true end end
  return false
end

-- The keys of all of the tables (a class of the enemies has only its
-- stat multipliers; a character, all of its tables).
local function keys (...)
  local ks = {}
  for _, t in ipairs({...}) do
    for k in pairs(t) do ks[k] = true end
  end
  return pairs(ks)
end

local function groups ()
  local chars = {}
  for k in keys(character_names, character_colors, character_color_strings, character_classes,
                 character_class_strings, character_descriptions, character_effect_names,
                 character_effect_names_gray, character_effect_descriptions,
                 character_effect_descriptions_gray, character_tiers) do
    chars[k] = {
      name = character_names[k], color = character_colors[k], color_string = character_color_strings[k],
      classes = character_classes[k], class_string = character_class_strings[k],
      description = character_descriptions[k],
      effect_name = character_effect_names[k], effect_name_gray = character_effect_names_gray[k],
      effect_description = character_effect_descriptions[k],
      effect_description_gray = character_effect_descriptions_gray[k],
      tier = character_tiers[k],
      attacks = not contains(non_attacking_characters, k),
      cooldown = not contains(non_cooldown_characters, k),
    }
  end
  local classes = {}
  for k in keys(class_colors, class_color_strings, class_stat_multipliers, class_descriptions) do
    classes[k] = {
      color = class_colors[k], color_string = class_color_strings[k],
      stat_multipliers = class_stat_multipliers[k], description = class_descriptions[k],
    }
  end
  local passives = {}
  for k in keys(passive_names, passive_descriptions, passive_descriptions_level) do
    passives[k] = {
      name = passive_names[k], description = passive_descriptions[k],
      description_level = passive_descriptions_level[k],
    }
  end
  local levels = {}
  for l = 1, 150 do
    levels[l] = {
      tier_weights = level_to_tier_weights[l], gold = level_to_gold_gained[l],
      elite_weights = level_to_elite_spawn_weights[l], elite_types = level_to_elite_spawn_types[l],
      boss = level_to_boss[l],
    }
  end
  return {
    { 'CLASSES', classes, true },
    { 'CHARACTERS', chars, true },
    { 'TIER_CHARACTERS', tier_to_characters },
    { 'PASSIVES', passives, true },
    { 'LEVELS', levels },
    { 'SHOP_ODDS', level_to_shop_odds },
    { 'UNLEVELLABLE_ITEMS', unlevellable_items },
  }
end

local function str (s)
  return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
end

local function key (k)
  if type(k) == 'number' then return '@' .. k end
  if k:match('^[A-Za-z_][A-Za-z0-9_]*$') then return k end
  return '@(' .. str(k) .. ')'
end

local function color (c)
  local f = function (v) return math.floor(math.max(0, math.min(1, v))*255 + 0.5) end
  return string.format('0x%02X%02X%02X%02X', f(c.r), f(c.g), f(c.b), f(c.a))
end

local function scalar (v)
  local t = type(v)
  return t == 'number' or t == 'string' or t == 'boolean'
end

local dump

local function sorted_keys (t)
  local ks = {}
  for k in pairs(t) do
    if not (type(k) == 'number' and k > 150) then table.insert(ks, k) end
  end
  table.sort(ks, function (a, b)
    if type(a) == type(b) then return a < b end
    return type(a) == 'number'
  end)
  return ks
end

dump = function (v, ind, by_lvl)
  local t = type(v)
  if t == 'number' then
    if v == math.floor(v) and math.abs(v) < 2^53 then return string.format('%d', v) end
    return string.format('%.17g', v)
  elseif t == 'string' then return str(v)
  elseif t == 'boolean' then return tostring(v)
  elseif t == 'function' then
    if not by_lvl then return nil end
    local out = {}
    for l = 1, 3 do
      local ok, r = pcall(v, l)
      if ok and r ~= nil then table.insert(out, '@' .. l .. '=' .. dump(r, ind)) end
    end
    return '[' .. table.concat(out, ', ') .. ']'
  elseif t == 'table' then
    if v.r and v.g and v.b and getmetatable(v) == Color then return color(v) end
    local n = #v
    local count = 0
    local all_scalar = true
    for k, x in pairs(v) do
      count = count + 1
      if not scalar(x) then all_scalar = false end
    end
    if n == count and all_scalar then
      local out = {}
      for i = 1, n do table.insert(out, dump(v[i], ind)) end
      return '[' .. table.concat(out, ', ') .. ']'
    end
    local out = {}
    local ind2 = ind .. '    '
    for _, k in ipairs(sorted_keys(v)) do
      local x = dump(v[k], ind2, by_lvl)
      if x then table.insert(out, ind2 .. key(k) .. ' = ' .. x .. ',') end
    end
    return '[\n' .. table.concat(out, '\n') .. '\n' .. ind .. ']'
  end
end

return function (path)
  local f = assert(io.open(path, 'w'))
  f:write(';; The data of the original (a327ex/SNKRX@6b93a64), as dumped by\n')
  f:write(';; tools/bench/dump.lua from the running game, one record per\n')
  f:write(';; class, character, passive, and level: do not edit.\n')
  for _, g in ipairs(groups()) do
    f:write('\npin ' .. g[1] .. ' = ' .. dump(g[2], '', g[3]) .. '\n')
  end
  f:close()
end
