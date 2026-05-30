`timescale 1ns / 1ps
//=========================================================
// Module  : uart_rx
// Purpose : UART Receiver — detects start bit on the serial
//           RX line, samples 8 data bits using mid-bit
//           sampling, and outputs the assembled byte.
//
// Sampling: RX waits wait_count/2 cycles after start bit
//           edge to sample at the CENTRE of each bit period
//           (maximum noise margin — 16550 datasheet method).
//
// Inputs  : clk     — system clock
//           rx      — serial input line (idle HIGH)
//           bitDone — 1-cycle pulse from baud_gen (timing)
// Outputs : rxout   — 8-bit received parallel data
//           rxdone  — pulses HIGH for 1 cycle when byte ready
//=========================================================

module uart_rx(
    input        clk,
    input        rx,
    input        bitDone,
    output [7:0] rxout,
    output       rxdone
);

// FSM State encoding
parameter ridle = 2'd0;
parameter rwait = 2'd1;
parameter recv  = 2'd2;

// Baud parameters (must match baud_gen)
parameter clk_value  = 100_000;
parameter baud       = 9600;
parameter wait_count = clk_value / baud;  // = 10 cycles per bit

reg [1:0]  rstate = ridle;
reg [9:0]  rxdata = 0;    // 10-bit shift register (captures full frame)
integer    rcount = 0;    // Half-bit period counter (for mid-bit sampling)
integer    rindex = 0;    // Bit counter (0-9: start + 8 data + stop)

//---------- RX FSM ----------
always @(posedge clk) begin
    case (rstate)

        ridle: begin
            rxdata <= 0;
            rindex <= 0;
            rcount <= 0;
            if (rx == 1'b0)       // Detect HIGH→LOW = start bit
                rstate <= rwait;
            else
                rstate <= ridle;  // Keep watching
        end

        rwait: begin
            // Count wait_count/2 cycles to reach MID-POINT of bit
            // This aligns subsequent samples to bit centres
            if (rcount < wait_count / 2) begin
                rcount <= rcount + 1;
                rstate <= rwait;
            end else begin
                rcount <= 0;
                rstate <= recv;
                // Sample rx and shift into rxdata from MSB side:
                // After 10 shifts: rxdata[0]=START, [8:1]=DATA, [9]=STOP
                rxdata <= {rx, rxdata[9:1]};
            end
        end

        recv: begin
            if (rindex <= 9) begin     // Collect 10 bits (0-9)
                if (bitDone == 1'b1) begin
                    rindex <= rindex + 1;
                    rstate <= rwait;   // Back to RWAIT to re-align
                end
                // else: wait for bitDone (stay in RECV)
            end else begin
                rstate <= ridle;       // All bits received
                rindex <= 0;
            end
        end

        default: rstate <= ridle;

    endcase
end

//---------- Combinational Outputs ----------
// rxout: strip START(bit0) and STOP(bit9) — only the 8 data bits
assign rxout  = rxdata[8:1];

// rxdone: pulses HIGH for 1 cycle when last bit (stop bit) is sampled
assign rxdone = (rindex == 9 && bitDone == 1'b1) ? 1'b1 : 1'b0;

endmodule
