// sync_fifo_tb.v
// Self-checking testbench for sync_fifo.
// Author: Harchalar Yogendran
//
// WIDTH and DEPTH are parameters so the same testbench runs on several
// configurations (see the Makefile sweep), e.g.
//   iverilog -g2012 -Psync_fifo_tb.DEPTH=5 ...
// Directed tests use 8-bit patterns, so keep WIDTH >= 8.
`timescale 1ns/1ps

module sync_fifo_tb;
    parameter WIDTH = 8;
    parameter DEPTH = 4;
    parameter RANDOM_CYCLES = 4000;

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
    reg [WIDTH-1:0] prev_dout;
    integer wr_pct;
    integer rd_pct;

    // Functional coverage: how often each corner case was exercised by the
    // randomized test. The run fails if any of these is never hit.
    integer cov_full        = 0;  // cycles spent full
    integer cov_wr_full     = 0;  // write attempted while full (overflow)
    integer cov_rd_empty    = 0;  // read attempted while empty (underflow)
    integer cov_rw_mid      = 0;  // read+write while neither full nor empty
    integer cov_rw_full     = 0;  // read+write while full
    integer cov_rw_empty    = 0;  // read+write while empty

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

        // Reset while the FIFO holds data must clear it.
        for (i = 0; i < 2; i = i + 1) begin
            @(negedge clk); wr_en = 1; din = 8'h50 + i;
            @(posedge clk); #1;
        end
        @(negedge clk); wr_en = 0;
        check(count == 2 && !empty, "data present before reset");
        @(negedge clk);
        rst = 1;
        wr_en = 0;
        rd_en = 0;
        @(posedge clk); #1;
        rst = 0;
        check(count == 0 && empty && !full, "reset with data clears FIFO");

        // After that reset, old data must not come back out.
        @(negedge clk); wr_en = 1; din = 8'h77;
        @(posedge clk); #1;
        @(negedge clk); wr_en = 0; rd_en = 1;
        @(posedge clk); #1;
        check(dout == 8'h77 && count == 0, "fresh data after reset");
        @(negedge clk); rd_en = 0;
        @(posedge clk); #1;

        // Randomized testing with a behavioral reference model.
        // The run is split into phases with different read/write
        // probabilities, so large FIFOs still reach full and empty:
        //   balanced (50/50), write-heavy (80/20), read-heavy (20/80).

        model_count = 0;
        model_wr_ptr = 0;
        model_rd_ptr = 0;

        for (i = 0; i < RANDOM_CYCLES; i = i + 1) begin
            case ((i / 250) % 3)
                0: begin wr_pct = 50; rd_pct = 50; end
                1: begin wr_pct = 80; rd_pct = 20; end
                default: begin wr_pct = 20; rd_pct = 80; end
            endcase

            wr_en = ($urandom_range(0, 99) < wr_pct);
            rd_en = ($urandom_range(0, 99) < rd_pct);
            din   = $urandom;

            // Decide accepted operations from pre-edge occupancy.
            write_ok = wr_en && (model_count < DEPTH);
            read_ok  = rd_en && (model_count > 0);
            prev_dout = dout;

            // Coverage, sampled from pre-edge state.
            if (model_count == DEPTH)          cov_full     = cov_full + 1;
            if (wr_en && model_count == DEPTH) cov_wr_full  = cov_wr_full + 1;
            if (rd_en && model_count == 0)     cov_rd_empty = cov_rd_empty + 1;
            if (wr_en && rd_en && model_count > 0 && model_count < DEPTH)
                cov_rw_mid = cov_rw_mid + 1;
            if (wr_en && rd_en && model_count == DEPTH)
                cov_rw_full = cov_rw_full + 1;
            if (wr_en && rd_en && model_count == 0)
                cov_rw_empty = cov_rw_empty + 1;

            @(posedge clk);
            #1;

            // dout must only change on an accepted read.
            if (!read_ok)
                check(dout == prev_dout, "dout held when no read");

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

        $display("COVERAGE (WIDTH=%0d DEPTH=%0d, %0d random cycles):",
                 WIDTH, DEPTH, RANDOM_CYCLES);
        $display("  cycles full            : %0d", cov_full);
        $display("  write while full       : %0d", cov_wr_full);
        $display("  read while empty       : %0d", cov_rd_empty);
        $display("  read+write, mid        : %0d", cov_rw_mid);
        $display("  read+write while full  : %0d", cov_rw_full);
        $display("  read+write while empty : %0d", cov_rw_empty);
        check(cov_wr_full  > 0, "coverage: write while full");
        check(cov_rd_empty > 0, "coverage: read while empty");
        check(cov_rw_mid   > 0, "coverage: read+write mid");
        check(cov_rw_full  > 0, "coverage: read+write while full");
        check(cov_rw_empty > 0, "coverage: read+write while empty");

        // $fatal gives a non-zero exit code, so make, CI and the Windows
        // script all see a failure, not just a printed message.
        if (failures == 0) begin
            $display("TEST PASSED: %0d checks", tests);
            $finish;
        end else begin
            $fatal(1, "TEST FAILED: %0d failures out of %0d checks",
                   failures, tests);
        end
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
