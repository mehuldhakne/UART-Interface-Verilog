`timescale 1ns / 1ps
//=========================================================
// tb : loopback testbench, File I/O test vectors, self-checking
//
//  * reads 10 predefined bytes from test_vectors.txt ($readmemh)
//  * sends each through uart_top (tx wired back to rx)
//  * compares rxout with txin the moment rxdone pulses
//  * prints PASS / FAIL per byte and a final summary
//
//  CLK_VALUE = 100_000   -> scaled clock, 10 clocks per bit (fast sim,
//                           same as the submitted report)
//  CLK_VALUE = 100_000_000 -> real Basys 3 timing (10416 clocks per bit)
//=========================================================
module tb;

parameter CLK_VALUE = 100_000;            // change to 100_000_000 for real timing
parameter VEC_FILE  = "test_vectors.txt"; // put the file in the xsim folder, or give a full path

reg        clk   = 0;
reg        start = 0;
reg  [7:0] txin  = 0;
wire [7:0] rxout;
wire       rxdone, txdone;
wire       txrx;                          // loopback wire

uart_top #(.clk_value(CLK_VALUE)) dut (
    .clk(clk), .start(start), .txin(txin),
    .rx(txrx), .tx(txrx),
    .rxout(rxout), .rxdone(rxdone), .txdone(txdone)
);

reg [7:0] test_data [0:9];
integer i;
integer pass_count = 0;
integer fail_count = 0;

always #5 clk = ~clk;                     // 100 MHz

initial begin
    $readmemh(VEC_FILE, test_data);
    start = 1;                            // TX restarts as soon as it is idle

    for (i = 0; i < 10; i = i + 1) begin
        txin = test_data[i];
        @(posedge rxdone);                // rxout is valid exactly while rxdone = 1
        if (rxout === txin) begin
            pass_count = pass_count + 1;
            $display("Test %0d: TX=0x%02h  RX=0x%02h  PASS", i, txin, rxout);
        end else begin
            fail_count = fail_count + 1;
            $display("Test %0d: TX=0x%02h  RX=0x%02h  FAIL ***", i, txin, rxout);
        end
    end

    $display("----------------------------------------");
    $display("PASSED: %0d / 10    FAILED: %0d / 10", pass_count, fail_count);
    $stop;
end

endmodule
