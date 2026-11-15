`timescale 1ns / 1ps
//=========================================================
// Module  : basys3_top            Board: Digilent Basys 3 (XC7A35T)
// Purpose : Hardware demonstration wrapper for the UART project.
//
//  SWITCHES                           BUTTONS
//   sw[7:0]  data byte to send         btnC  send sw[7:0] as one byte
//   sw[8]    RX source:                btnL  send the word "UART\r\n"
//             0 = internal loopback    btnR  hardware SELF-TEST
//             1 = jumper wire JA1->JA2        (the 10 testbench vectors,
//   sw[9]    7-seg view:                       compared on-chip)
//             0 = TX byte | RX byte    btnD  CLEAR display / results
//             1 = PC byte | PC count   btnU  soft RESET of the demo logic
//   sw[10]   ECHO: PC -> FPGA -> PC
//
//  LEDs   (normal)    LED[7:0]  = last byte received by the project's RX
//                     LED[15:8] = last byte received from the PC
//         (self-test) LED[7:0] = last received byte
//                     LED[8]   = at least one failure
//                     LED[9]   = test engine active
//                     LED[14]  = test finished
//                     LED[15]  = all 272 checks passed
//
//  7-SEG  (normal)    [TX byte hex][RX byte hex]
//         (self-test) [tests completed, decimal][failure count]
//         decimal point of the leftmost digit = PC framing error seen
//
//  Serial pins: RsTx / RsRx  = USB-UART to the PC (PuTTY)
//               ja_tx / ja_rx = Pmod JA pins 1 and 2 (jumper loopback)
//=========================================================
module basys3_top #(
    parameter CLK_FREQ        = 100_000_000,   // Basys 3 clock
    parameter DEBOUNCE_CYCLES = 2_000_000,     // 20 ms
    parameter GAP_CYCLES      = 30_000_000     // 300 ms between demo bytes
)(
    input  wire        clk,
    input  wire [15:0] sw,
    input  wire        btnC, btnU, btnL, btnR, btnD,
    output wire [15:0] led,
    output wire [6:0]  seg,
    output wire        dp,
    output wire [3:0]  an,
    output wire        RsTx,
    input  wire        RsRx,
    output wire        ja_tx,
    input  wire        ja_rx
);

// ---------------------------------------------------------
// 1. Button conditioning (debounce + one-shot)
// ---------------------------------------------------------
wire p_send, p_rst, p_str, p_test, p_clr;
debounce_oneshot #(.CYCLES(DEBOUNCE_CYCLES)) db_c (.clk(clk), .btn(btnC), .pulse(p_send));
debounce_oneshot #(.CYCLES(DEBOUNCE_CYCLES)) db_u (.clk(clk), .btn(btnU), .pulse(p_rst));
debounce_oneshot #(.CYCLES(DEBOUNCE_CYCLES)) db_l (.clk(clk), .btn(btnL), .pulse(p_str));
debounce_oneshot #(.CYCLES(DEBOUNCE_CYCLES)) db_r (.clk(clk), .btn(btnR), .pulse(p_test));
debounce_oneshot #(.CYCLES(DEBOUNCE_CYCLES)) db_d (.clk(clk), .btn(btnD), .pulse(p_clr));

// ---------------------------------------------------------
// 2. The UART project core (TX + baud_gen + RX)
// ---------------------------------------------------------
reg        start = 1'b0;
reg  [7:0] txin  = 8'd0;
reg        busy  = 1'b0;          // a frame is in flight

wire       tx_line;
wire       txdone, rxdone;
wire [7:0] rxout;

// jumper-wire input synchroniser
reg ja_s1 = 1'b1, ja_s2 = 1'b1;
always @(posedge clk) begin
    ja_s1 <= ja_rx;
    ja_s2 <= ja_s1;
end

// RX source select. The project's RX takes its timing from the TX-side baud
// tick, so its input is parked HIGH (idle) whenever no frame is in flight.
wire rx_sel  = sw[8] ? ja_s2 : tx_line;
wire rx_line = busy ? rx_sel : 1'b1;

uart_top #(.clk_value(CLK_FREQ), .baud(9600)) u_uart (
    .clk   (clk),
    .start (start),
    .txin  (txin),
    .rx    (rx_line),
    .tx    (tx_line),
    .rxout (rxout),
    .rxdone(rxdone),
    .txdone(txdone)
);

always @(posedge clk) begin
    if (start)       busy <= 1'b1;
    else if (txdone) busy <= 1'b0;
end

assign RsTx  = tx_line;     // to the PC through the USB-UART bridge
assign ja_tx = tx_line;     // to Pmod JA1 (jumper to JA2 for the wire demo)

// ---------------------------------------------------------
// 3. Receiver for bytes typed on the PC (self-timed)
// ---------------------------------------------------------
wire [7:0] pc_data;
wire       pc_done, pc_ferr;
uart_rx_async #(.clk_value(CLK_FREQ), .baud(9600)) u_pc_rx (
    .clk      (clk),
    .rx_in    (RsRx),
    .data     (pc_data),
    .done     (pc_done),
    .frame_err(pc_ferr)
);

// ---------------------------------------------------------
// 4. Message ROMs
// ---------------------------------------------------------
function [7:0] str_rom(input [3:0] i);
    case (i)
        4'd0: str_rom = 8'h55;   // 'U'
        4'd1: str_rom = 8'h41;   // 'A'
        4'd2: str_rom = 8'h52;   // 'R'
        4'd3: str_rom = 8'h54;   // 'T'
        4'd4: str_rom = 8'h0D;   // CR
        default: str_rom = 8'h0A; // LF
    endcase
endfunction

// Comprehensive test ROM:
//   0..255   : every possible 8-bit value (includes 7-bit ASCII 00..7F)
//   256..263 : bit-transition patterns
//   264..271 : consecutive printable bytes "HELLO123"
function [7:0] test_rom(input [8:0] i);
    begin
        if (i <= 9'd255)
            test_rom = i[7:0];
        else begin
            case (i)
                9'd256: test_rom = 8'h00;
                9'd257: test_rom = 8'hFF;
                9'd258: test_rom = 8'h55;
                9'd259: test_rom = 8'hAA;
                9'd260: test_rom = 8'hF0;
                9'd261: test_rom = 8'h0F;
                9'd262: test_rom = 8'h81;
                9'd263: test_rom = 8'h18;
                9'd264: test_rom = 8'h48; // H
                9'd265: test_rom = 8'h45; // E
                9'd266: test_rom = 8'h4C; // L
                9'd267: test_rom = 8'h4C; // L
                9'd268: test_rom = 8'h4F; // O
                9'd269: test_rom = 8'h31; // 1
                9'd270: test_rom = 8'h32; // 2
                default: test_rom = 8'h33; // 3
            endcase
        end
    end
endfunction

// ---------------------------------------------------------
// 5. Demo controller (one request at a time)
// ---------------------------------------------------------
localparam C_IDLE = 3'd0, C_FIRE = 3'd1, C_LAUNCH = 3'd2,
           C_WAIT = 3'd3, C_CHECK = 3'd4, C_GAP    = 3'd5;
localparam M_NONE = 3'd0, M_SINGLE = 3'd1, M_STR = 3'd2,
           M_TEST = 3'd3, M_ECHO   = 3'd4;

reg [2:0] cs   = C_IDLE;
reg [2:0] mode = M_NONE;
reg [8:0] idx  = 9'd0;  // 0..271 test item index
reg [7:0] cur  = 8'd0;
integer   gap_cnt = 0;

reg [7:0] tx_last = 8'd0;
reg [7:0] rx_last = 8'd0;
reg [7:0] rx_cnt  = 8'd0;
reg       got_rx  = 1'b0;

reg [8:0] pass       = 9'd0; // maximum 272
reg [8:0] tested     = 9'd0; // maximum 272
reg [8:0] fail_count = 9'd0;
reg       fail_seen  = 1'b0;
reg       st_show    = 1'b0;
reg       test_done  = 1'b0;

reg       echo_req  = 1'b0;
reg [7:0] echo_byte = 8'd0;
reg [7:0] pc_last   = 8'd0;
reg [7:0] pc_cnt    = 8'd0;
reg       fe_latch  = 1'b0;

wire test_ok   = got_rx && (rx_last == cur);
integer gap_lim;
// Keep the comprehensive sweep fast: only the human-readable UART word
// uses the long inter-character pause. The test engine waits just 16 clocks.
always @(*) gap_lim = (mode == M_STR) ? GAP_CYCLES : 16;

always @(posedge clk) begin
    start <= 1'b0;

    // ---- capture what the project's RX delivers ----
    if (rxdone) begin
        rx_last <= rxout;
        rx_cnt  <= rx_cnt + 8'd1;
        got_rx  <= 1'b1;
    end

    // ---- capture what the PC sends ----
    if (pc_done) begin
        pc_last <= pc_data;
        pc_cnt  <= pc_cnt + 8'd1;
        if (pc_ferr) fe_latch <= 1'b1;
        if (sw[10]) begin
            echo_req  <= 1'b1;
            echo_byte <= pc_data;
        end
    end

    // ---- request sequencer ----
    case (cs)

        C_IDLE: if (!busy) begin
            if (p_test) begin
                mode <= M_TEST;  idx <= 9'd0;  cur <= test_rom(9'd0);
                st_show <= 1'b1; test_done <= 1'b0;
                pass <= 9'd0; tested <= 9'd0;
                fail_count <= 9'd0; fail_seen <= 1'b0;
                cs <= C_FIRE;
            end else if (p_str) begin
                mode <= M_STR;   idx <= 4'd0;  cur <= str_rom(4'd0);
                cs <= C_FIRE;
            end else if (p_send) begin
                mode <= M_SINGLE; cur <= sw[7:0];
                cs <= C_FIRE;
            end else if (echo_req) begin
                mode <= M_ECHO;  cur <= echo_byte;  echo_req <= 1'b0;
                cs <= C_FIRE;
            end
        end

        C_FIRE: begin                       // load TX and pulse start
            txin    <= cur;
            start   <= 1'b1;
            tx_last <= cur;
            got_rx  <= 1'b0;
            cs      <= C_LAUNCH;
        end

        C_LAUNCH: if (busy) cs <= C_WAIT;   // TX accepted the byte

        C_WAIT: if (!busy) cs <= C_CHECK;   // frame finished (txdone)

        C_CHECK: begin
            if (mode == M_TEST) begin
                if (test_ok) pass <= pass + 9'd1;
                else begin
                    fail_count <= fail_count + 9'd1;
                    fail_seen <= 1'b1;
                end
                tested <= idx + 9'd1;
            end
            gap_cnt <= 0;
            cs      <= C_GAP;
        end

        C_GAP: begin
            if (gap_cnt >= gap_lim) begin
                gap_cnt <= 0;
                case (mode)
                    M_STR: begin
                        if (idx == 4'd5) cs <= C_IDLE;
                        else begin idx <= idx + 4'd1; cur <= str_rom(idx + 4'd1); cs <= C_FIRE; end
                    end
                    M_TEST: begin
                        if (idx == 9'd271) begin test_done <= 1'b1; cs <= C_IDLE; end
                        else begin
                            idx <= idx + 9'd1;
                            cur <= test_rom(idx + 9'd1);
                            cs <= C_FIRE;
                        end
                    end
                    default: cs <= C_IDLE;
                endcase
            end else begin
                gap_cnt <= gap_cnt + 1;
            end
        end

        default: cs <= C_IDLE;
    endcase

    // ---- btnD : clear display and results ----
    if (p_clr) begin
        st_show <= 1'b0;  test_done <= 1'b0;
        pass <= 9'd0; tested <= 9'd0;
        fail_count <= 9'd0; fail_seen <= 1'b0;
        tx_last <= 8'd0;  rx_last <= 8'd0;  rx_cnt <= 8'd0;
        pc_last <= 8'd0;  pc_cnt <= 8'd0;   fe_latch <= 1'b0;
        echo_req <= 1'b0;
    end

    // ---- btnU : soft reset of the demo sequencer ----
    if (p_rst) begin
        cs <= C_IDLE;  mode <= M_NONE;  echo_req <= 1'b0;
    end
end

// ---------------------------------------------------------
// 6. LEDs and 7-segment display
// ---------------------------------------------------------
assign led = st_show ? {(test_done && fail_count == 9'd0), test_done,
                         4'b0000, (cs != C_IDLE), fail_seen, rx_last}
                     : {pc_last, rx_last};

// Convert a 0..272 test count to three decimal digits.
function [11:0] to_bcd3(input [8:0] v);
    integer n;
    begin
        n = v;
        to_bcd3[11:8] = n / 100;
        to_bcd3[7:4]  = (n % 100) / 10;
        to_bcd3[3:0]  = n % 10;
    end
endfunction

wire [15:0] disp_value =
    st_show ? {to_bcd3(tested), (fail_count > 9 ? 4'hF : fail_count[3:0])} :
    sw[9]   ? {pc_last, pc_cnt} :
              {tx_last, rx_last};

seg7_driver u_seg (
    .clk   (clk),
    .value (disp_value),
    .dp_on ({fe_latch, 3'b000}),
    .seg   (seg),
    .dp    (dp),
    .an    (an)
);

endmodule
