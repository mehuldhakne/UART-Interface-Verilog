# Report Updates — v1 (submitted) → v2 (FPGA-ready)

Your report describes v1. These are the exact places that no longer match, and replacement text you can paste.

## 1. Change summary

| # | File | v1 (in report) | v2 (this package) | Report sections |
|---|---|---|---|---|
| 1 | `baud_gen.v` | `count == wait_count` → pulse every **11** clocks (sim) | `count == wait_count-1` → pulse every exactly **10** clocks; `clk_value` default 100 MHz | 6.2, 7.3.1, 9, 10 |
| 2 | `uart_tx.v` | `bitIndex` reached 10 → read `txData[10]` (out of range) → **X on `tx` for 2 clocks every frame** | CHECK ends the frame at `bitIndex == 9`; `tx` starts HIGH; unused `shifttx` removed | 8.2, 9, **10.3** |
| 3 | `uart_rx.v` | After the stop bit it went round once more (**11th sample**), shifting garbage into `rxdata` after `rxdone` | RECV returns to RIDLE when `rindex == 9 && bitDone` | 8.3, 9 |
| 4 | `uart_top.v` | `clk_value` fixed inside submodules | `clk_value`, `baud` are top parameters passed down; ports unchanged | 7.3.4, 9 |
| 5 | `tb.v` | waited `rxdone` then `txdone`; no comparison | waits `rxdone`, compares `rxout` with `txin`, prints PASS/FAIL + summary | 10.1 |
| 6 | **new** `uart_rx_async.v`, `basys3_top.v`, `debounce_oneshot.v`, `seg7_driver.v`, `Basys3_UART.xdc` | – | FPGA demo | **new Section 11** |

How these were checked: Icarus Verilog 12 (not Vivado) — v1 reproduced the X cycles and the 11-clock pulse; v2 shows 0 X cycles and 10-clock pulses; 10/10 vectors PASS at scaled clock **and** at real 100 MHz timing; 26/26 board-level checks PASS; Yosys synthesis for Xilinx 7-series is clean (no latches). Re-run everything in Vivado and take **new screenshots**.

---

## 2. Replacement text — Section 10.3 ("red undefined X states")

**Delete** the paragraph that calls the X a *simulator artefact*. **Paste:**

> **Undefined (X) values at frame boundaries — root cause and fix.**
> In the first version of the design a brief X appeared on the `tx` line at the end of every frame. During hardware preparation this was traced to the transmitter FSM: after the stop bit, `bitIndex` was incremented to 10 and the SEND state executed `tx <= txData[bitIndex]`. Since `txData` is a 10-bit register (indices 0 to 9), this read lay outside the vector, which evaluates to X in simulation and is undefined in hardware. It lasted two clock cycles per frame.
> The CHECK state was modified so the frame ends when `bitDone = 1` and `bitIndex = 9` (the stop bit has been held for one bit period), returning to IDLE without a further SEND. After the change the `tx` line contains no undefined values: 0 X cycles were measured over 10 frames, at both the scaled and the real 100 MHz clock.

## 3. Replacement text — Section 10.2 / 10.3 (`rxout` after `rxdone`)

Add this sentence after the "intermediate values" explanation:

> `rxout` is valid while `rxdone` is HIGH. In v2 the receiver returns to idle immediately after the stop-bit sample (in v1 an extra eleventh sample shifted an unwanted bit into `rxdata` after `rxdone`), and the testbench compares `rxout` with `txin` at the instant `rxdone` rises.

## 4. Section 6 / 7.3.1 — bit period

v1 produced `bitDone` every 11 clock cycles in simulation (110 ns) while the text said 10 cycles (100 ns). v2 produces exactly 10 cycles, so the Section 6.2 table (clock period 10 ns, bit period 100 ns) is now **correct as written**. Simulation length for 10 frames: 10.185 µs. Re-take Waveform 1 and 2 so the screenshots show 100 ns bits and no red X.

## 5. FSM diagrams (Section 8)

Use **`docs/uart_fsm_diagrams_v2.svg`** in place of the old figure. Update the tables:

**TX FSM — replace the last two rows**

| Current | Condition | Next | Action |
|---|---|---|---|
| CHECK | bitDone=1, bitIndex < 9 | SEND | bitIndex++ |
| CHECK | bitDone=1, bitIndex = 9 | IDLE | bitIndex=0 (frame complete) |

Also delete "shifttx" wherever it is mentioned (Section 8.2 SEND description, Section 9 listing).

**RX FSM — replace the last two rows**

| Current | Condition | Next | Action |
|---|---|---|---|
| RECV | bitDone=1, rindex < 9 | RWAIT | rindex++ |
| RECV | bitDone=1, rindex = 9 | RIDLE | frame complete (rxdone pulses) |

## 6. Section 9 — code listings

Replace the four listings with `rtl/baud_gen.v`, `uart_tx.v`, `uart_rx.v`, `uart_top.v`. Add `uart_rx_async.v` and the testbench `sim/tb.v` (new). The FPGA-only files go into Section 11 or the Appendix.

## 7. Section 11 — FPGA Implementation (new, ready to paste)

### 11.1 Target platform
The design was implemented on a Digilent Basys 3 board (Xilinx Artix-7 XC7A35T-1CPG236C, 100 MHz clock, USB-UART bridge, 16 switches, 16 LEDs, 5 push buttons, 4-digit 7-segment display) using Vivado 2020.2.

### 11.2 Hardware changes required
Three changes were needed to move the design from simulation to the board:
1. **Baud timing.** `clk_value` was changed from the scaled simulation value (100 000) to 100 000 000, giving `wait_count = 10 416` clocks per bit (104.17 µs). It is a single parameter of `uart_top`.
2. **Transmitter frame end.** An out-of-range read of `txData[10]` (undefined `tx` for two clocks per frame) was removed.
3. **Receiver for external data.** The project receiver is clocked by the transmitter-side baud tick and therefore receives its own transmissions (loopback and wire). A self-timed receiver, `uart_rx_async`, was added for bytes arriving from the PC. It includes a 2-flop synchroniser and mid-bit sampling.

### 11.3 Board-level design (`basys3_top`)
Switch bits 7:0 select the data byte, `btnC` sends it, `btnL` sends the word "UART", `btnR` runs a hardware self-test using the ten testbench vectors, `btnD` clears the display and `btnU` resets the sequencer. Buttons are debounced (20 ms) and converted to single-clock pulses. LEDs show the received byte in binary; the 7-segment display shows the transmitted and received bytes in hexadecimal.

### 11.4 Verification on hardware
| Test | Method | Result |
|---|---|---|
| Single byte | `sw=0x41`, `btnC` | LEDs `01000001`, PuTTY `A` — **fill in** |
| Word | `btnL` | PuTTY `UART` — **fill in** |
| Jumper wire JA1→JA2 | `sw[8]=1` | byte received through a physical pin — **fill in** |
| Self-test (wire in) | `btnR` | 10/10, LED15 lit — **fill in** |
| Self-test (wire out) | `btnR` | 0/10, LED15 off — **fill in** |
| PC → FPGA | type `K` in PuTTY | LEDs `01001011` — **fill in** |
| Echo | `sw[10]=1`, type | characters returned — **fill in** |

### 11.5 Implementation results (take from **your** Vivado reports)
| Resource / metric | Value |
|---|---|
| LUTs / FFs / IO | … |
| WNS (setup) at 100 MHz | … |
| Total on-chip power | … |

> Do not copy numbers from anywhere else. Use your own *Report Utilization / Timing Summary / Power* output.

### 11.6 Figures to insert
Board photo, PuTTY window, wire loopback close-up, self-test PASS and FAIL photos, elaborated schematic, utilisation report.

## 8. Appendix D
Delete the "FPGA testing was not completed" note and replace it with a one-line pointer to Section 11.

## 9. Presentation / PPT edits
- Slide "Design Decisions": add "Single parameter for clock: scaled for simulation, 100 MHz for hardware".
- Slide "Simulation results": remove the "red X = simulator artefact" claim; say it was a **real bug (out-of-range index) found and fixed**.
- Add one slide: **"On the board"** with the self-test photo (all LEDs lit) and the PuTTY window.
- FSM slide: use `uart_fsm_diagrams_v2.svg`.
