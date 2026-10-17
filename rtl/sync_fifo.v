// sync_fifo.v
// Parameterized synchronous FIFO.
// Author: Harchalar Yogendran
`timescale 1ns/1ps

module sync_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16,
    parameter COUNT_WIDTH = $clog2(DEPTH+1)
) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 wr_en,
    input  wire                 rd_en,
    input  wire [WIDTH-1:0]     din,
    output reg  [WIDTH-1:0]     dout,
    output wire                 full,
    output wire                 empty,
    output reg  [COUNT_WIDTH-1:0] count
);

    // DEPTH must be at least 2 for this pointer implementation.
    localparam PTR_WIDTH = (DEPTH <= 2) ? 1 : $clog2(DEPTH);
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [PTR_WIDTH-1:0] wr_ptr;
    reg [PTR_WIDTH-1:0] rd_ptr;

    initial begin
        if (DEPTH < 2) begin
            $error("sync_fifo DEPTH must be at least 2");
            $finish;
        end
    end

    assign empty = (count == 0);
    assign full  = (count == DEPTH);

    // A write is accepted only when not full; a read only when not empty.
    // When both are requested with one item available, both occur.
    // When full, a simultaneous read/write accepts only the read; the write
    // is rejected because full is evaluated from the pre-edge occupancy.
    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
            dout   <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wr_ptr] <= din;
                if (wr_ptr == DEPTH-1)
                    wr_ptr <= 0;
                else
                    wr_ptr <= wr_ptr + 1'b1;
            end

            if (rd_en && !empty) begin
                dout <= mem[rd_ptr];
                if (rd_ptr == DEPTH-1)
                    rd_ptr <= 0;
                else
                    rd_ptr <= rd_ptr + 1'b1;
            end

            case ({wr_en && !full, rd_en && !empty})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule
