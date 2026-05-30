# UART Interface Design in Verilog HDL

A modular RTL implementation of a UART (Universal Asynchronous Receiver Transmitter) communication interface using Verilog HDL. The project demonstrates serial data transmission and reception following the UART 8N1 protocol and includes complete simulation-based verification using Xilinx Vivado 2020.2.

---

## Project Overview

UART is one of the most widely used asynchronous serial communication protocols in embedded systems, microcontrollers, FPGAs, and SoCs.

This project implements:

- Baud Rate Generator
- UART Transmitter (TX)
- UART Receiver (RX)
- Top-Level Integration Module
- Testbench for Functional Verification

The design was developed as part of an academic industry-oriented project.

---

## Features

✅ UART 8N1 Frame Format

✅ Configurable Baud Rate Generation

✅ Modular RTL Architecture

✅ Mid-Bit Sampling Technique

✅ FSM-Based TX and RX Design

✅ Functional Verification using Vivado Simulator

---

## Project Structure

```text
UART-Interface-Verilog
│
├── src
│   ├── baud_gen.v
│   ├── uart_tx.v
│   ├── uart_rx.v
│   └── uart_top.v
│
├── sim
│   └── tb_uart.v
│
├── docs
│   └── UART_Project_Report.pdf
│
└── README.md
```

## UART Frame Format

```text
| Start | Data[0] | Data[1] | Data[2] | Data[3] |
|   0   |    LSB First Transmission         |

| Data[4] | Data[5] | Data[6] | Data[7] | Stop |
|          Remaining Data Bits         |  1   |
```

Protocol Configuration:

- Baud Rate: 9600 bps
- Data Bits: 8
- Parity: None
- Stop Bits: 1

---

## Simulation Results

The UART transmitter successfully serializes 8-bit parallel data and transmits it through the TX line.

The UART receiver detects the start bit, performs mid-bit sampling, reconstructs the transmitted byte, and verifies successful reception.

Simulation was verified using Vivado waveform analysis.

---

## Tools Used

- Verilog HDL
- Xilinx Vivado 2020.2
- UART 16550 Protocol Reference

---

## Key Concepts Demonstrated

- Finite State Machines (FSM)
- Serial Communication Protocols
- RTL Design
- Shift Registers
- Baud Rate Generation
- Testbench Development
- Functional Verification

---

## Future Enhancements

- FPGA Hardware Implementation
- FIFO Buffers
- Parity Generation and Checking
- Multiple Baud Rate Support
- Interrupt Support

---

## Author

**Mehul Dhakne**

Electronics Engineering Student  
Digital Design • FPGA • VLSI • Embedded Systems
