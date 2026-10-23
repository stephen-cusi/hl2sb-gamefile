# Lua layout and remaining GMod migration

This inventory was checked against the installed GMod files on 2026-10-23. It describes source layout and adapters; file presence does not prove native API completeness or live gameplay parity.

## Runtime ownership

| Location | Responsibility |
| --- | --- |
| `lua/includes/init.lua` | Explicit shared/client bootstrap and original Derma includes |
| `lua/hl2sb/compat/` | Fork-specific native bridges, fonts, enumerations, effect aliases and notification compatibility |
| `lua/includes/modules/`, `lua/includes/extensions/` | Public GMod libraries and existing compatibility required by the native startup passes |
| `lua/autorun/` | Automatic game and addon registration |
| `gamemodes/base/gamemode/` | Base player rules and HUD, including `cl_deathnotice.lua` and `gravitygun.lua` |
| `gamemodes/sandbox/gamemode/` | Sandbox commands, creation/context menus, tools and persistence |
| `lua/tests/` | Manual diagnostics; no normal startup execution |

The native loader still prepares extensions/modules before includes/init.lua and mounts gamemode content from `gamemodes/<name>/content/lua`. GMod uses `gamemodes/<name>/entities`. Existing tools/entities remain in their working locations until the native loader supports the canonical hierarchy; moving them alone would stop registration.

The obsolete sandbox BuildMenu pair and disabled Experiment bootstrap were removed. Native hover events own tooltip dispatch; the redundant Lua wrapper around vgui.Create was removed. Original tooltip, Derma and spawnmenu scripts were not replaced.

`deathmatch` and `campaign` remain selectable gamemodes. They are not assumed to be dead directories. The base player-class taunt camera also still contains an old adapter while the active gamemode uses a separate camera implementation; unifying those requires behavior work rather than deleting a duplicate filename.

## Already present under other paths

Toolgun/stools, camera, balloons, dynamite, hoverballs, lamps, lights, thrusters, wheels, base entities and the player hands are already registered from `lua/` or gamemode `content/lua`. They must not be listed as unimplemented merely because the canonical GMod path is absent.

The base kill-feed port now resides at `gamemodes/base/gamemode/cl_deathnotice.lua`; its existing engine-event adapter and single-consumer hooks remain. Gravity callbacks were extracted to `gamemodes/base/gamemode/gravitygun.lua` without changing entity forwarding or vetoes.

Sandbox `cl_notice.lua` is not copied as a separate file: its AddNotify behavior is still supplied by the base adapter. Sandbox `save_load.lua` has a partial file-save adapter in base; GMod's engine.WriteSave/.gms/LoadGModSave path is not implemented by that adapter.

## Original files still absent

After resolving relocated files and the two inline/partial adapters, base has four absent files and sandbox has twelve:

| Gamemode | Files relative to its original `entities/` directory |
| --- | --- |
| base effects | `effects/base.lua`, `effects/dof_node.lua` |
| base entities | `entities/prop_effect.lua`, `entities/ragdoll_motion.lua` |
| sandbox effects | `effects/balloon_pop.lua`, `effects/entity_remove.lua`, `effects/inflator_magic.lua`, `effects/lasertracer.lua`, `effects/phys_unfreeze.lua`, `effects/wheel_indicator.lua` |
| sandbox editor entities | `entities/base_edit.lua`, `entities/edit_fog.lua`, `entities/edit_sky.lua`, `entities/edit_sun.lua` |
| sandbox examples | `entities/nb_example.lua`, `weapons/manhack_welder.lua` |

These are file-level gaps, not sixteen proven broken runtime features. Native effects may cover some names, and empty base methods are not useful substitutes for missing native dispatch. Each import still needs dependency and native-call verification.

Across 178 original base/sandbox Lua files, 107 match existing files after line-ending normalization, 53 have adapters or other differences, 16 are absent, one is supplied inline and one has a partial adapter. These counts exclude addon content and do not describe every Lua library as unmodified upstream.

## Behavioral work still separate

- Canonical gamemode entity-directory loading, with registry order and overrides preserved.
- Original save/archive path and duplicator end-to-end validation.
- Player-class taunt-camera adapter and vehicle CalcView integration.
- Remaining native hook contracts; absence of a Lua default method is not proof of an undispatched hook. PlayerButtonDown/Up and SpawniconGenerated already have native dispatch sites and are no longer unimplemented items.
- Render hooks such as Pre/PostPlayerDraw and GetMotionBlurValues have code paths but their placement/signature concerns in TODO remain open.

Local audit data, the pre-cleanup snapshot, before/after behavior checks and exact relocation manifest are in `D:/tmp/hl2sb_lua_cleanup_20261023`. No game was launched and no live gameplay result is claimed by this cleanup.
