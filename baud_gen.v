`timescale 1ns / 1ps
//=========================================================
// Module  : baud_gen
// Purpose : Generates a 1-cycle 'bitDone' pulse every
//           wait_count clock cycles — acts as the shared
//           timing reference (metronome) for TX and RX.
// Inputs  : clk   — system clock
//           en    — enable (driven HIGH by TX when active)
// Output  : bitDone — 1-cycle pulse at every baud period
//=========================================================

module baud_gen(
    input      clk,
    input      en,
    output reg bitDone
);

parameter clk_value  = 100_000;        // Simulation clock value (Hz)
parameter baud       = 9600;           // Target baud rate (bps)
parameter wait_count = clk_value/baud; // Cycles per bit = 10

integer count = 0;

always @(posedge clk) begin
    if (!en) begin
        // Reset counter when TX is idle — ensures first bit
        // always gets a full baud period on next transmission
        count   <= 0;
        bitDone <= 1'b0;
    end else begin
        if (count == wait_count) begin
            bitDone <= 1'b1;   // Pulse HIGH for 1 cycle
            count   <= 0;      // Reset counter
        end else begin
            count   <= count + 1;
            bitDone <= 1'b0;
        end
    end
end

endmodule
