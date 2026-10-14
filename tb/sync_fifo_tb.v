// sync_fifo_tb.v
// Self-checking testbench for sync_fifo.
// Author: Harchalar Yogendran
`timescale 1ns/1ps

module sync_fifo_tb;
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

    integer failures = 0;
    integer tests = 0;
    integer i;
    reg [WIDTH-1:0] expected;

    reg [WIDTH-1:0] model [0:DEPTH-1];
    integer model_count;
    integer model_wr_ptr;
    integer model_rd_ptr;
    reg write_ok;
    reg read_ok;

    sync_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
        .clk(clk), .rst(rst), .wr_en(wr_en), .rd_en(rd_en),
        .din(din), .dout(dout), .full(full), .empty(empty), .count(count)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sync_fifo_tb.vcd");
        $dumpvars(0, sync_fifo_tb);

        model_count = 0;
        model_wr_ptr = 0;
        model_rd_ptr = 0;

        // Synchronous reset
        @(negedge clk); rst = 1;
        @(posedge clk); #1;
        rst = 0;
        check(count == 0 && empty && !full, "reset state");

        // Fill to capacity and check full/count.
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk); wr_en = 1; din = 8'hA0 + i;
            @(posedge clk); #1;
        end
        @(negedge clk); wr_en = 0;
        check(count == DEPTH && full && !empty, "fill to full");

        // Overflow must be rejected; original four values must remain.
        @(negedge clk); wr_en = 1; din = 8'hEE;
        @(posedge clk); #1;
        check(count == DEPTH && full, "overflow rejected");
        @(negedge clk); wr_en = 0;

        // Drain and check FIFO order, then empty.
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk); rd_en = 1;
            @(posedge clk); #1;
            expected = 8'hA0 + i;
            check(dout == expected, "FIFO order while draining");
        end
        @(negedge clk); rd_en = 0;
        check(count == 0 && empty && !full, "drain to empty");

        // Underflow must not alter the empty state or output.
        expected = dout;
        @(negedge clk); rd_en = 1;
        @(posedge clk); #1;
        check(count == 0 && empty && dout == expected, "underflow rejected");
        @(negedge clk); rd_en = 0;

        // Simultaneous read/write with one item queued.
        @(negedge clk); wr_en = 1; din = 8'h31;
        @(posedge clk); #1;
        @(negedge clk); wr_en = 0; rd_en = 1;
        @(posedge clk); #1;
        check(dout == 8'h31 && count == 0, "read final queued item");

        @(negedge clk); rd_en = 0; wr_en = 1; din = 8'h42;
        @(posedge clk); #1;
        @(negedge clk); wr_en = 1; rd_en = 1; din = 8'h43;
        @(posedge clk); #1;
        check(dout == 8'h42 && count == 1, "simultaneous read/write");

        @(negedge clk); wr_en = 0; rd_en = 1;
        @(posedge clk); #1;
        check(dout == 8'h43 && count == 0,
              "simultaneous operation retained new item");
        @(negedge clk); rd_en = 0;

        // Wrap-around: repeated write/read cycles beyond pointer depth.
        for (i = 0; i < 10; i = i + 1) begin
            @(negedge clk); wr_en = 1; din = i;
            @(posedge clk); #1;
            @(negedge clk); wr_en = 0; rd_en = 1;
            @(posedge clk); #1;
            check(dout == i && count == 0, "pointer wrap-around");
        end
        @(negedge clk); rd_en = 0;

        // Randomized testing with a behavioral reference model.
        @(negedge clk);
        rst = 1;
        wr_en = 0;
        rd_en = 0;
        @(posedge clk); #1;
        rst = 0;

        model_count = 0;
        model_wr_ptr = 0;
        model_rd_ptr = 0;

        for (i = 0; i < 1000; i = i + 1) begin
            wr_en = $urandom_range(0, 1);
            rd_en = $urandom_range(0, 1);
            din   = $urandom;

            // Decide accepted operations from pre-edge occupancy.
            write_ok = wr_en && (model_count < DEPTH);
            read_ok  = rd_en && (model_count > 0);

            @(posedge clk);
            #1;

            if (read_ok) begin
                expected = model[model_rd_ptr];
                check(dout == expected, "randomized FIFO data");

                if (model_rd_ptr == DEPTH-1)
                    model_rd_ptr = 0;
                else
                    model_rd_ptr = model_rd_ptr + 1;
            end

            if (write_ok) begin
                model[model_wr_ptr] = din;

                if (model_wr_ptr == DEPTH-1)
                    model_wr_ptr = 0;
                else
                    model_wr_ptr = model_wr_ptr + 1;
            end

            if (write_ok && !read_ok)
                model_count = model_count + 1;
            else if (!write_ok && read_ok)
                model_count = model_count - 1;

            check(count == model_count, "randomized FIFO count");
            check(full == (model_count == DEPTH), "randomized FIFO full");
            check(empty == (model_count == 0), "randomized FIFO empty");
        end

        wr_en = 0;
        rd_en = 0;

        if (failures == 0) begin
            $display("TEST PASSED: %0d checks", tests);
        end else begin
            $display("TEST FAILED: %0d failures out of %0d checks",
                     failures, tests);
        end
        $finish;
    end

    task check(input condition, input [8*80-1:0] label);
        begin
            tests = tests + 1;
            if (condition !== 1'b1) begin
                failures = failures + 1;
                $display("TEST FAILED: %0s at time %0t", label, $time);
            end
        end
    endtask
endmodule
