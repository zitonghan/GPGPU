`timescale 1ns/100ps
module SIMT_Warp(
    input clk,
    input rst_n,
    /////////////////////
    input SIMT_Stack_Push,
    input SIMT_Stack_Pop,
    input [1:0] SIMT_Pushed_Token,
    output [1:0] SIMT_Popped_Token,
    input [31:0] SIMT_Pushed_PC,
    output [31:0] SIMT_Popped_PC,
    input [7:0] SIMT_Pushed_AM,
    output [7:0] SIMT_Popped_AM,
    output SIMT_Full,
    output SIMT_TwoMoreVacant
);
    parameter SYNC=2'b00,
              DIV=2'b01,
              CALL=2'b10;
    /////////////////////////
    reg [41:0] Stack [15:0];//token+pc+am
    reg [4:0] TOSP, TOSP_plus1;//plus1 is the write pointer, the TOSP is the read pointer
    ////////////////////////////////
    //NOTE: if branch has written a sync token into SIMT, we don't need to consider the situation that the branch will occupy 2location,
    //another location is occupied by branch when it comes out from the WB
    //then the full and two more location signals should take accunt of this locatoin to be occupied in advance for the following instruction in the same waarp
    //However, it is unnecessary, since the branch instruction will stall the pc, no other instructions will be fetched out until it comes out from the ALU
    ////////////////////////////////
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            TOSP<=5'b11111;
            TOSP_plus1<=5'b00000;
        end else begin
            //push a new item into SIMT
            if(SIMT_Stack_Push)begin
                Stack[TOSP_plus1][41:40]<=SIMT_Pushed_Token;
                Stack[TOSP_plus1][39:8]<=SIMT_Pushed_PC;
                Stack[TOSP_plus1][7:0]<=SIMT_Pushed_AM;
                TOSP_plus1<=TOSP_plus1+1;
                TOSP<=TOSP+1;
            end
            //////////////
            if(SIMT_Stack_Pop)begin
                TOSP_plus1<=TOSP_plus1-1;
                TOSP<=TOSP-1;
            end
        end
    end
    assign SIMT_Popped_Token=Stack[TOSP][41:40];
    assign SIMT_Popped_PC=Stack[TOSP][39:8];
    assign SIMT_Popped_AM=Stack[TOSP][7:0];
    assign SIMT_Full=(TOSP_plus1==5'b1_0000);
    assign SIMT_TwoMoreVacant=(TOSP_plus1<=5'b0_1110);
endmodule