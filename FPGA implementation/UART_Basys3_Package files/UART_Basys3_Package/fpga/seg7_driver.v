`timescale 1ns / 1ps
//=========================================================
// Module  : seg7_driver
// Purpose : Drives the Basys 3 four-digit 7-segment display.
//           value[15:12] = leftmost digit ... value[3:0] = rightmost
//           Segments and anodes are ACTIVE-LOW on the Basys 3.
//           The four digits share one set of segment lines, so they
//           are lit one at a time, ~760 times per second each cycle
//           (refresh[17:16] selects the digit) - the eye sees all four.
//
//           dp_on[3:0] : 1 = light the decimal point of that digit
//=========================================================
module seg7_driver(
    input             clk,
    input      [15:0] value,
    input      [3:0]  dp_on,
    output reg [6:0]  seg,      // {g,f,e,d,c,b,a}  seg[0]=CA ... seg[6]=CG
    output reg        dp,
    output reg [3:0]  an
);

reg [17:0] refresh = 18'd0;
always @(posedge clk) refresh <= refresh + 18'd1;

wire [1:0] sel = refresh[17:16];

reg [3:0] nib;
reg [3:0] an_n;
reg       dp_n;
reg [6:0] seg_n;

always @(*) begin
    case (sel)
        2'd0:    begin an_n = 4'b1110; nib = value[3:0];   dp_n = ~dp_on[0]; end
        2'd1:    begin an_n = 4'b1101; nib = value[7:4];   dp_n = ~dp_on[1]; end
        2'd2:    begin an_n = 4'b1011; nib = value[11:8];  dp_n = ~dp_on[2]; end
        default: begin an_n = 4'b0111; nib = value[15:12]; dp_n = ~dp_on[3]; end
    endcase
end

always @(*) begin
    case (nib)               //   gfedcba   (0 = segment ON)
        4'h0: seg_n = 7'b1000000;
        4'h1: seg_n = 7'b1111001;
        4'h2: seg_n = 7'b0100100;
        4'h3: seg_n = 7'b0110000;
        4'h4: seg_n = 7'b0011001;
        4'h5: seg_n = 7'b0010010;
        4'h6: seg_n = 7'b0000010;
        4'h7: seg_n = 7'b1111000;
        4'h8: seg_n = 7'b0000000;
        4'h9: seg_n = 7'b0010000;
        4'hA: seg_n = 7'b0001000;
        4'hB: seg_n = 7'b0000011;
        4'hC: seg_n = 7'b1000110;
        4'hD: seg_n = 7'b0100001;
        4'hE: seg_n = 7'b0000110;
        default: seg_n = 7'b0001110;   // F
    endcase
end

// Registered outputs: anode, segments and dp change on the SAME clock edge,
// so a digit never shows the previous digit's pattern (no ghosting).
always @(posedge clk) begin
    an  <= an_n;
    seg <= seg_n;
    dp  <= dp_n;
end

initial begin
    an  = 4'b1111;
    seg = 7'b1111111;
    dp  = 1'b1;
end

endmodule
