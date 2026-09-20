# EcoShift repository instructions

- EcoShift is still in development and has not been publicly released.
- Do not add migrations, legacy data conversion, compatibility shims, fallback paths for old saves, or support for obsolete item and system formats unless the user explicitly requests them.
- When replacing a system, remove its obsolete implementation and old configuration instead of keeping parallel old and new paths.
- Development saves and obsolete items may be deleted rather than migrated. Keep only the current intended data format and behavior.
- Do not create or run tests, smoke tests, or test scripts unless the user explicitly asks.
