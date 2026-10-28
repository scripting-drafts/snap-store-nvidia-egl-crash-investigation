# Intentionally cheap, crash-thread-only first pass.
# See docs/TEST-PLAN.md before attempting anything more expensive.
set pagination off
set confirm off
set debuginfod enabled off
set auto-load off
set print pretty off
set print elements 0
set print frame-arguments none
set print static off
set backtrace limit 12
bt 12
info registers
x/8i $pc
