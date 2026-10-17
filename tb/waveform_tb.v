// waveform_tb.v
// Short directed sequence used to produce the README waveform (docs/waveform.png).
// Not self-checking; sync_fifo_tb.v does the verification.
// Author: Harchalar Yogendran
//
// Sequence (DEPTH=4):
//   1. reset
//   2. write A1..A4            -> count 1..4, full rises
//   3. write EE while full     -> rejected, count stays 4
//   4. read + write B1 at full -> only the read happens (A1 out), count 3
//   5. read + write B2, B3     -> both happen, count stays 3
//   6. drain                   -> A4, B2, B3 out (B1 was never stored), empty rises
//   7. read while empty        -> rejected, dout holds B3
`timescale 1ns/1ps

module waveform_tb;
    localparam WIDTH = 8;
    localparam DEPTH = 4;

    reg clk = 0;
    reg rst = 0;
    reg wr_en = 0;
    reg rd_en = 0;
    reg [WIDTH-1:0] din = 0;

    wire [WIDTH-1:0] dout;
    wire full;
    wire empty;
    wire [$clog2(DEPTH+1)-1:0] count;

    integer i;

    sync_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
        .clk(clk), .rst(rst), .wr_en(wr_en), .rd_en(rd_en),
        .din(din), .dout(dout), .full(full), .empty(empty), .count(count)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("fifo_waveform.vcd");
        $dumpvars(0, waveform_tb);

        // 1. reset
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;

        // 2. fill to full
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk); wr_en = 1; din = 8'hA1 + i;
        end

        // 3. overflow attempt
        @(negedge clk); din = 8'hEE;

        // 4. read + write while full: write rejected
        @(negedge clk); rd_en = 1; din = 8'hB1;

        // 5. read + write in the middle: both accepted
        @(negedge clk); din = 8'hB2;
        @(negedge clk); din = 8'hB3;

        // 6. drain
        @(negedge clk); wr_en = 0; din = 8'h00;
        repeat (2) @(negedge clk);

        // 7. read while empty
        @(negedge clk);
        @(negedge clk); rd_en = 0;
        repeat (2) @(negedge clk);
        $finish;
    end
endmodule
