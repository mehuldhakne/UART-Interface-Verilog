# Comprehensive UART hardware test implementation

## Current implementation scope

`fpga/basys3_top.v` has been updated so `btnR` runs 272 on-chip loopback comparisons:

1. Byte sweep `0x00` through `0xFF` (all 256 possible 8-bit values, including ASCII `0x00`-`0x7F`).
2. Eight patterns: `00`, `FF`, `55`, `AA`, `F0`, `0F`, `81`, `18`.
3. Eight sequential bytes spelling `HELLO123`.

Each item is transmitted by the existing UART TX and compared with the byte captured by the existing project RX. `pass`, `tested`, and `fail_count` are 9-bit counters. The test engine uses a short 16-clock inter-frame pause; the human-readable `btnL` UART message retains its longer pause.

## Switches and results

- Set `SW8` DOWN for internal loopback. Do not fit the JA1-JA2 jumper for this automatic test.
- `btnR` starts the test.
- `btnD` clears displayed results.
- During/after test, seven-segment digits show completed count (three decimal digits) and failure count (one digit; displays `F` for 10 or more failures).
- `LED15` means finished with zero failures; `LED14` means finished; `LED9` means active; `LED8` means at least one failure; `LED7:0` show the latest received byte.

## Important limitations / next work

- This test verifies byte values through the internal TX-to-RX loopback. It does not by itself test the PC-side asynchronous receiver, incorrect baud rates, framing errors, or break detection. Those require separate tests.
- The existing `sim/tb_basys3_top.v` was written for the old 10-vector test and must be updated to expect 272 items before using it as a regression test.
- No HDL simulator/compiler was available in the editing environment, so this change has not yet been compiled or simulated here. Run Vivado **Run Synthesis** before programming the board.
