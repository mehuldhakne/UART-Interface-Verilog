`timescale 1ns / 1ps
//=========================================================
// Module  : uart_top                       (v2 - FPGA ready)
// Structural wrapper - no logic. Ports unchanged from v1.
// clk_value / baud are now parameters of the top, so one
// number controls BOTH baud_gen and uart_rx.
//
//   Simulation : uart_top #(.clk_value(100_000))     dut (...);
//   Basys 3    : uart_top #(.clk_value(100_000_000)) u   (...);
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

parameter clk_value = 100_000_000;
parameter baud      = 9600;

wire bitDone;
wire baud_en;

baud_gen #(.clk_value(clk_value), .baud(baud)) u_baud_gen (
    .clk    (clk),
    .en     (baud_en),
    .bitDone(bitDone)
);

uart_tx u_uart_tx (
    .clk    (clk),
    .start  (start),
    .txin   (txin),
    .bitDone(bitDone),
    .tx     (tx),
    .txdone (txdone),
    .baud_en(baud_en)
);

uart_rx #(.clk_value(clk_value), .baud(baud)) u_uart_rx (
    .clk    (clk),
    .rx     (rx),
    .bitDone(bitDone),
    .rxout  (rxout),
    .rxdone (rxdone)
);

endmodule
