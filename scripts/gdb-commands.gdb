set pagination off
set confirm off
set print pretty on
set print frame-arguments all
set debuginfod enabled off
info files
info sharedlibrary
info threads
thread apply all bt full
info registers
x/16i $pc-32
x/16gx $sp
