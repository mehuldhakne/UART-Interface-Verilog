`timescale 1ns / 1ps
//=========================================================
// Module  : baud_gen                       (v2 - FPGA ready)
// Purpose : Generates a 1-cycle 'bitDone' pulse EXACTLY every
//           wait_count clock cycles. Shared timing reference
//           (metronome) for TX and RX.
//
// Changes vs v1:
//   * clk_value default is now the real board clock (100 MHz).
//     The testbench overrides it with a scaled value for fast
//     simulation:  uart_top #(.clk_value(100_000)) ...
//   * Pulse period is now exactly wait_count cycles
//     (v1 compared count == wait_count, so the period was
//     wait_count + 1 = 11 cycles in simulation, not 10).
//=========================================================
module baud_gen(
    input      clk,
    input      en,        // HIGH while TX is transmitting
    output reg bitDone    // 1-cycle pulse every wait_count cycles
);

parameter clk_value  = 100_000_000;       // system clock in Hz
parameter baud       = 9600;              // target baud rate
parameter wait_count = clk_value / baud;  // cycles per bit (10416 @ 100 MHz)

integer count = 0;

initial bitDone = 1'b0;

always @(posedge clk) begin
    if (!en) begin
        // counter parked while TX is idle -> first bit of every
        // frame gets a full, uninterrupted baud period
        count   <= 0;
        bitDone <= 1'b0;
    end else begin
        if (count == wait_count - 1) begin
            bitDone <= 1'b1;
            count   <= 0;
        end else begin
            count   <= count + 1;
            bitDone <= 1'b0;
        end
    end
end

endmodule
