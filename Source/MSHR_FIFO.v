`timescale 1ns/100ps
module MSHR_FIFO #(
    parameter DEPTH=8,
              DATA_WIDTH=74
)(
    input clk,
    input rst_n,
    input wen,
    input ren,
    input [DATA_WIDTH-1:0] din,
    output [DATA_WIDTH-1:0] dout,
    output Full,
    output Empty 
);
    reg [DATA_WIDTH-1:0] mem_fifo [DEPTH-1:0]; //1bit lw/swbar, 27bit cache line address, 24 bit word access address, 3bit warp ID, 3bit latency, 8bit active mask, 1bit release sb valid, 2bit sb release entry number
    //since this fifo is used to analog the mshr for dealing with cache miss
    //the data is fetched out from data cache and stored into this fifo, when latency counter
    //is counted to 0, means cache miss is solved, then the data can be sent to WB stage 
    reg [$clog2(DEPTH):0] Wr_Ptr, Rd_Ptr;
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            Wr_Ptr<='b0;
            Rd_Ptr<='b0;
        end else begin
            if(wen)begin
                Wr_Ptr<=Wr_Ptr+1;
            end
            //
            if(ren)begin
                Rd_Ptr<=Rd_Ptr+1;
            end
        end
    end
    ///////////
    always @(posedge clk) begin
        if(wen)begin
            mem_fifo[Wr_Ptr[$clog2(DEPTH)-1:0]]<=din;
        end
    end
    assign dout=mem_fifo[Rd_Ptr[$clog2(DEPTH)-1:0]];
    assign Full=(Wr_Ptr^Rd_Ptr)=={1'b1,{$clog2(DEPTH){1'b0}}}?1'b1:1'b0;
    assign Empty=(Wr_Ptr^Rd_Ptr)=={1'b0,{$clog2(DEPTH){1'b0}}}?1'b1:1'b0;
endmodule 
