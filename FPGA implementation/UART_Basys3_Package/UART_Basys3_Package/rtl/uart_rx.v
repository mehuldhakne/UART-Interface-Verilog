`timescale 1ns / 1ps
//=========================================================
// Module  : uart_rx                        (v2 - FPGA ready)
// Mid-bit sampling receiver. Timing comes from the shared
// 'bitDone' tick of baud_gen, so it receives while the TX
// side is running (loopback / jumper-wire demo).
//
// Changes vs v1:
//   * RECV state ends the frame when the stop bit has been
//     sampled (rindex == 9 && bitDone). v1 went round once
//     more (11th sample), which shifted garbage into rxdata
//     after rxdone. rxout is still valid while rxdone = 1.
//   * clk_value default = real board clock; the testbench
//     overrides it, exactly like baud_gen.
//=========================================================
module uart_rx(
    input        clk,
    input        rx,
    input        bitDone,
    output [7:0] rxout,
    output       rxdone
);

parameter ridle = 2'd0;
parameter rwait = 2'd1;
parameter recv  = 2'd2;

parameter clk_value  = 100_000_000;       // must match baud_gen
parameter baud       = 9600;
parameter wait_count = clk_value / baud;

reg [1:0] rstate = ridle;
reg [9:0] rxdata = 0;     // [0]=START  [8:1]=DATA  [9]=STOP
integer   rcount = 0;
integer   rindex = 0;     // 0..9

always @(posedge clk) begin
    case (rstate)

        ridle: begin
            rxdata <= 0;
            rindex <= 0;
            rcount <= 0;
            if (rx == 1'b0)
                rstate <= rwait;          // start bit detected
        end

        rwait: begin                      // walk to the CENTRE of the bit
            if (rcount < wait_count / 2) begin
                rcount <= rcount + 1;
            end else begin
                rcount <= 0;
                rstate <= recv;
                rxdata <= {rx, rxdata[9:1]};   // sample + shift in
            end
        end

        recv: begin
            if (bitDone == 1'b1) begin
                if (rindex == 9) begin
                    rstate <= ridle;      // stop bit sampled: frame done
                end else begin
                    rindex <= rindex + 1;
                    rstate <= rwait;
                end
            end
        end

        default: rstate <= ridle;

    endcase
end

assign rxout  = rxdata[8:1];
assign rxdone = (rindex == 9 && bitDone == 1'b1) ? 1'b1 : 1'b0;

endmodule
