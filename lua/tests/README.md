# Manual Lua diagnostics

These scripts are opt-in development tools. The normal client/server bootstrap does not load this directory.

Existing root-level diagnostics now live here. For example:

```text
lua_dofile tests/undo_lib_test.lua
lua_dofile_cl tests/derma_lib_test.lua
```

Use the realm required by each script. Scripts that spawn or change entities should only be run in a disposable test map. The former automatically loaded string probe is now `tests/hl2sb_strtest.lua` and runs only on request.

The migration preserves diagnostic code. `hands_lib_test.lua` and `portalgun_lib_test.lua` already had syntax errors before the move and remain historical probes; they are not passing automated tests.
