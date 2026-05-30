`timescale 1ns / 1ps
//=========================================================
// Module  : uart_top
// Purpose : Top-level wrapper — instantiates baud_gen,
//           uart_tx, and uart_rx and connects all internal
//           wires. For simulation a loopback is used
//           (tx connected to rx externally in testbench).
//
// Ports   : clk    — system clock (100 MHz on FPGA)
//           start  — pulse HIGH to begin transmission
//           txin   — 8-bit data to transmit
//           rx     — serial receive input (from wire/loopback)
//           tx     — serial transmit output
//           rxout  — 8-bit received data (valid when rxdone=1)
//           rxdone — pulses HIGH when a byte is received
//           txdone — pulses HIGH when transmission completes
//=========================================================

module uart_top(
    input            clk,
    input            start,
    input      [7:0] txin,
    input            rx,
    output           tx,
    output     [7:0] rxout,
    output           rxdone,
    output           txdone
);

// Internal wires connecting the three submodules
wire bitDone;   // Baud tick: 1-cycle pulse every baud period
wire baud_en;   // Baud enable: HIGH when TX is transmitting

//------ Baud Rate Generator ------
// Generates shared timing reference for TX and RX
baud_gen u_baud_gen (
    .clk    (clk),
    .en     (baud_en),
    .bitDone(bitDone)
);

//------ UART Transmitter ------
// Serialises txin into UART frame on tx line
uart_tx u_uart_tx (
    .clk    (clk),
    .start  (start),
    .txin   (txin),
    .bitDone(bitDone),
    .tx     (tx),
    .txdone (txdone),
    .baud_en(baud_en)
);

//------ UART Receiver ------
// Deserialises serial rx line back to 8-bit rxout
uart_rx u_uart_rx (
    .clk    (clk),
    .rx     (rx),
    .bitDone(bitDone),
    .rxout  (rxout),
    .rxdone (rxdone)
);

endmodule
