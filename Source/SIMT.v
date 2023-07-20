`timescale 1ns/100ps
module SIMT(
    input clk,
    input rst_n,
    ///////////
    //interface with ALU
    input [2:0] WarpID_from_ALU,
    output reg [31:0] SIMT_PCplus4_ALU,
    //还没写
    //interface with ID
    output [7:0] SIMT_Full,
    output [7:0] SIMT_TwoMoreVacant,
    output reg [31:0] SIMT_Poped_PC_ID0,
    output reg [31:0] SIMT_Poped_PC_ID1,
    output reg [7:0] SIMT_Poped_Active_Mask_ID0,
    output reg [7:0] SIMT_Poped_Active_Mask_ID1,
    input [7:0] ID0_Active_Mask_SIMT_IB,
    input [7:0] ID1_Active_Mask_SIMT_IB,
	input DotS_ID0_SIMT,
	input DotS_ID1_SIMT,
    output SIMT_Div_SyncBar_Token_ID0,
    output SIMT_Div_SyncBar_Token_ID1,
	input Call_ID0_SIMT,
	input Call_ID1_SIMT,
	input Ret_ID0_SIMT,
	input Ret_ID1_SIMT,
	input Branch_ID0_SIMT,
	input Branch_ID1_SIMT,
    input [31:0] ID0_PCplus4_SIMT_UpdatePC_WS,
	input [31:0] ID1_PCplus4_SIMT_UpdatePC_WS,
    input [31:0] ID0_Call_ReturnAddr_SIMT,
    input [31:0] ID1_Call_ReturnAddr_SIMT,
    input [7:0] WarpID0_SIMT_IB,
    input [7:0] WarpID1_SIMT_IB,
    ////////////////////
    //interface with WB
    input [2:0] WarpID_from_WB,
    input WB_Update_SIMT,
    input [7:0] WB_AM_SIMT//branch active mask for written into DIV token
);
    parameter SYNC=2'b00,
              DIV=2'b01,
              CALL=2'b10;
    /////////////////////////////////////
    reg [7:0] WB_WarpID_SIMT;//decoded warp id sent from WB stage
    always@(*)begin
        WB_WarpID_SIMT='b0;
        if(WB_Update_SIMT)begin
            case(WarpID_from_WB)
                3'b000:WB_WarpID_SIMT=8'b0000_0001;
                3'b001:WB_WarpID_SIMT=8'b0000_0010;
                3'b010:WB_WarpID_SIMT=8'b0000_0100;
                3'b011:WB_WarpID_SIMT=8'b0000_1000;
                3'b100:WB_WarpID_SIMT=8'b0001_0000;
                3'b101:WB_WarpID_SIMT=8'b0010_0000;
                3'b110:WB_WarpID_SIMT=8'b0100_0000;
                3'b111:WB_WarpID_SIMT=8'b1000_0000;
            endcase
        end
    end
    /////////////////////////////////////
    wire [7:0] SIMT_Stack_Push, SIMT_Stack_Pop;
    wire [1:0] SIMT_Pushed_Token [7:0];
    wire [1:0] SIMT_Popped_Token [7:0];
    wire [31:0] SIMT_Pushed_PC [7:0];
    wire [31:0] SIMT_Popped_PC [7:0];
    wire [7:0] SIMT_Pushed_AM [7:0];
    wire [7:0] SIMT_Popped_AM [7:0];
    /////////////////////////////////////
    //always block for generating output pc for ALU
    always@(*)begin
        case(WarpID_from_ALU)
            3'b001:SIMT_PCplus4_ALU=SIMT_Popped_PC[1];
            3'b010:SIMT_PCplus4_ALU=SIMT_Popped_PC[2];
            3'b011:SIMT_PCplus4_ALU=SIMT_Popped_PC[3];
            3'b100:SIMT_PCplus4_ALU=SIMT_Popped_PC[4];
            3'b101:SIMT_PCplus4_ALU=SIMT_Popped_PC[5];
            3'b110:SIMT_PCplus4_ALU=SIMT_Popped_PC[6];
            3'b111:SIMT_PCplus4_ALU=SIMT_Popped_PC[7];
            default:SIMT_PCplus4_ALU=SIMT_Popped_PC[0];
        endcase
    end
    ////////////////////////////////////
    //flag signal used to record if the branch instruction in processing is .s or not, if it is .s, when it comes out from the WB, and WB_Update_SIMT is 1,
    //then a div token should be written into SIMT, otherwise, it should read out the sync token from the SIMT, since normal branch use aentry to store 
    //PC+4
    reg [7:0] SIMT_Branch_Dots;
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            SIMT_Branch_Dots<='b0;
        end else begin
            SIMT_Branch_Dots<=(SIMT_Branch_Dots|WarpID0_SIMT_IB&{8{Branch_ID0_SIMT&&DotS_ID0_SIMT}}|WarpID1_SIMT_IB&{8{Branch_ID1_SIMT&&DotS_ID1_SIMT}})&~(WB_WarpID_SIMT&{8{WB_Update_SIMT}});
        end
    end
    ////////////////////////////////////
    reg [1:0] SIMT_Poped_Token_ID0, SIMT_Poped_Token_ID1;
    always@(*)begin
        case(WarpID0_SIMT_IB)
            8'b0000_0010:begin
                SIMT_Poped_Token_ID0=SIMT_Popped_Token[1];
                SIMT_Poped_PC_ID0=SIMT_Popped_PC[1];
                SIMT_Poped_Active_Mask_ID0=SIMT_Popped_AM[1];
            end
            8'b0000_0100:begin
                SIMT_Poped_Token_ID0=SIMT_Popped_Token[2];
                SIMT_Poped_PC_ID0=SIMT_Popped_PC[2];
                SIMT_Poped_Active_Mask_ID0=SIMT_Popped_AM[2];
            end
            8'b0000_1000:begin
                SIMT_Poped_Token_ID0=SIMT_Popped_Token[3];
                SIMT_Poped_PC_ID0=SIMT_Popped_PC[3];
                SIMT_Poped_Active_Mask_ID0=SIMT_Popped_AM[3];
            end
            8'b0001_0000:begin
                SIMT_Poped_Token_ID0=SIMT_Popped_Token[4];
                SIMT_Poped_PC_ID0=SIMT_Popped_PC[4];
                SIMT_Poped_Active_Mask_ID0=SIMT_Popped_AM[4];
            end
            8'b0010_0000:begin
                SIMT_Poped_Token_ID0=SIMT_Popped_Token[5];
                SIMT_Poped_PC_ID0=SIMT_Popped_PC[5];
                SIMT_Poped_Active_Mask_ID0=SIMT_Popped_AM[5];
            end
            8'b0100_0000:begin
                SIMT_Poped_Token_ID0=SIMT_Popped_Token[6];
                SIMT_Poped_PC_ID0=SIMT_Popped_PC[6];
                SIMT_Poped_Active_Mask_ID0=SIMT_Popped_AM[6];
            end
            8'b1000_0000:begin
                SIMT_Poped_Token_ID0=SIMT_Popped_Token[7];
                SIMT_Poped_PC_ID0=SIMT_Popped_PC[7];
                SIMT_Poped_Active_Mask_ID0=SIMT_Popped_AM[7];
            end
            default:begin
                SIMT_Poped_Token_ID0=SIMT_Popped_Token[0];
                SIMT_Poped_PC_ID0=SIMT_Popped_PC[0];
                SIMT_Poped_Active_Mask_ID0=SIMT_Popped_AM[0];
            end
        endcase
        /////////////
        case(WarpID1_SIMT_IB)
            8'b0000_0010:begin
                SIMT_Poped_Token_ID1=SIMT_Popped_Token[1];
                SIMT_Poped_PC_ID1=SIMT_Popped_PC[1];
                SIMT_Poped_Active_Mask_ID1=SIMT_Popped_AM[1];
            end
            8'b0000_0100:begin
                SIMT_Poped_Token_ID1=SIMT_Popped_Token[2];
                SIMT_Poped_PC_ID1=SIMT_Popped_PC[2];
                SIMT_Poped_Active_Mask_ID1=SIMT_Popped_AM[2];
            end
            8'b0000_1000:begin
                SIMT_Poped_Token_ID1=SIMT_Popped_Token[3];
                SIMT_Poped_PC_ID1=SIMT_Popped_PC[3];
                SIMT_Poped_Active_Mask_ID1=SIMT_Popped_AM[3];
            end
            8'b0001_0000:begin
                SIMT_Poped_Token_ID1=SIMT_Popped_Token[4];
                SIMT_Poped_PC_ID1=SIMT_Popped_PC[4];
                SIMT_Poped_Active_Mask_ID1=SIMT_Popped_AM[4];
            end
            8'b0010_0000:begin
                SIMT_Poped_Token_ID1=SIMT_Popped_Token[5];
                SIMT_Poped_PC_ID1=SIMT_Popped_PC[5];
                SIMT_Poped_Active_Mask_ID1=SIMT_Popped_AM[5];
            end
            8'b0100_0000:begin
                SIMT_Poped_Token_ID1=SIMT_Popped_Token[6];
                SIMT_Poped_PC_ID1=SIMT_Popped_PC[6];
                SIMT_Poped_Active_Mask_ID1=SIMT_Popped_AM[6];
            end
            8'b1000_0000:begin
                SIMT_Poped_Token_ID1=SIMT_Popped_Token[7];
                SIMT_Poped_PC_ID1=SIMT_Popped_PC[7];
                SIMT_Poped_Active_Mask_ID1=SIMT_Popped_AM[7];
            end
            default:begin
                SIMT_Poped_Token_ID1=SIMT_Popped_Token[0];
                SIMT_Poped_PC_ID1=SIMT_Popped_PC[0];
                SIMT_Poped_Active_Mask_ID1=SIMT_Popped_AM[0];
            end
        endcase
    end

    genvar i;
    generate
        for(i=0;i<8;i=i+1)begin:SIMT_Generate_Block
        //the push signal will be activated when a branch or call instruction in ID stage or Branch in WB stage
            assign SIMT_Stack_Push[i]=WarpID0_SIMT_IB[i]&&(Branch_ID0_SIMT||Call_ID0_SIMT)||WarpID1_SIMT_IB[i]&&(Branch_ID1_SIMT||Call_ID1_SIMT)||WB_WarpID_SIMT[i]&&WB_Update_SIMT&&SIMT_Branch_Dots[i]&&WB_AM_SIMT!=8'h00;  
            //NOTE: the AM to be written into SIMT in WB stage is for untaken instruction, if this mask is all zeros, it means all thread are going to taken direction
            //so that no divergence occurs
            assign SIMT_Stack_Pop[i]=WarpID0_SIMT_IB[i]&&(!Branch_ID0_SIMT&&DotS_ID0_SIMT||Ret_ID0_SIMT)||WarpID1_SIMT_IB[i]&&(!Branch_ID1_SIMT&&DotS_ID1_SIMT||Ret_ID1_SIMT)||WB_WarpID_SIMT[i]&&WB_Update_SIMT&&!SIMT_Branch_Dots[i];
            assign SIMT_Pushed_Token[i]=WarpID0_SIMT_IB[i]?(Branch_ID0_SIMT?SYNC:CALL):(WarpID1_SIMT_IB[i]?(Branch_ID0_SIMT?SYNC:CALL):DIV);
            assign SIMT_Pushed_PC[i]=WarpID0_SIMT_IB[i]?(Branch_ID0_SIMT?ID0_PCplus4_SIMT_UpdatePC_WS:ID0_Call_ReturnAddr_SIMT):(WarpID1_SIMT_IB[i]?(Branch_ID1_SIMT?ID1_PCplus4_SIMT_UpdatePC_WS:ID1_Call_ReturnAddr_SIMT):SIMT_Popped_PC[i]);
            assign SIMT_Pushed_AM[i]=WarpID0_SIMT_IB[i]?ID0_Active_Mask_SIMT_IB:(WarpID1_SIMT_IB[i]?ID1_Active_Mask_SIMT_IB:WB_AM_SIMT);
            //////////////////////////
            SIMT_Warp simt_warp(
                .clk(clk),
                .rst_n(rst_n),
                /////////////////////
                .SIMT_Stack_Push(SIMT_Stack_Push[i]),
                .SIMT_Stack_Pop(SIMT_Stack_Pop[i]),
                .SIMT_Pushed_Token(SIMT_Pushed_Token[i]),
                .SIMT_Popped_Token(SIMT_Popped_Token[i]),
                .SIMT_Pushed_PC(SIMT_Pushed_PC[i]),
                .SIMT_Popped_PC(SIMT_Popped_PC[i]),
                .SIMT_Pushed_AM(SIMT_Pushed_AM[i]),
                .SIMT_Popped_AM(SIMT_Popped_AM[i]),
                .SIMT_Full(SIMT_Full[i]),
                .SIMT_TwoMoreVacant(SIMT_TwoMoreVacant[i])
            ); 
        end
    endgenerate
    //////////////////
    assign SIMT_Div_SyncBar_Token_ID0=(SIMT_Poped_Token_ID0==DIV);
    assign SIMT_Div_SyncBar_Token_ID1=(SIMT_Poped_Token_ID1==DIV);
endmodule
