# UART on Basys 3 — Prototype & Demonstration Guide

Board: Digilent Basys 3 (Artix-7 `XC7A35T-1CPG236C`) · Tool: Vivado 2020.2 · Link: 9600 baud, 8N1

---

## 0. What you are demonstrating (say this first, 30 seconds)

> "This is my UART, written in Verilog, running on the FPGA. The board has two serial paths.
> **Path 1:** my transmitter sends a byte out as a real serial frame, and my receiver, on the same chip, rebuilds it. I can send that frame over a jumper wire and show it arrive.
> **Path 2:** the same serial line goes to the PC through the USB-UART bridge, so PuTTY shows what the FPGA sends, and what I type on the PC is received by the FPGA.
> The same 10 test vectors from my simulation testbench also run on the chip as a hardware self-test."

Two receivers exist on purpose, say so up front:

| Receiver | File | Used for | Why |
|---|---|---|---|
| **Project RX** (in the report) | `uart_rx.v` | Everything the board sends (loopback and jumper wire) | Takes its timing from the shared baud tick |
| **Extension RX** (new) | `uart_rx_async.v` | Bytes typed on the PC | Has its own bit counter, so it can receive while the TX is idle |

---

## 1. Board cheat-sheet (keep this open during the demo)

### Switches

| Switch | Function |
|---|---|
| `sw[7:0]` (SW0 = rightmost) | The data byte to send. SW7…SW0 = bit 7…0 |
| `sw[8]` | **RX source.** Down = internal loopback. Up = the jumper wire JA1→JA2 |
| `sw[9]` | **7-segment view.** Down = `[TX byte][RX byte]`. Up = `[PC byte][PC count]` |
| `sw[10]` | **Echo.** Up = every byte typed on the PC is sent back to the PC |
| `sw[15:11]` | unused |

### Push buttons

| Button | Function |
|---|---|
| **btnC** (centre) | Send the byte set on `sw[7:0]` |
| **btnL** (left) | Send the word `UART` + CR + LF |
| **btnR** (right) | **Hardware self-test**, 10 test vectors compared on-chip |
| **btnD** (down) | **Clear** LEDs, 7-segment and results |
| **btnU** (up) | Soft reset of the demo sequencer |

Buttons are accepted only when the previous action has finished. The word takes ≈2 s, the self-test ≈3 s.

### LEDs and 7-segment

| Display | Normal mode | Self-test mode |
|---|---|---|
| `LED[7:0]` (right half) | Last byte received by the **project RX**, in binary | LED0…LED9 = one LED per test vector (lit = PASS) |
| `LED[15:8]` (left half) | Last byte received **from the PC**, in binary | LED14 = test finished · LED15 = **all 10 passed** |
| 7-segment, `sw[9]`=0 | `[TX byte hex][RX byte hex]`, e.g. `41 41` | `[vectors sent][vectors passed]` in decimal, e.g. `10 10` |
| 7-segment, `sw[9]`=1 | `[PC byte hex][PC byte count]` | same as above |
| Decimal point, leftmost digit | Lit = a **framing error** was received from the PC | |

---

## 2. Build the bitstream (Vivado 2020.2)

1. **File → Project → New → RTL Project.** Name it `uart_basys3`. Tick *Do not specify sources at this time*.
2. **Part:** search `xc7a35tcpg236-1` (or choose the *Basys3* board if board files are installed).
3. **Add Sources → Add or create design sources.** Add all 8 files:
   - `rtl/` → `baud_gen.v`, `uart_tx.v`, `uart_rx.v`, `uart_top.v`, `uart_rx_async.v`
   - `fpga/` → `basys3_top.v`, `debounce_oneshot.v`, `seg7_driver.v`
4. **Add Sources → Add or create constraints** → `fpga/Basys3_UART.xdc`.
5. **Add Sources → Add or create simulation sources** → `sim/tb.v` and `sim/tb_basys3_top.v`.
   Copy `test_vectors.txt` into `<project>.sim/sim_1/behav/xsim/` (create the folder by running a simulation once), or give the full path in `VEC_FILE`.
6. In *Sources*, right-click **`basys3_top`** → **Set as Top**.
7. **Flow Navigator:** *Run Synthesis* → *Run Implementation* → *Generate Bitstream*.
   (Expect zero errors. If a "port not constrained" or pin-conflict message appears, check the XDC against Digilent's `Basys-3-Master.xdc`.)

**Capture for Section 11 of the report** (open each report from the Flow Navigator):
- *Report Utilization* → LUT, FF, IO counts
- *Report Timing Summary* → **WNS** (should be positive at 100 MHz)
- *Report Power* → total on-chip power
- *Open Elaborated Design → Schematic* → shows `basys3_top` containing `u_uart` and `u_pc_rx`

---

## 3. Connect everything

1. Power switch **OFF**. Connect a micro-USB cable from the PC to the port labelled **PROG / UART** on the board. Power switch **ON**. The power LED lights.
2. **Hardware Manager → Open Target → Auto Connect → Program Device** → select `uart_basys3.runs/impl_1/basys3_top.bit`.
   After programming the `DONE` LED lights. All LEDs off, 7-segment shows `0000`.
3. **Find the COM port:** Windows **Device Manager → Ports (COM & LPT) → "USB Serial Port (COMx)"**. If two ports appear, unplug and re-plug to see which one is new.
4. **PuTTY → Connection type: Serial.**
   - Serial line: `COMx` Speed: **9600**
   - Connection → Serial: Data bits **8**, Stop bits **1**, Parity **None**, Flow control **None**
   - Open. A blank terminal appears.
5. **Jumper wire** (needed for demo steps D4–D6): one female–female wire between **Pmod JA pin 1** and **JA pin 2**. These are the first two signal pins of the same row.
   Pin 1 = `ja_tx` (serial out), pin 2 = `ja_rx` (serial in). Pin 1 is the one marked on the board silkscreen; confirm the numbering against the Basys 3 reference manual before plugging in.
   **Never touch pins 5, 6, 11, 12** (GND / 3.3 V). Do not plug the wire in yet, you will do that in D4.
6. Set **all switches down**, then press **btnD** once.

---

## 4. The demonstration, step by step

Each step has **Do → See → Say**. Total about 10 minutes.

### D1. One byte, sent and received (btnC)

- **Do:** set `sw[7:0] = 0100 0001` (SW6 and SW0 up). Keep `sw[8]` down. Press **btnC**.
- **See:**
  - `LED[7:0]` shows `0100 0001` (LED6 and LED0 lit)
  - 7-segment `41 41`
  - PuTTY prints **A**
- **Say:** "The switches are the parallel input. My TX turned `0x41` into a 10-bit frame, start bit, 8 data bits LSB first, stop bit. My RX rebuilt it. The LEDs show what the **receiver** produced, not what the switches hold."

### D2. A different byte, read it in binary

- **Do:** set `0101 0101` (`0x55`, SW6, SW4, SW2, SW0 up). Press **btnC**. Then try `0x42`, `0x7A`.
- **See:** PuTTY prints `U`, `B`, `z`; LEDs show the same bit pattern.
- **Say:** "`0x55` is the alternating pattern, it makes the most edges on the line, so it is the standard bit-timing test."

### D3. The word UART (btnL)

- **Do:** press **btnL**, then again.
- **See:** PuTTY prints `UART` on a new line each time. The LEDs and 7-segment step through `55 → 41 → 52 → 54 → 0D → 0A`, one every 0.3 s.
- **Say:** "Six frames: U, A, R, T, carriage return, line feed. These are the same first four bytes as my testbench."

### D4. Real signals leaving and re-entering the chip (jumper wire)

- **Do:** set `sw[8]` **up**. Plug the wire between **JA1 and JA2**. Set `sw[7:0] = 0x5A`. Press **btnC**.
- **See:** `LED[7:0] = 0101 1010`, 7-segment `5A 5A`.
- **Now pull the wire out.** Set `sw[7:0] = 0xA5`. Press **btnC**.
- **See:** the **left two digits change to `A5`** (sent) but the **right two digits stay `5A`** (nothing received). LEDs do not change.
- **Say:** "With the wire in, the frame leaves a physical pin and comes back into my receiver. With it out, the byte is still sent, but nothing arrives. So the reception is real, not a software shortcut."

### D5. Hardware self-test — the testbench, running on silicon (btnR)

- **Do:** plug the wire back in (`sw[8]` up). Press **btnD**, then **btnR**.
- **See (about 3 s):**
  - LED0 to LED9 light **one by one** (each lit LED = one vector passed)
  - 7-segment counts `01 01`, `02 02` … `10 10`
  - At the end **LED14 and LED15 light**
- **Say:** "These are the same ten vectors from my File-I/O testbench. The board sends each one, receives it, compares, and lights an LED. LED15 means all ten matched."

### D6. Prove the test can fail (pull the wire)

- **Do:** pull the wire out. Press **btnR**.
- **See:** **no** LED0–9 light. LED14 lights (finished), **LED15 stays off**. 7-segment `10 00`.
- **Say:** "If the self-test could not fail, it would prove nothing. With the wire out nothing is received, so every vector fails."

### D7. The PC types, the FPGA receives (extension RX)

- **Do:** set `sw[8]` down, `sw[9]` **up**. Click inside the PuTTY window and type `K`.
- **See:**
  - `LED[15:8]` = `0100 1011` (the ASCII code of K: LED14, LED11, LED9, LED8)
  - 7-segment `4B 01` (code, then count). Typing more keys raises the count.
  - **Nothing appears in PuTTY.** PuTTY does not echo locally.
- **Say:** "My keystroke came down the USB-UART bridge as a serial frame at 9600 baud. This second receiver has its own bit counter, a 2-flop synchroniser for the asynchronous input, and mid-bit sampling."

### D8. Echo — a full round trip

- **Do:** set `sw[10]` **up**. Type `hello` in PuTTY.
- **See:** `hello` **now appears** in PuTTY, and the LEDs and 7-segment follow each key.
- **Say:** "Every key travels PC → FPGA RX → my TX → PC. That is a complete duplex loop through my design. Turn the switch off and the echo stops."

### D9. (Optional) Why baud rates must match

- **Do:** `sw[10]` down. In PuTTY: right-click the title bar → **Change Settings → Connection → Serial** → speed **4800** → Apply. Type `K`.
- **See:** `LED[15:8]` shows `1001 1110` (`0x9E`), **not** `0x4B`. The count may jump by 2. Typing `A` lights the **decimal point** (framing error).
- **Restore** the speed to **9600**, press **btnD**.
- **Say:** "No clock wire exists, so both sides must agree on the bit time. At the wrong speed the receiver samples the wrong instants and rebuilds garbage."

### D10. (Optional) Link the board to the simulation

- If an oscilloscope or logic analyser is available, probe **JA1** (`ja_tx`, GND on JA pin 5) and press **btnC** with `0x41`. The waveform is the frame from your report diagram, with **104 µs per bit** and **1.04 ms per frame**.
- Otherwise show: the simulation PASS log (`sim/expected_logs/`), and the Vivado utilisation / timing reports.

---

## 5. What to say if asked "what changed from your submitted design?"

Be direct. It reads as engineering, not as a mistake:

1. **Baud timing constants.** The report used a scaled clock (`100_000`) for fast simulation. The board runs at 100 MHz, so `clk_value` is now a top-level parameter. The testbench keeps the scaled value, the FPGA uses `100_000_000`. One RTL, two settings.
2. **A real bug, found while preparing for hardware.** The TX could read `txData[10]`, outside the 10-bit vector, for two clock cycles per frame. This produced the red X on the waveform. The frame now ends cleanly at index 9. The old explanation ("simulator artefact") was wrong.
3. **The baud pulse was every 11 clocks, not 10.** The counter compared to `wait_count`, not `wait_count − 1`. Corrected, so the report's "10 cycles per bit" is now true.
4. **RX stopped taking an 11th sample** after the stop bit.
5. **New:** the extension receiver, so the FPGA can receive from the PC.

Evidence: with the fixes, 0 X cycles in 10 frames, 10/10 PASS at both the scaled clock and real 100 MHz timing.

---

## 6. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Hardware Manager: no target found | Power switch off / cable / drivers | Switch ON, re-plug USB, install Digilent/FTDI drivers |
| PuTTY opens but nothing prints | Wrong COM port | Device Manager, try the other COM number |
| PuTTY shows garbage characters | Speed not 9600, or flow control on | Serial speed **9600**, flow control **None** |
| `btnC` does nothing | Previous action still running, or button not held ≥20 ms | Wait 3 s, press firmly |
| `sw[8]` up, nothing received | Wire missing or on wrong pins | JA **1 → 2**, same row |
| Self-test lights only some LEDs | Loose jumper wire | Re-seat the wire |
| 7-segment shows hex when you expect decimal | Hex is normal mode. Decimal appears only after **btnR** | Press **btnD**, then **btnR** |
| LED15 never lights though all 10 LEDs do | Self-test still running | Wait for LED14 |
| Bitstream error about unconstrained ports | XDC not added, or port name mismatch | Add `Basys3_UART.xdc` under *Constraints* |
| Vivado simulation can't find `test_vectors.txt` | File not in the xsim folder | Copy it there, or set `VEC_FILE` to the full path |

---

## 7. Likely questions from the guide

**Why two receivers?** "My report receiver gets its timing from the transmitter's baud tick, perfect for loopback and the wire demo, but it cannot receive while the TX is idle. The PC can send at any time, so I added a self-timed receiver for that direction."

**Why is the RX input held high when nothing is being sent?** "The project RX only works while the baud generator runs. Parking its input idle prevents a glitch from starting a frame that would then wait forever for a tick."

**What is the 2-flop synchroniser for?** "The PC and the FPGA share no clock, so a signal can change right at my clock edge and leave a flip-flop metastable. Two flip-flops in series give it time to settle. The 16550 datasheet specifies the same idea."

**Why debounce the buttons?** "A mechanical button bounces for a few milliseconds and would register as many presses. I wait until the level has been stable for 20 ms and then emit exactly one clock-wide pulse."

**How is the 7-segment display driven?** "Four digits share one set of segment lines. I light one digit at a time, about 760 full refreshes per second, so the eye sees all four."

**How much of the FPGA is used?** Quote your own Vivado utilisation report. Expect well under 2% of the device.

---

## 8. Checklist — photos / screenshots to collect for Section 11

- [ ] Board photo with the demo running (LEDs + 7-segment visible)
- [ ] PuTTY window showing `A`, `UART`, and the echo
- [ ] Jumper wire plugged into JA1–JA2 (close-up)
- [ ] Self-test result: LED0–9, LED14, LED15 lit + `10 10` on the display
- [ ] Self-test failure with the wire out (LED15 off, `10 00`)
- [ ] Vivado: utilisation report, timing summary (WNS), power report, schematic
- [ ] (Optional) oscilloscope or logic-analyser capture of JA1
