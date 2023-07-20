module Req_FIFO #(
    parameter DATA_WIDTH=6,
              DEPTH=8
)(
    input clk,
    input rst_n,
    input Wen_1st,//write the first data into fifo
    input wen_2nd,//write the second data into fifo
    input Ren,
    input [DATA_WIDTH-1:0] din1,
    input [DATA_WIDTH-1:0] din2,
    output [DATA_WIDTH-1:0] dout,
    output Empty
);
    reg [$clog2(DEPTH):0] Wr_ptr1, Wr_ptr2, Rd_Ptr;//n+1 bits pointer
    reg [DATA_WIDTH-1:0] fifo_mem [DEPTH-1:0];
    wire Full;
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)begin
            Wr_ptr1<='b0;
            Wr_ptr2<='b1;
            Rd_Ptr<='b0;
        end else begin
            if(Wen_1st&&wen_2nd)begin//if two write enable signals are both 1, it means two request wants to send to the same fifo at the same time
                Wr_ptr1<=Wr_ptr1+2;
                Wr_ptr2<=Wr_ptr2+2;
            end else if(Wen_1st||wen_2nd) begin//ohterwise only one request
                Wr_ptr1<=Wr_ptr1+1;
                Wr_ptr2<=Wr_ptr2+1;
            end 
            //////////
            if(Ren)begin
                Rd_Ptr<=Rd_Ptr+1;
            end
        end
    end
    ////////////////
    always@(posedge clk)begin
        if(Wen_1st&&wen_2nd)begin
            fifo_mem[Wr_ptr1[$clog2(DEPTH)-1:0]]<=din1;
            fifo_mem[Wr_ptr2[$clog2(DEPTH)-1:0]]<=din2;
        end else if(Wen_1st||wen_2nd) begin
            if(Wen_1st)begin
                fifo_mem[Wr_ptr1[$clog2(DEPTH)-1:0]]<=din1;
            end else  begin
                fifo_mem[Wr_ptr1[$clog2(DEPTH)-1:0]]<=din2;
            end
        end 
    end
    assign dout=fifo_mem[Rd_Ptr[$clog2(DEPTH)-1:0]];
    assign Full=((Wr_ptr1^Rd_Ptr)=={1'b1,{$clog2(DEPTH){1'b0}}})?1'b1:1'b0;
    assign Empty=((Wr_ptr1^Rd_Ptr)=={1'b0,{$clog2(DEPTH){1'b0}}})?1'b1:1'b0;
endmodule
