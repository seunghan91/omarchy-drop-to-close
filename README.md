# Drop to Close

Close windows the way you'd throw something away on a Mac: drag a window with
**SUPER + left mouse**, and a small trash tile appears at the bottom center of
the screen. Drop the window on it and the window closes.

- **Graceful close, not a kill.** Apps still get the chance to ask
  "save changes?".
- **Sized for your screen.** The tile is 7.5% of the monitor's short side
  (after scaling), clamped to 52–88 logical px, so it stays small on 16:9,
  16:10, 21:9, 32:9 and portrait monitors alike.
- **Easy to hit.** The hit area is slightly larger than the tile and extends
  down to the screen edge, so flinging a window downward lands.
- **Leaves your bindings alone.** Omarchy's `SUPER + drag` "Move window"
  binding keeps working exactly as before; this only adds non-consuming
  press/release binds next to it.
- **Multi-monitor aware.** The tile follows the monitor under the cursor.

## Requirements

- Omarchy 4 (Quattro) with the Lua Hyprland config and `omarchy-shell`.
  Tested on Omarchy 4.0.4 / Hyprland 0.56.2.
- No other dependencies. The icon uses the Nerd Font Omarchy ships with.

## Install

1. Add the shell plugin (it draws the trash tile):

   ```bash
   omarchy plugin add https://github.com/seunghan91/omarchy-drop-to-close.git --enable
   ```

2. The drag detection runs inside Hyprland, so it needs one manual step that
   the installer deliberately never does for you: add these lines to
   `~/.config/hypr/hyprland.lua`, below `require("hypr.autostart")`:

   ```lua
   -- Drop to Close
   local drop_to_close = loadfile(os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.seunghan91.drop-to-close/hypr/drop_to_close.lua")
   if drop_to_close then drop_to_close() end
   ```

   `loadfile` returns `nil` when the plugin is missing, so this line is
   harmless if the plugin is ever removed.

3. Apply and check for errors:

   ```bash
   hyprctl reload && hyprctl configerrors
   ```

## Options

Set `drop_to_close_options` **before** the loader lines. Every field is
optional.

```lua
drop_to_close_options = {
  size_ratio = 0.075, -- tile size as a share of the monitor's short side
  min_size = 52,      -- logical px
  max_size = 88,      -- logical px

  -- Replace the default close. `close(window)` performs the default action.
  -- Example: ask before closing terminals.
  on_drop = function(window, close)
    if window.class ~= "foot" then return close(window) end
    hl.exec_cmd("my-confirm-close-script")
  end,
}
```

## Remove

1. Delete the loader lines (and `drop_to_close_options`, if you added it) from
   `~/.config/hypr/hyprland.lua`, then run `hyprctl reload`.
2. Remove the shell plugin:

   ```bash
   omarchy plugin remove io.github.seunghan91.drop-to-close
   ```

## How it works

- `hypr/drop_to_close.lua` adds a non-consuming `SUPER + mouse:272` press bind
  and a modifier-ignoring `mouse:272` release bind. While a drag is in
  progress, a 40 ms timer tracks the cursor, decides whether it is over the
  tile, and closes the dragged window on release. A 30-second safety timeout
  hides the tile if a release is ever missed.
- `DropToClose.qml` is a draw-only overlay (empty input region, so it never
  intercepts the drag). The Lua side sends it geometry and hover state with
  `omarchy-shell shell summon | call | hide`, so what is drawn and what is
  hit-tested always match.

## License

[MIT](LICENSE)
