`timescale 1ns / 1ps
//=========================================================
// tb_basys3_top : "virtual Basys 3 + virtual PC" testbench
//
//  Emulates (at the real 9600 baud, 100 MHz clock):
//    - the 5 push buttons and the switches
//    - a PC terminal: decodes everything the FPGA sends on RsTx,
//      and types bytes into RsRx
//    - the jumper wire JA1 -> JA2 (plugged / unplugged)
//  and checks the LEDs and the 7-segment digits for every step of
//  the demo guide.  Run it BEFORE going to the board.
//
//  Debounce and the 300 ms demo gap are shortened (they only
//  matter to humans); the serial timing is the REAL one.
//=========================================================
module tb_basys3_top;

localparam real BIT = 1000000000.0 / 9600.0;   // ns per bit

reg         clk = 0;
reg  [15:0] sw  = 16'd0;
reg         btnC = 0, btnU = 0, btnL = 0, btnR = 0, btnD = 0;
wire [15:0] led;
wire [6:0]  seg;
wire        dp;
wire [3:0]  an;
wire        RsTx, ja_tx;
reg         RsRx = 1'b1;
reg         jumper = 1'b0;                     // 1 = wire JA1->JA2 plugged in
wire        ja_rx = jumper ? ja_tx : 1'b1;     // pull-up when unplugged

basys3_top #(
    .CLK_FREQ       (100_000_000),
    .DEBOUNCE_CYCLES(50),
    .GAP_CYCLES     (3000)
) dut (
    .clk(clk), .sw(sw),
    .btnC(btnC), .btnU(btnU), .btnL(btnL), .btnR(btnR), .btnD(btnD),
    .led(led), .seg(seg), .dp(dp), .an(an),
    .RsTx(RsTx), .RsRx(RsRx), .ja_tx(ja_tx), .ja_rx(ja_rx)
);

always #5 clk = ~clk;

integer errors = 0;
integer checks = 0;

// ---------------- virtual PC : receiver (decodes RsTx) ----------------
reg [7:0] mon [0:63];
integer   mon_n = 0;
reg [7:0] mb;
integer   k;
initial begin
    forever begin
        @(negedge RsTx);
        #(BIT/2.0);
        if (RsTx == 1'b0) begin
            for (k = 0; k < 8; k = k + 1) begin
                #(BIT);
                mb[k] = RsTx;
            end
            #(BIT);                        // stop bit
            mon[mon_n] = mb;
            mon_n = mon_n + 1;
        end
    end
end

// ---------------- virtual PC : transmitter (drives RsRx) ----------------
task pc_send(input [7:0] b, input good_stop);
    integer j;
    begin
        RsRx = 1'b0;           #(BIT);
        for (j = 0; j < 8; j = j + 1) begin
            RsRx = b[j];       #(BIT);
        end
        RsRx = good_stop;      #(BIT);
        RsRx = 1'b1;           #(BIT);
    end
endtask

// ---------------- 7-segment snooping ----------------
reg [3:0] dig [0:3];
reg       dpv [0:3];
function [3:0] seg2nib(input [6:0] s);
    case (s)
        7'b1000000: seg2nib = 4'h0;  7'b1111001: seg2nib = 4'h1;
        7'b0100100: seg2nib = 4'h2;  7'b0110000: seg2nib = 4'h3;
        7'b0011001: seg2nib = 4'h4;  7'b0010010: seg2nib = 4'h5;
        7'b0000010: seg2nib = 4'h6;  7'b1111000: seg2nib = 4'h7;
        7'b0000000: seg2nib = 4'h8;  7'b0010000: seg2nib = 4'h9;
        7'b0001000: seg2nib = 4'hA;  7'b0000011: seg2nib = 4'hB;
        7'b1000110: seg2nib = 4'hC;  7'b0100001: seg2nib = 4'hD;
        7'b0000110: seg2nib = 4'hE;  default:    seg2nib = 4'hF;
    endcase
endfunction
always @(an or seg or dp) begin
    #1;
    case (an)
        4'b1110: begin dig[0] = seg2nib(seg); dpv[0] = ~dp; end
        4'b1101: begin dig[1] = seg2nib(seg); dpv[1] = ~dp; end
        4'b1011: begin dig[2] = seg2nib(seg); dpv[2] = ~dp; end
        4'b0111: begin dig[3] = seg2nib(seg); dpv[3] = ~dp; end
        default: ;
    endcase
end
wire [15:0] shown = {dig[3], dig[2], dig[1], dig[0]};

// ---------------- helpers ----------------
task press(input integer which);               // 0=C 1=U 2=L 3=R 4=D
    begin
        case (which)
            0: btnC = 1;  1: btnU = 1;  2: btnL = 1;  3: btnR = 1;  default: btnD = 1;
        endcase
        #3000;
        btnC = 0; btnU = 0; btnL = 0; btnR = 0; btnD = 0;
        #3000;
    end
endtask

task wait_idle;
    begin
        #2000;
        wait (dut.cs == 3'd0 && dut.busy == 1'b0);
        #(BIT * 3);
    end
endtask

task settle;                       // one full 4-digit refresh sweep (~2.6 ms)
    begin #3_000_000; end
endtask

task check16(input [255:0] name, input [15:0] got, input [15:0] exp);
    begin
        checks = checks + 1;
        if (got === exp) $display("  PASS  %0s = 0x%04h", name, got);
        else begin
            errors = errors + 1;
            $display("  FAIL  %0s = 0x%04h  (expected 0x%04h)", name, got, exp);
        end
    end
endtask

// ---------------- the demo script ----------------
initial begin
    #1000;
    $display("\n=== STEP 1: single byte  sw=0x41, btnC (internal loopback) ===");
    sw[7:0] = 8'h41;  sw[8] = 0;
    press(0);  wait_idle;
    check16("LED[7:0] (RX byte)", {8'h00, led[7:0]}, 16'h0041);
    settle;
    check16("7-seg [TX|RX]     ", shown, 16'h4141);
    check16("PC terminal got   ", {8'h00, mon[0]}, 16'h0041);

    $display("\n=== STEP 2: word UART\\r\\n, btnL ===");
    press(2);  wait_idle;
    check16("PC got 'U'", {8'h00, mon[1]}, 16'h0055);
    check16("PC got 'A'", {8'h00, mon[2]}, 16'h0041);
    check16("PC got 'R'", {8'h00, mon[3]}, 16'h0052);
    check16("PC got 'T'", {8'h00, mon[4]}, 16'h0054);
    check16("PC got CR ", {8'h00, mon[5]}, 16'h000D);
    check16("PC got LF ", {8'h00, mon[6]}, 16'h000A);
    check16("LED[7:0] = last char (LF)", {8'h00, led[7:0]}, 16'h000A);

    $display("\n=== STEP 3: hardware self-test, btnR (internal loopback) ===");
    press(3);  wait_idle;
    check16("LED[9:0] all PASS     ", {6'd0, led[9:0]}, 16'h03FF);
    check16("LED[15:14] done+allOK ", {14'd0, led[15:14]}, 16'h0003);
    settle;
    check16("7-seg [sent|passed] dec", shown, 16'h1010);

    $display("\n=== STEP 4: btnD clear ===");
    press(4);  #(BIT);
    check16("LEDs cleared  ", led, 16'h0000);
    settle;
    check16("7-seg cleared ", shown, 16'h0000);

    $display("\n=== STEP 5: jumper wire plugged  (sw[8]=1) single byte 0x5A ===");
    jumper = 1;  sw[8] = 1;  sw[7:0] = 8'h5A;
    press(0);  wait_idle;
    check16("LED[7:0] via the wire", {8'h00, led[7:0]}, 16'h005A);

    $display("\n=== STEP 6: self-test over the wire (plugged) ===");
    press(3);  wait_idle;
    check16("LED[9:0] all PASS", {6'd0, led[9:0]}, 16'h03FF);
    check16("LED[15:14]       ", {14'd0, led[15:14]}, 16'h0003);

    $display("\n=== STEP 7: PULL THE WIRE OUT, repeat self-test (must FAIL) ===");
    jumper = 0;
    press(4);  #(BIT);
    press(3);  wait_idle;
    check16("LED[9:0] all FAIL     ", {6'd0, led[9:0]}, 16'h0000);
    check16("LED[15:14] done, !ok  ", {14'd0, led[15:14]}, 16'h0001);
    settle;
    check16("7-seg [sent|passed]   ", shown, 16'h1000);

    $display("\n=== STEP 8: PC types 'K' (0x4B) -> FPGA receives, sw[9]=1 ===");
    jumper = 0;  sw[8] = 0;  press(4);  #(BIT);
    sw[9] = 1;
    pc_send(8'h4B, 1'b1);  #(BIT);
    check16("LED[15:8] = PC byte", {8'h00, led[15:8]}, 16'h004B);
    settle;
    check16("7-seg [PC byte|count]", shown, 16'h4B01);

    $display("\n=== STEP 9: ECHO  (sw[10]=1)  PC types 'Z' -> comes back ===");
    sw[10] = 1;
    mon_n = 0;
    pc_send(8'h5A + 8'h00, 1'b1);       // 'Z' = 0x5A
    wait_idle;  #(BIT * 12);
    check16("echo bytes received by PC", mon_n, 1);
    check16("echoed byte               ", {8'h00, mon[0]}, 16'h005A);
    sw[10] = 0;

    $display("\n=== STEP 10: framing error (stop bit forced LOW) ===");
    pc_send(8'h77, 1'b0);  #(BIT);
    settle;
    check16("decimal point lit (left digit)", {15'd0, dpv[3]}, 16'h0001);

    $display("\n=======================================================");
    if (errors == 0) $display(" ALL %0d CHECKS PASSED", checks);
    else             $display(" %0d OF %0d CHECKS FAILED", errors, checks);
    $display("=======================================================\n");
    $finish;
end

// safety net
initial begin
    #200_000_000;
    $display("TIMEOUT");
    $finish;
end

endmodule
