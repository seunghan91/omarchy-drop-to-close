-- Drop to Close: drag a window with SUPER + left mouse and a trash tile
-- appears at the bottom center of the screen; release over it to close the
-- window (graceful close, not a kill, so apps can still ask to save).
--
-- Load this file from ~/.config/hypr/hyprland.lua (see README.md). It leaves
-- Omarchy's SUPER + mouse:272 "Move window" binding untouched and only adds a
-- non-consuming press bind and a release bind next to it. The tile itself is
-- drawn by the shell plugin in the parent directory.
--
-- Optional settings, assigned before this file is loaded:
--
--   drop_to_close_options = {
--     -- Replace the default close. `close(window)` is the default action.
--     on_drop = function(window, close) close(window) end,
--     size_ratio = 0.075, -- tile size as a share of the monitor's short side
--     min_size = 52,      -- logical px
--     max_size = 88,      -- logical px
--   }

local options = rawget(_G, "drop_to_close_options") or {}

local SHELL = "omarchy-shell -q shell "
local PLUGIN = "io.github.seunghan91.drop-to-close"
local TICK_MS = 40
local MAX_DRAG_MS = 30000 -- hide the tile even if the release event is missed

local SIZE_RATIO = options.size_ratio or 0.075
local MIN_SIZE = options.min_size or 52
local MAX_SIZE = options.max_size or 88

local state = { active = false }
local timer

local function round(n)
  return math.floor(n + 0.5)
end

local function clamp(n, lo, hi)
  return math.max(lo, math.min(hi, n))
end

local function vec(v)
  if type(v) ~= "table" then return nil end
  return v.x or v[1], v.y or v[2]
end

-- The tile is sized from the monitor's short logical side (after scaling), so
-- it carries the same visual weight on 16:9, 16:10, 21:9, 32:9 and portrait
-- monitors, and stays small on high-resolution and ultrawide screens:
--   1536x864 (4K @2.5) -> 65px   1920x1080 -> 81px   1280x800 -> 60px
--   2560x1080 (21:9)   -> 81px   3440x1440 -> 88px   1080x1920 -> 81px
local function zone_for(monitor)
  local w, h = monitor.width / monitor.scale, monitor.height / monitor.scale
  if monitor.transform % 2 == 1 then
    w, h = h, w
  end

  local size = clamp(round(math.min(w, h) * SIZE_RATIO), MIN_SIZE, MAX_SIZE)
  local margin = round(size * 0.4)

  return {
    monitor = monitor.name,
    ox = monitor.x,
    oy = monitor.y,
    x = round((w - size) / 2),
    y = round(h - margin - size),
    size = size,
    -- The hit area is slightly larger than the tile (it grows on hover) and
    -- open down to the screen edge, so flinging a window downward lands.
    pad = round(size * 0.15),
  }
end

local function in_zone(zone, cursor)
  local cx, cy = vec(cursor)
  if not cx then return false end
  cx, cy = cx - zone.ox, cy - zone.oy
  return cx >= zone.x - zone.pad
    and cx <= zone.x + zone.size + zone.pad
    and cy >= zone.y - zone.pad
end

local function cursor_on_window(window, cursor)
  local wx, wy = vec(window.at)
  local ww, wh = vec(window.size)
  local cx, cy = vec(cursor)
  if not (wx and ww and cx) then return true end
  return cx >= wx and cx <= wx + ww and cy >= wy and cy <= wy + wh
end

local function show(zone, hover)
  local payload = string.format(
    '{"monitor":"%s","x":%d,"y":%d,"size":%d,"hover":%s}',
    zone.monitor, zone.x, zone.y, zone.size, tostring(hover)
  )
  hl.exec_cmd(SHELL .. "summon " .. PLUGIN .. " '" .. payload .. "'")
end

local function set_hover(hover)
  hl.exec_cmd(SHELL .. "call " .. PLUGIN .. " setHover " .. tostring(hover))
end

local function stop()
  if timer then timer:set_enabled(false) end
  if state.shown then
    hl.exec_cmd(SHELL .. "hide " .. PLUGIN)
  end
  state = { active = false }
end

local function close(window)
  hl.dispatch(hl.dsp.window.close({ window = "address:" .. window.address }))
end

local function tick()
  if not state.active then return end

  state.elapsed = state.elapsed + TICK_MS
  if state.elapsed > MAX_DRAG_MS then
    stop()
    return
  end

  local cursor = hl.get_cursor_pos()
  local monitor = hl.get_monitor_at_cursor()
  if not (cursor and monitor) then return end

  -- Lock in the dragged window on the first tick. A SUPER-drag on the empty
  -- desktop has no window under the cursor, so no tile is shown.
  if not state.window then
    local window = hl.get_active_window()
    if not (window and cursor_on_window(window, cursor)) then
      stop()
      return
    end
    state.window = window
  end

  if not state.zone or state.zone.monitor ~= monitor.name then
    state.zone = zone_for(monitor)
    state.hover = in_zone(state.zone, cursor)
    show(state.zone, state.hover)
    state.shown = true
    return
  end

  local hover = in_zone(state.zone, cursor)
  if hover ~= state.hover then
    state.hover = hover
    set_hover(hover)
  end
end

local function start()
  if state.active then return end
  state = { active = true, elapsed = 0 }
  if not timer then
    timer = hl.timer(tick, { timeout = TICK_MS, type = "repeat" })
  end
  timer:set_enabled(true)
end

local function finish()
  if not state.active then return end
  local window, zone = state.window, state.zone
  local dropped = zone and in_zone(zone, hl.get_cursor_pos())
  stop()
  if dropped and window then
    if type(options.on_drop) == "function" then
      options.on_drop(window, close)
    else
      close(window)
    end
  end
end

hl.bind("SUPER + mouse:272", start, { non_consuming = true, description = "Drop to Close: drag start" })
-- Ignore modifiers on release so the drop still lands when SUPER is let go first.
hl.bind("mouse:272", finish, { release = true, non_consuming = true, ignore_mods = true, description = "Drop to Close: drop" })
