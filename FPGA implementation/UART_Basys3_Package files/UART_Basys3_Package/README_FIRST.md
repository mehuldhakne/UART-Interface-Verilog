# UART_Basys3_Package — v2 (FPGA-ready)

UART transceiver in Verilog (8N1, 9600 baud) + Basys 3 demo design.
Start with **`docs/FPGA_Demo_Guide.md`**.

```
UART_Basys3_Package/
├── README_FIRST.md
├── rtl/                      <- the UART (report design, fixed)
│   ├── baud_gen.v            baud tick, exact period, parameterised clock
│   ├── uart_tx.v             transmitter (out-of-range read fixed)
│   ├── uart_rx.v             receiver on the shared tick (11th sample removed)
│   ├── uart_top.v            structural top, same ports as v1
│   └── uart_rx_async.v       NEW  self-timed receiver for PC -> FPGA bytes
├── fpga/                     <- Basys 3 only
│   ├── basys3_top.v          demo top: buttons, switches, LEDs, 7-seg, PC, wire
│   ├── debounce_oneshot.v    button debounce + 1-clock pulse
│   ├── seg7_driver.v         4-digit multiplexed display driver
│   └── Basys3_UART.xdc       pin + clock constraints (xc7a35tcpg236-1)
├── sim/
│   ├── tb.v                  loopback testbench, file I/O, self-checking
│   ├── test_vectors.txt      the 10 vectors (55 41 52 54 A5 5A FF 00 0F F0)
│   ├── tb_basys3_top.v       "virtual board + virtual PC" testbench (26 checks)
│   └── expected_logs/        what a passing run prints
└── docs/
    ├── FPGA_Demo_Guide.md    build, connect, demo steps D1-D10, troubleshooting
    ├── Report_Updates.md     what to change in the report + new Section 11 text
    └── uart_fsm_diagrams_v2.svg   FSM figure matching the fixed RTL
```

## Quick start (15 minutes)

1. Vivado 2020.2 → new RTL project → part `xc7a35tcpg236-1`.
2. Add the 5 files in `rtl/` and the 3 `.v` files in `fpga/` as design sources; add `Basys3_UART.xdc` as constraints; set **`basys3_top`** as top.
3. Generate bitstream → program the board → open PuTTY at **9600 8N1, no flow control**.
4. Follow `docs/FPGA_Demo_Guide.md` section 4.

## Simulating in Vivado first
Add `sim/tb.v` as a simulation source (sim top = `tb`) and copy `test_vectors.txt` into the xsim folder.
Expected: `PASSED: 10 / 10`. For the board-level check use `tb_basys3_top` (about 49 ms of simulated time, so allow a few minutes).

## What changed from your submitted design
See `docs/Report_Updates.md`. In short: clock constant is now a parameter; a real out-of-range-index bug in the TX is fixed; `bitDone` period is now exactly `wait_count`; RX no longer takes an 11th sample; one new receiver for the PC direction.

## Verification status — read this

| Item | Status |
|---|---|
| Core loopback, scaled clock | 10/10 PASS (Icarus Verilog 12) |
| Core loopback, real 100 MHz timing (10416 clk/bit) | 10/10 PASS, 0 X cycles |
| Full board model: buttons, wire in/out, PC typing, echo, self-test, 7-seg, framing error | 26/26 checks PASS (Icarus) |
| Synthesis for Xilinx 7-series | Clean in Yosys (no latches, no errors) |
| **Vivado 2020.2 synthesis / implementation / timing** | **Not run — I had no Vivado.** Run it and send me any error text |
| **Bitstream on a real Basys 3** | **Not tested** |
| **XDC pin numbers** | Written from my recollection of Digilent's master file; **verify against `Basys-3-Master.xdc`** (clock, switches, LEDs, buttons, 7-seg, `RsRx`/`RsTx`, Pmod JA1/JA2) |
| Pmod JA pin order and silkscreen | Check against the Basys 3 reference manual before plugging the wire in |

Known limitation (by design, mention it honestly): the report's receiver `uart_rx` is clocked by the transmitter's baud tick, so it receives only while the TX is running — loopback and wire. That is why `uart_rx_async` exists for the PC direction.
