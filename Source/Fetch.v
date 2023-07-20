`timescale 1ns/100ps
module Fetch #(
    parameter DATA = 32,
              ADDR = 10,
              Test = "16x16_Matrix_Multiply"
)(
    input clk,
    input rst_n,
    input Uart_clk,
    input IC_Init,//for debug
    input Init_Done,
    input [ADDR-1:0] IC_Init_Addr,
    input [DATA-1:0] IC_Init_Data,
    input [ADDR-1:0] IC_WriteBack_Addr,
    output [DATA-1:0] IC_WriteBack_Data,
    input [31:0] WS_IF_PC_Warp0,
    input [31:0] WS_IF_PC_Warp1,
    input [7:0] WS_IF_Active_Mask0,
    input [7:0] WS_IF_Active_Mask1,
    input [7:0] WS_IF_WarpID0,
    input [7:0] WS_IF_WarpID1,
    input [31:0] WS_IF_PC0_Plus4,
    input [31:0] WS_IF_PC1_Plus4,
    ///////////////////////////////////////
    //the flush signal from Warp Scheduler when a stall or update signal is active in ID stage, the instruction in IF stage which belongs to those warps to be flushed should be flushed
    input Flush_IF,
    input [7:0] Flush_Warp,
    ///////////////////////////////////////
    output [31:0] IF_ID0_Instruction,
    output [31:0] IF_ID1_Instruction,
    output reg [7:0] IF_ID0_Active_Mask,
    output reg [7:0] IF_ID1_Active_Mask,
    output reg [7:0] IF_ID0_WarpID,
    output reg [7:0] IF_ID1_WarpID,
    output reg [31:0] IF_ID0_PC_Plus4,
    output reg [31:0] IF_ID1_PC_Plus4
);
    wire [ADDR-1:0] IC_Debug_Addr=(!Init_Done)?IC_Init_Addr:IC_WriteBack_Addr;
    //true dual port bram pipelined, the output register is used as the stage register IF/ID
    //two port used for reading instruction s 
   
   Dual_Port_Bram #(.Test(Test)) I_Cache1(
        .clka(Uart_clk),
        .wena(IC_Init),
        .addra(IC_Debug_Addr),
        .dina(IC_Init_Data),
        .douta(IC_WriteBack_Data),
    //
        .clkb(clk),
        .addrb(WS_IF_PC_Warp0[11:2]),
        .dinb(),
        .doutb(IF_ID0_Instruction)
    );

    Dual_Port_Bram #(.Test(Test)) I_Cache2(
        .clka(Uart_clk),
        .wena(IC_Init),
        .addra(IC_Init_Addr),
        .dina(IC_Init_Data),
        .douta(),
    //
        .clkb(clk),
        .addrb(WS_IF_PC_Warp1[11:2]),
        .dinb(),
        .doutb(IF_ID1_Instruction)
    );
    //////////////////////////////////////////////
    //stage regsiter for storing active mask and warp id
    reg [7:0] IF_WarpID0, IF_WarpID1;//can also be used as valid bits
    reg [7:0] IF_Active_Mask0, IF_Active_Mask1;
    reg [31:0] IF_PC0_Plus4, IF_PC1_Plus4;
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            IF_WarpID0<='b0;
            IF_WarpID1<='b0;
            IF_ID0_WarpID<='b0;
            IF_ID1_WarpID<='b0;
            IF_Active_Mask0<='bx;
            IF_Active_Mask1<='bx;
            IF_ID0_Active_Mask<='bx;
            IF_ID1_Active_Mask<='bx;
            IF_PC0_Plus4<='bx;
            IF_PC1_Plus4<='bx;
            IF_ID0_PC_Plus4<='bx;
            IF_ID1_PC_Plus4<='bx;
        end else begin
            //if a flush occurs, the input warp id are those which has been flushed
            //so we just need to take care of the update of the second warp id regsiter
            IF_WarpID0<=WS_IF_WarpID0;
            IF_WarpID1<=WS_IF_WarpID1;
            IF_Active_Mask0<=WS_IF_Active_Mask0;
            IF_Active_Mask1<=WS_IF_Active_Mask1;
            IF_ID0_Active_Mask<=IF_Active_Mask0;
            IF_ID1_Active_Mask<=IF_Active_Mask1;
            IF_PC0_Plus4<=WS_IF_PC0_Plus4;
            IF_PC1_Plus4<=WS_IF_PC1_Plus4;
            IF_ID0_PC_Plus4<=IF_PC0_Plus4;
            IF_ID1_PC_Plus4<=IF_PC1_Plus4;
            if(!Flush_IF)begin
                IF_ID0_WarpID<=IF_WarpID0;
                IF_ID1_WarpID<=IF_WarpID1;
            end else begin
                IF_ID0_WarpID<=(~Flush_Warp)&IF_WarpID0;
                IF_ID1_WarpID<=(~Flush_Warp)&IF_WarpID1;
            end
        end
    end
endmodule  
