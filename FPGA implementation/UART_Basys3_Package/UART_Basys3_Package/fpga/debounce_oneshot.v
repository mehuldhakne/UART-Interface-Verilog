`timescale 1ns / 1ps
//=========================================================
// Module  : debounce_oneshot
// Purpose : Mechanical push-buttons bounce for a few ms.
//           This module (1) synchronises the button to clk,
//           (2) waits until the level has been stable for
//           CYCLES clock cycles, and (3) outputs ONE clock-wide
//           pulse when a stable press is confirmed.
//           Holding the button does NOT repeat the pulse.
//
// CYCLES = 2_000_000 @ 100 MHz = 20 ms
//=========================================================
module debounce_oneshot #(
    parameter integer CYCLES = 2_000_000
)(
    input      clk,
    input      btn,
    output reg pulse
);

reg     s1     = 1'b0;
reg     s2     = 1'b0;
reg     stable = 1'b0;
integer cnt    = 0;

initial pulse = 1'b0;

always @(posedge clk) begin
    s1    <= btn;
    s2    <= s1;
    pulse <= 1'b0;

    if (s2 == stable) begin
        cnt <= 0;                         // nothing new
    end else if (cnt == CYCLES - 1) begin
        stable <= s2;                     // new level held long enough
        cnt    <= 0;
        if (s2) pulse <= 1'b1;            // rising edge only
    end else begin
        cnt <= cnt + 1;
    end
end

endmodule
