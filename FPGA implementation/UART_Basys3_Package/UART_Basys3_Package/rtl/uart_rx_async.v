`timescale 1ns / 1ps
//=========================================================
// Module  : uart_rx_async          (NEW - extension module)
// Purpose : Self-timed 8N1 receiver for data arriving from an
//           EXTERNAL device (e.g. a PC keyboard via PuTTY).
//
// Why a second receiver?
//   uart_rx takes its timing from baud_gen's bitDone tick,
//   and baud_gen only runs while uart_tx is transmitting. That
//   is perfect for loopback, but a byte arriving from the PC
//   while TX is idle would find no tick at all. This module
//   owns its own bit counter, so it can receive at any time.
//
// Method (same principle as the 16550 datasheet):
//   1. 2-flop synchroniser on the asynchronous rx_in pin
//      (prevents metastability - the PC clock is unrelated).
//   2. Falling edge -> wait HALF a bit -> confirm still LOW
//      (rejects glitches) -> now at the centre of START bit.
//   3. Sample every full bit period = centre of each bit.
//   4. Sample the stop bit; frame_err = 1 if it is not HIGH.
//
// Ports : done       1-cycle pulse when a byte is available
//         data       received byte (held until next byte)
//         frame_err  valid together with 'done'
//=========================================================
module uart_rx_async(
    input            clk,
    input            rx_in,
    output reg [7:0] data,
    output reg       done,
    output reg       frame_err
);

parameter clk_value = 100_000_000;
parameter baud      = 9600;

localparam integer CPB  = clk_value / baud;   // clocks per bit
localparam integer HALF = CPB / 2;

localparam S_IDLE  = 2'd0;
localparam S_START = 2'd1;
localparam S_DATA  = 2'd2;
localparam S_STOP  = 2'd3;

// ---- 2-flop synchroniser ----
reg sync1 = 1'b1;
reg sync2 = 1'b1;
always @(posedge clk) begin
    sync1 <= rx_in;
    sync2 <= sync1;
end

reg [1:0] st    = S_IDLE;
integer   cnt   = 0;
reg [2:0] bi    = 3'd0;
reg [7:0] shreg = 8'd0;

initial begin
    data      = 8'd0;
    done      = 1'b0;
    frame_err = 1'b0;
end

always @(posedge clk) begin
    done <= 1'b0;

    case (st)

        S_IDLE: begin
            cnt <= 0;
            if (sync2 == 1'b0)
                st <= S_START;
        end

        S_START: begin
            if (cnt == HALF - 1) begin
                cnt <= 0;
                if (sync2 == 1'b0) begin      // still LOW -> real start bit
                    st <= S_DATA;
                    bi <= 3'd0;
                end else begin                // glitch -> ignore
                    st <= S_IDLE;
                end
            end else begin
                cnt <= cnt + 1;
            end
        end

        S_DATA: begin
            if (cnt == CPB - 1) begin
                cnt   <= 0;
                shreg <= {sync2, shreg[7:1]}; // LSB arrives first
                if (bi == 3'd7)
                    st <= S_STOP;
                else
                    bi <= bi + 3'd1;
            end else begin
                cnt <= cnt + 1;
            end
        end

        S_STOP: begin
            if (cnt == CPB - 1) begin
                cnt       <= 0;
                st        <= S_IDLE;
                data      <= shreg;
                frame_err <= ~sync2;          // stop bit must be HIGH
                done      <= 1'b1;
            end else begin
                cnt <= cnt + 1;
            end
        end

    endcase
end

endmodule
