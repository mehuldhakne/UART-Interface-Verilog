UART Transceiver in Verilog: Simulation and FPGA Implementation (Basys 3)

A modular UART (8N1, 9600 baud) written in Verilog, verified with a self-checking file-I/O testbench, and demonstrated on a Digilent Basys 3 (Artix-7 XC7A35T) with PuTTY, switches, LEDs and the 7-segment display.

The design follows the UART 16550 IP specification (SIDSA datasheet v1.0), implemented in 16450-compatible mode (no FIFO).

Board demo




  
Features
8N1 frame (1 start, 8 data bits LSB first, 1 stop), 9600 baud from a 100 MHz clock (10 416 clocks per bit)
Moore-FSM transmitter and receiver, shared baud-tick generator, structural top level
Mid-bit sampling: the receiver waits half a bit after the start edge, then samples at the centre of each bit
Self-timed receiver for PC input with a 2-flop synchroniser, start-bit glitch rejection and a framing-error flag
One clock parameter drives both simulation (scaled) and hardware (100 MHz)
Self-checking testbench: loads 10 test vectors with $readmemh, compares every byte
Basys 3 demo: single byte, the word UART, on-chip self-test, jumper-wire loopback, PC typing, echo
Architecture
uart_top
baud_en
tx
loopback
RsRx
baud_genbitDone tick
uart_tx3-state FSM
uart_rx3-state FSM
sw 7:0 + btnC
RsTx / JA1
LEDs + 7-seg
PC keyboard
uart_rx_asyncself-timed
Module	Role
baud_gen	Pulses bitDone once every wait_count = clk_value / baud clocks while a frame is in flight
uart_tx	Builds {STOP, D7..D0, START} and shifts it out one bit per bitDone
uart_rx	Detects the start bit, waits half a bit, then samples each bit at its centre; rxout = rxdata[8:1]
uart_top	Structural wrapper; clk_value and baud are parameters
uart_rx_async	Receiver with its own bit counter, used for bytes arriving from the PC
basys3_top	Board demo: buttons, switches, LEDs, 7-segment, PC and wire paths
debounce_oneshot, seg7_driver	20 ms button debounce with a one-clock pulse; 4-digit multiplexed display

Why two receivers? uart_rx takes its timing from the transmitter's baud tick, so it receives while the board is transmitting (loopback and jumper-wire demo). A byte typed on the PC arrives while the transmitter is idle, so uart_rx_async keeps its own counter for that direction.

Specifications
Parameter	Value
Frame format	8N1 (10 bits per character)
Baud rate	9600 bps (parameterised)
System clock	100 MHz (Basys 3); scaled to 100 kHz for fast simulation
Bit period	104.17 µs on hardware, 100 ns in the scaled simulation
Sampling	One sample at the centre of each bit (not 16x oversampling)
Parity / FIFO	Not implemented
Reference	UART 16550 IP datasheet, SIDSA v1.0 (2000)
Language / tool	Verilog-2001, Vivado 2020.2
Target	Digilent Basys 3, XC7A35T-1CPG236C
Repository structure
.
├── rtl/
│   ├── baud_gen.v        uart_tx.v        uart_rx.v
│   ├── uart_top.v        uart_rx_async.v
├── fpga/
│   ├── basys3_top.v      debounce_oneshot.v     seg7_driver.v
│   └── Basys3_UART.xdc
├── sim/
│   ├── tb.v                     loopback testbench (file I/O, self-checking)
│   ├── tb_basys3_top.v          virtual board + virtual PC testbench
│   ├── test_vectors.txt         55 41 52 54 A5 5A FF 00 0F F0
│   └── expected_logs/
├── docs/
│   ├── FPGA_Demo_Guide.md       build, connect, demo steps, troubleshooting
│   ├── uart_fsm_diagrams_v2.svg
│   └── images/
└── README.md
Simulation

Vivado: add rtl/*.v as design sources, sim/tb.v as a simulation source (sim top tb), and copy sim/test_vectors.txt into <project>.sim/sim_1/behav/xsim/.

Icarus Verilog:

bash
iverilog -g2005 -o tb.vvp sim/tb.v rtl/baud_gen.v rtl/uart_tx.v rtl/uart_rx.v rtl/uart_top.v
cd sim && vvp ../tb.vvp

Expected output ends with PASSED: 10 / 10    FAILED: 0 / 10.

Test	Result
Loopback, 10 vectors, scaled clock	10/10 PASS, no undefined values on tx
Loopback, 10 vectors, real timing (CLK_VALUE = 100_000_000)	10/10 PASS
Board-level model (buttons, wire in/out, PC typing, echo, self-test, 7-segment)	26/26 checks PASS
<!-- Add after re-running in Vivado: -->

Waveform: two frames

FPGA implementation (Basys 3)

Full steps are in docs/FPGA_Demo_Guide.md.

Create a Vivado project for part xc7a35tcpg236-1.
Add rtl/*.v and fpga/*.v as design sources and fpga/Basys3_UART.xdc as the constraint file.
Set basys3_top as the top module, then run synthesis, implementation and bitstream generation.
Connect the PROG/UART USB port, program the board, and open PuTTY: 9600, 8 data bits, 1 stop bit, no parity, no flow control.
Controls
Control	Function
sw[7:0] + btnC	Send the byte set on the switches
btnL	Send the word UART + CR + LF
btnR	Hardware self-test: replays the 10 test vectors and compares each on-chip
btnD / btnU	Clear display / soft-reset the demo sequencer
sw[8]	Receiver input: internal loopback, or jumper wire JA1 to JA2
sw[9]	7-segment view: TX and RX bytes, or PC byte and count
sw[10]	Echo: bytes typed in PuTTY are sent back
LED[7:0]	Last byte received by the project receiver
LED[15:8]	Last byte received from the PC
Self-test	LED0 to LED9 = one per vector, LED14 = finished, LED15 = all 10 passed
Hardware results
Item	Result
Single byte, PuTTY output	☐
Jumper-wire loopback (JA1 to JA2)	☐
Self-test, wire in (10/10)	☐
Self-test, wire out (0/10, as expected)	☐
PC to FPGA reception, echo	☐
Resource utilisation (LUT / FF / IO)	from Vivado report
Worst negative slack at 100 MHz	from Vivado report
Design notes

Issues found while preparing for hardware, and fixed:

Out-of-range index in the transmitter. The FSM read txData[10] on a 10-bit register after the stop bit, leaving tx undefined for 2 clocks per frame. The frame now ends cleanly at index 9.
Baud pulse period. The counter compared against wait_count, giving a pulse every wait_count + 1 clocks. It now compares against wait_count - 1.
Receiver extra sample. The receiver took an eleventh sample after the stop bit. It now returns to idle immediately after sampling the stop bit.
Hard-coded clock constant. clk_value is now a top-level parameter (scaled for simulation, 100 MHz for hardware).
Limitations and future work
uart_rx receives only while the transmitter's baud tick is running; uart_rx_async covers the PC direction. A single self-timed receiver would unify the two.
No parity, no overrun detection, no break detection.
No 16-byte FIFOs (16450-compatible mode).
Single baud rate; a programmable divisor (DLL/DLM) is a natural extension.
AXI-Lite or APB register interface.
References
SIDSA, UART 16550 IP Core Datasheet, v1.0, 2000.
Digilent, Basys 3 FPGA Board Reference Manual and Basys-3-Master.xdc.
AMD/Xilinx, Vivado Design Suite User Guide: Logic Simulation (UG900).
Author

Mehul Dhakne: Final-year B.E. Electronics and Telecommunication Engineering, Government College of Engineering, Amravati. LinkedIn · Portfolio

