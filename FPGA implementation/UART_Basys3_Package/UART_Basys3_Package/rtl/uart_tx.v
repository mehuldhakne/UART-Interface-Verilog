`timescale 1ns / 1ps
//=========================================================
// Module  : uart_tx                        (v2 - FPGA ready)
// Frame   : [START=0] [D0..D7, LSB first] [STOP=1]  (8N1)
//
// Changes vs v1:
//   * BUG FIX: v1 let bitIndex reach 10 and then executed
//     tx <= txData[10]. txData is only 10 bits wide (0..9), so
//     the read was out of range and drove X on the tx pin for
//     2 clock cycles at the end of EVERY frame. The frame now
//     ends cleanly when the stop bit (index 9) has been held
//     for one bit period.
//   * tx has an initial value of 1 (line idles HIGH from
//     power-up, no X at time 0).
//   * Unused 'shifttx' register removed.
//=========================================================
module uart_tx(
    input            clk,
    input            start,      // pulse HIGH 1 cycle while idle
    input      [7:0] txin,
    input            bitDone,    // baud tick from baud_gen
    output reg       tx,
    output           txdone,     // 1-cycle pulse at end of stop bit
    output           baud_en     // HIGH while a frame is in progress
);

parameter idle  = 2'd0;
parameter send  = 2'd1;
parameter check = 2'd2;

reg [1:0] state    = idle;
reg [9:0] txData   = 10'h3FF;    // {STOP, D7..D0, START}
integer   bitIndex = 0;          // 0 .. 9

initial tx = 1'b1;

always @(posedge clk) begin
    case (state)

        idle: begin
            tx       <= 1'b1;
            bitIndex <= 0;
            if (start == 1'b1) begin
                txData <= {1'b1, txin, 1'b0};
                state  <= send;
            end
        end

        send: begin
            tx    <= txData[bitIndex];
            state <= check;
        end

        check: begin
            if (bitDone == 1'b1) begin
                if (bitIndex == 9) begin      // stop bit finished
                    state    <= idle;
                    bitIndex <= 0;
                end else begin
                    state    <= send;
                    bitIndex <= bitIndex + 1;
                end
            end
        end

        default: state <= idle;

    endcase
end

assign txdone  = (bitIndex == 9 && bitDone == 1'b1) ? 1'b1 : 1'b0;
assign baud_en = (state != idle) ? 1'b1 : 1'b0;

endmodule
