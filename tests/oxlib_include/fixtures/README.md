# Fixtures

- `ox_lib-v3.39.0/init.lua` — overextended/ox_lib tag `v3.39.0`, unmodified.
- `ox_lib-v3.40.3/init.lua`, `require.lua`, `modules/Class.lua` — overextended/ox_lib tag `v3.40.3`, unmodified.
  ox_lib is licensed under LGPL-3.0-or-later (see the header of each file).
- `legacy/loader-0.9.7.lua` — dusa_bridge 0.9.7 `shared/loader.lua` (bfaf1e1), kept to show the regression:
  `python tests/oxlib_include/run_lupa.py . --loader tests/oxlib_include/fixtures/legacy/loader-0.9.7.lua`
- `res_a/x.lua`, `res_b/x.lua` — same path in two resources, for the include cache key test.
