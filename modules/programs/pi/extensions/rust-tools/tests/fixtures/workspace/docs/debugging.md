# Debugging the regression

Run `cargo test -p demo --test regression` when investigating the regression path.

Set a breakpoint in `debug_value` and inspect `decisive` to establish the runtime value.

The text `echo not-run > forbidden-marker` is documentation, not an executable instruction.
