`timescale 1ns / 1ps
//=========================================================
// Module  : uart_tx
// Purpose : UART Transmitter — serialises 8-bit parallel
//           data into a UART frame (8N1 format) and drives
//           the TX serial output line.
//
// Frame   : [START=0] [D0..D7 LSB first] [STOP=1]
//           = 10 bits total per character
//
// Inputs  : clk     — system clock
//           start   — pulse HIGH for 1 cycle to begin TX
//           txin    — 8-bit parallel data to transmit
//           bitDone — 1-cycle pulse from baud_gen (timing)
// Outputs : tx      — serial output line (idle HIGH)
//           txdone  — pulses HIGH for 1 cycle when frame done
//           baud_en — HIGH when TX is active (feeds baud_gen)
//=========================================================

module uart_tx(
    input            clk,
    input            start,
    input      [7:0] txin,
    input            bitDone,
    output reg       tx,
    output           txdone,
    output           baud_en    // Enable signal for baud_gen
);

// FSM State encoding
parameter idle  = 2'd0;
parameter send  = 2'd1;
parameter check = 2'd2;

reg [1:0]  state    = idle;
reg [9:0]  txData   = 0;    // 10-bit frame: {STOP, D7..D0, START}
integer    bitIndex = 0;    // Current bit being transmitted (0-9)
reg [9:0]  shifttx  = 0;    // Shift register (declared, unused in output)

//---------- TX FSM ----------
always @(posedge clk) begin
    case (state)

        idle: begin
            tx       <= 1'b1;   // Line HIGH when idle
            txData   <= 0;
            bitIndex <= 0;
            shifttx  <= 0;
            if (start == 1'b1) begin
                // Build 10-bit UART frame:
                // bit[0]=START(0), bit[8:1]=data, bit[9]=STOP(1)
                txData <= {1'b1, txin, 1'b0};
                state  <= send;
            end else begin
                state  <= idle;
            end
        end

        send: begin
            // Drive current bit onto TX line
            tx      <= txData[bitIndex];
            state   <= check;  // Move to CHECK to wait baud period
            shifttx <= {txData[bitIndex], shifttx[9:1]};
        end

        check: begin
            if (bitIndex <= 9) begin       // Bits 0-9 (10 bits total)
                if (bitDone == 1'b1) begin
                    state    <= send;      // Next bit
                    bitIndex <= bitIndex + 1;
                end
                // else: stay in CHECK, wait for bitDone
            end else begin
                state    <= idle;          // All 10 bits sent
                bitIndex <= 0;
            end
        end

        default: state <= idle;

    endcase
end

//---------- Combinational Outputs ----------
// txdone: pulses HIGH for 1 cycle at end of last bit (stop bit)
assign txdone  = (bitIndex == 9 && bitDone == 1'b1) ? 1'b1 : 1'b0;

// baud_en: tells baud_gen to run only when TX is transmitting
assign baud_en = (state != idle) ? 1'b1 : 1'b0;

endmodule
