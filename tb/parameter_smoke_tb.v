`timescale 1ns/1ps

module parameter_smoke_tb;
    reg clk = 0;
    reg rst = 0;
    reg wr_en = 0;
    reg rd_en = 0;
    reg [15:0] din = 0;
    wire [15:0] dout;
    wire full, empty;
    wire [$clog2(8+1)-1:0] count;

    integer failures = 0;

    sync_fifo #(.WIDTH(16), .DEPTH(8)) dut (
        .clk(clk), .rst(rst), .wr_en(wr_en), .rd_en(rd_en),
        .din(din), .dout(dout), .full(full), .empty(empty), .count(count)
    );

    always #5 clk = ~clk;

    task fail(input [8*80-1:0] msg);
        begin
            failures = failures + 1;
            $display("FAIL: %0s", msg);
        end
    endtask

    initial begin
        @(negedge clk); rst = 1;
        @(posedge clk); #1;
        rst = 0;

        if (!empty || full || count != 0) fail("parameterized reset");

        @(negedge clk); wr_en = 1; din = 16'h1234;
        @(posedge clk); #1;
        @(negedge clk); wr_en = 0; rd_en = 1;
        @(posedge clk); #1;
        if (dout != 16'h1234) fail("parameterized data path");

        @(negedge clk); rd_en = 0;
        if (failures == 0)
            $display("PARAMETER SMOKE PASSED: WIDTH=16 DEPTH=8");
        else
            $display("PARAMETER SMOKE FAILED: %0d failures", failures);

        $finish;
    end
endmodule
