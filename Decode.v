`timescale 1ns/100ps
module Decode(
    input clk,
    input rst_n,//used for generating Warp release signal
    //interface with IF stage
    input [31:0] IF_ID0_Instruction,
    input  [31:0] IF_ID1_Instruction,
    input [7:0] IF_ID0_Active_Mask,
    input [7:0] IF_ID1_Active_Mask,
    input [7:0] IF_ID0_WarpID,
    input [7:0] IF_ID1_WarpID,
    input [31:0] IF_ID0_PC_Plus4,
    input [31:0] IF_ID1_PC_Plus4,
    ///////////////////
    //interface with I-buffer
    input [7:0] IB_Full, //if the signal is 1, it means the i-buffer only has one free location
    input [7:0] IB_Empty,
    //these two signals is selected by I-buffer according to the warp id of the instruction in ID stage currently
    ////////////
	output reg [5:0] Src1_ID0_IB, //rs regsiter address
	output reg [5:0] Src1_ID1_IB,
	output reg [5:0] Src2_ID0_IB,//rt regsiter address
	output reg [5:0] Src2_ID1_IB,
	output reg [5:0] Dst_ID0_IB,//rt/rd register address
	output reg [5:0] Dst_ID1_IB,
	output [15:0] Imme_ID0_IB, //immediate address
	output [15:0] Imme_ID1_IB,
	output reg RegWrite_ID0_IB,//similar signals in pipelined cpu
	output reg RegWrite_ID1_IB,
	output reg MemWrite_ID0_IB,
	output reg MemWrite_ID1_IB,
	output reg MemRead_ID0_IB,//besides using this signal to access the data cache, this signal is also used to select the correct result to write into register file
	output reg MemRead_ID1_IB,
	output reg [3:0] ALUop_ID0_IB,
	output reg [3:0] ALUop_ID1_IB,
	output reg Share_Globalbar_ID0_IB,//indicate the type of lw, sw instruction, the local memory can be accessed by all threads and threads block, the global memory is used to exchange the data between GPU and CPU
	output reg Share_Globalbar_ID1_IB,
	output reg Imme_Valid_ID0_IB,//used to indicate current instruction is a immediate type
	output reg Imme_Valid_ID1_IB,
    output reg BEQ_ID0_IB,
    output reg BEQ_ID1_IB,
    output reg BLT_ID0_IB,
    output reg BLT_ID1_IB,
    //interfacee with SIMT
    input [7:0] SIMT_Full,
    input [7:0] SIMT_TwoMoreVacant,//two-free location will be used when current instruction in ID is a branch.s
    ////////////////////////////
    //the program counter value sent from SIMT when current instruction is return or .s 
    input [31:0] SIMT_Poped_PC_ID0,
    input [31:0] SIMT_Poped_PC_ID1,
    input [7:0] SIMT_Poped_Active_Mask_ID0,
    input [7:0] SIMT_Poped_Active_Mask_ID1,
    output reg [7:0] ID0_Active_Mask_SIMT_IB,//NOTE: the active mask send back to WS has to be seperated from IB when DIV token is poped out from SIMT 
    output reg [7:0] ID1_Active_Mask_SIMT_IB,//The active mask for IB is current instruction's active mask, but the one for WS the the active mask poped out from SIMT
	output reg DotS_ID0_SIMT,
	output reg DotS_ID1_SIMT,
    input SIMT_Div_SyncBar_Token_ID0,//indicate the token popped out from the SIMT is a sync token or div token
    input SIMT_Div_SyncBar_Token_ID1,//to make sure the warp scheduler's pc updated value
    //NOTE:
    //the .s signal is not needed by I-buffer, since the only use of .s for i-buffer is to indicate a branch.s
    //however, for a normal branch signal, the software has to make sure that the divergence should never happen, otherwise, the program failed
    //for a branch.s we can gather the taken result of each thread to judge if it is a branch.s
    //if no divergence occurs, even if the branch is .s, it will not add div token into SIMT, if divergence occurs, the branch must be .s type
	output reg Call_ID0_SIMT,
	output reg Call_ID1_SIMT,
	output reg Ret_ID0_SIMT,
	output reg Ret_ID1_SIMT,
	output Branch_ID0_SIMT,//only needed by SIMT
	output Branch_ID1_SIMT,
    //All above instructions will cause the pop and push operation of the SIMT stack
    ////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////
    //Interface with Warp Scheduler
    output [7:0] ID_Warp_Release_RAU,
    //////////////////////////////////////////////////////////
    //NOTE: the pc+4 which is used to calculate the branch target address is stored in SIMT instead of I-buffer, so that we can avoid the movement of 32bit pc from Ibuffer to operand collector
    //conversely, we store the entry of SIMT where the pc+4 is stored into the instruction buffer, when the instruction comes into ALu, it can fetch out the pc value from SIMT
    //to calculate the target address
    output reg [31:0] ID0_PCplus4_SIMT_UpdatePC_WS,//the pc+4 is use for branch to store pc+4
	output reg [31:0] ID1_PCplus4_SIMT_UpdatePC_WS,
    output reg [31:0] ID0_Call_ReturnAddr_SIMT,//if current instruction is a call, besides updating the pc value to target address, it has push the return address into SIMT, so we need another pin
    output reg [31:0] ID1_Call_ReturnAddr_SIMT,
    //the pc value used for update WS and SIMT share the same pin, since these two things will never happen at the same time
    ////////////////////////////////////////////////////////////////////
    output reg [7:0] ID0_Active_Mask_WS,//this active mask will send to SIMT, IB WS at the same time
    output reg ID0_PC_Update_SIMT_WS,
    output reg ID0_Stall_PC_WS,
    output reg [7:0] WarpID0_SIMT_IB,//WARP ID FOR IB and SIMT
    output [7:0] WarpID0_WS,//the warp ID signal going to I-buffer, Warp scheduler and SIMT
    //second decode unit
    output reg ID1_PC_Update_SIMT_WS,
    output reg [7:0] ID1_Active_Mask_WS,
    output reg ID1_Stall_PC_WS,
    output reg [7:0] WarpID1_SIMT_IB,
    output[7:0] WarpID1_WS
);
    //combinational module
    //its input register is the output register of instruction bram
    ////////////////////////////////////////////////////////
    //Note: for normal branch instruction, it should also stall the pc and let the warp shcheduler wait for the target address, so that it can also allocate a SIMT etry to store the pc+4
    //and release the entry when it comes out from the ALU
    //so if the branch arrives at the ID stage, the SIMT will never be full, the SIMT at least has one free location,
    //in this case, if the SIMT is full after the branch enter the SIMT, it will just activate the stall signal without update signal. not like other structure hazard,
    //since the update value of pc should be the target address
    /////////////////////////////////////////////////////////////////////////
    //NOTE: In ID stage, there is no flush mechanism, since there are two kind of situation to cause a stalling in Warp schedule and flush some junior instruction
    //1. branch in ID, structural hazard after instruction in ID enters into I-buffer or SIMT
    //so in above cases, we don't need to flush the instruction in ID stage
    //and when Branch comes out from WB, since the pc of the warp to which the branch instruction belongs is still locked
    //it is impossible that an intruction in the ID stage with the same warp ID should be flushed
    /////////////////////////////////////////////////////////////////////////
    wire [5:0] Funct_ID0=IF_ID0_Instruction[5:0];
    wire [5:0] Funct_ID1=IF_ID1_Instruction[5:0];
    wire [5:0] Opcode_ID0=IF_ID0_Instruction[31:26];
    wire [5:0] Opcode_ID1=IF_ID1_Instruction[31:26];
    wire [31:0] Jmp_Call_Target_Addr_ID0={2'b00,IF_ID0_Instruction[25:0],2'b00};
    wire [31:0] Jmp_Call_Target_Addr_ID1={2'b00,IF_ID1_Instruction[25:0],2'b00};
    //////////////////////////////////////////////////////////////////////////
    reg Jmp_ID0, Jmp_ID1;
    //NOTE: The EXIT signal is not needed to be transmitted to WS anymore, since we use the ID_ReleaseWarp_WS_RAU signal
    //to notify the WS to release a hw warp
    reg EXIT_ID0_WS, EXIT_ID1_WS;
    //output signal of ID0
    assign Imme_ID0_IB = IF_ID0_Instruction[15:0];
    assign Branch_ID0_SIMT = BEQ_ID0_IB||BLT_ID0_IB;
    assign WarpID0_WS=IF_ID0_WarpID;
    //output signal of ID1
    assign Imme_ID1_IB = IF_ID1_Instruction[15:0];
    assign Branch_ID1_SIMT = BEQ_ID1_IB||BLT_ID1_IB;
    assign WarpID1_WS=IF_ID1_WarpID;
    /////////////////////////////////////
    wire IB_ID0_Full,IB_ID1_Full;//these signals is used to generate structural hazard stall signal,
    assign IB_ID0_Full=|(IF_ID0_WarpID&IB_Full);
    assign IB_ID1_Full=|(IF_ID1_WarpID&IB_Full);
    /////////////////////////////////////
    wire SIMT_ID0_Full, SIMT_ID0_TwoMoreVacant,SIMT_ID1_Full,SIMT_ID1_TwoMoreVacant;
    assign SIMT_ID0_Full=|(SIMT_Full&IF_ID0_WarpID);
    assign SIMT_ID1_Full=|(SIMT_Full&IF_ID1_WarpID);
    assign SIMT_ID0_TwoMoreVacant=|(SIMT_TwoMoreVacant&IF_ID0_WarpID);
    assign SIMT_ID1_TwoMoreVacant=|(SIMT_TwoMoreVacant&IF_ID1_WarpID);
    //////////////////////////////////////////////////
    //flag registers used for starting scheduling a new sw warp
    reg [7:0] Warp_Done_Reg;
    assign ID_Warp_Release_RAU=({8{EXIT_ID0_WS}}&IF_ID0_WarpID|{8{EXIT_ID1_WS}}&IF_ID1_WarpID|Warp_Done_Reg)&IB_Empty;
    //
    integer i;
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            Warp_Done_Reg<='b0;
        end else begin
            //when Warp_Done signal is 1 in ID stage, if currently coresponding IB is not empty yet,
            //the flag register should be set to 1, ohterwise it keeps as 0
            for(i=0;i<8;i=i+1)begin
                if((EXIT_ID0_WS&&IF_ID0_WarpID[i]||EXIT_ID1_WS&&IF_ID1_WarpID[i])&&!IB_Empty[i])begin
                    Warp_Done_Reg[i]<=!Warp_Done_Reg[i];
                end
                //if current release of  a warp is caused by the corresponding bit in Warp_Done_Reg, then this bit should be reset to 0 at the next clock
            //however, if the release is casued by current instruction in ID stage, then the corresponding bit of Warp_Done_Reg should keep 0
            //the RAU will record and determine which warp can be released , so the release signal in ID stage can only be activated by one clock
                if(ID_Warp_Release_RAU[i]&&Warp_Done_Reg[i])begin
                    Warp_Done_Reg[i]<=!Warp_Done_Reg[i];
                end else if(ID_Warp_Release_RAU[i]&&!Warp_Done_Reg[i]) begin
                    Warp_Done_Reg[i]<=Warp_Done_Reg[i];
                end
            end
            
        end
    end
    ////////////////////////////////////
    always@(*)begin
        Src1_ID0_IB = {1'b0,IF_ID0_Instruction[25:21]};
        Src2_ID0_IB = {1'b0,IF_ID0_Instruction[20:16]};
        Dst_ID0_IB  = {1'b0,IF_ID0_Instruction[15:11]};
        Src1_ID1_IB = {1'b0,IF_ID1_Instruction[25:21]};
        Src2_ID1_IB = {1'b0,IF_ID1_Instruction[20:16]};
        Dst_ID1_IB  = {1'b0,IF_ID1_Instruction[15:11]};
        RegWrite_ID0_IB='b0;
	    RegWrite_ID1_IB='b0;
	    MemWrite_ID0_IB='b0;
	    MemWrite_ID1_IB='b0;
	    MemRead_ID0_IB='b0;
	    MemRead_ID1_IB='b0;
	    ALUop_ID0_IB='b0;
	    ALUop_ID1_IB='b0;
	    Share_Globalbar_ID0_IB='b0;//indicate the type of lw, sw instruction, the local memory can be accessed by all threads and threads block, the global memory is used to exchange the data between GPU and CPU
	    Share_Globalbar_ID1_IB='b0;
	    Imme_Valid_ID0_IB='b0;//used to indicate current instruction is a immediate type
	    Imme_Valid_ID1_IB='b0;
        DotS_ID0_SIMT='b0;
        DotS_ID1_SIMT='b0;
        BEQ_ID0_IB='b0;
        BEQ_ID1_IB='b0;
        BLT_ID0_IB='b0;
        BLT_ID1_IB='b0;
        Call_ID0_SIMT='b0;
	    Call_ID1_SIMT='b0;
	    Ret_ID0_SIMT='b0;
	    Ret_ID1_SIMT='b0;
        EXIT_ID0_WS='b0;
        EXIT_ID1_WS='b0;
        Jmp_ID0=1'b0;
        Jmp_ID1=1'b0;
        case(Opcode_ID0)
            6'b000_000, 6'b010_000:begin //r_type
                Src1_ID0_IB = {1'b1,IF_ID0_Instruction[25:21]};
                Src2_ID0_IB = {1'b1,IF_ID0_Instruction[20:16]};
                Dst_ID0_IB  = {1'b1,IF_ID0_Instruction[15:11]};
                RegWrite_ID0_IB=1'b1;
                if(Opcode_ID0[4]) DotS_ID0_SIMT=1'b1;
                case(Funct_ID0)
                    6'b100_000: ALUop_ID0_IB=4'b0000;//add
                    6'b100_010: ALUop_ID0_IB=4'b0001;//sub
                    6'b011_000: ALUop_ID0_IB=4'b0010;//mul
                    6'b100_100: ALUop_ID0_IB=4'b0011;//and
                    6'b100_101: ALUop_ID0_IB=4'b0100;//or
                    6'b100_110: ALUop_ID0_IB=4'b0101;//xor
                    6'b000_010: ALUop_ID0_IB=4'b0110;//shr
                    6'b000_000: ALUop_ID0_IB=4'b0111;//shl
                endcase
            end
            6'b001_000, 6'b011_000:begin//addi
                Src1_ID0_IB = {1'b1,IF_ID0_Instruction[25:21]};
                Src2_ID0_IB = {1'b0,IF_ID0_Instruction[20:16]};
                Dst_ID0_IB  = {1'b1,IF_ID0_Instruction[20:16]};
                RegWrite_ID0_IB=1'b1;
                ALUop_ID0_IB=4'b0000;
                if(Opcode_ID0[4]) DotS_ID0_SIMT=1'b1;
                Imme_Valid_ID0_IB=1'b1;
            end
            6'b001_100, 6'b011_100:begin//andi
                Src1_ID0_IB = {1'b1,IF_ID0_Instruction[25:21]};
                Src2_ID0_IB = {1'b0,IF_ID0_Instruction[20:16]};
                Dst_ID0_IB  = {1'b1,IF_ID0_Instruction[20:16]};
                RegWrite_ID0_IB=1'b1;
                ALUop_ID0_IB=4'b0011;
                if(Opcode_ID0[4]) DotS_ID0_SIMT=1'b1;
                Imme_Valid_ID0_IB=1'b1;
            end
            6'b001_101, 6'b011_101:begin//ori
                Src1_ID0_IB = {1'b1,IF_ID0_Instruction[25:21]};
                Src2_ID0_IB = {1'b0,IF_ID0_Instruction[20:16]};
                Dst_ID0_IB  = {1'b1,IF_ID0_Instruction[20:16]};
                RegWrite_ID0_IB=1'b1;
                ALUop_ID0_IB=4'b0100;
                if(Opcode_ID0[4]) DotS_ID0_SIMT=1'b1;
                Imme_Valid_ID0_IB=1'b1;
            end
            6'b001_110, 6'b011_110:begin//xori
                Src1_ID0_IB = {1'b1,IF_ID0_Instruction[25:21]};
                Src2_ID0_IB = {1'b0,IF_ID0_Instruction[20:16]};
                Dst_ID0_IB  = {1'b1,IF_ID0_Instruction[20:16]};
                RegWrite_ID0_IB=1'b1;
                ALUop_ID0_IB=4'b0101;
                if(Opcode_ID0[4]) DotS_ID0_SIMT=1'b1;
                Imme_Valid_ID0_IB=1'b1;
            end
            6'b100_011, 6'b110_011:begin//lw access global memory through data cache
                Src1_ID0_IB = {1'b1,IF_ID0_Instruction[25:21]};
                Src2_ID0_IB = {1'b0,IF_ID0_Instruction[20:16]};
                Dst_ID0_IB  = {1'b1,IF_ID0_Instruction[20:16]};
                RegWrite_ID0_IB=1'b1;
                MemRead_ID0_IB=1'b1;
                if(Opcode_ID0[4]) DotS_ID0_SIMT=1'b1;
            end
            6'b100_111, 6'b110_111:begin//LWS
                Src1_ID0_IB = {1'b1,IF_ID0_Instruction[25:21]};
                Src2_ID0_IB = {1'b0,IF_ID0_Instruction[20:16]};
                Dst_ID0_IB  = {1'b1,IF_ID0_Instruction[20:16]};
                RegWrite_ID0_IB=1'b1;
                MemRead_ID0_IB=1'b1;
                if(Opcode_ID0[4]) DotS_ID0_SIMT=1'b1;
                Share_Globalbar_ID0_IB=1'b1; //access the share memory, namely on-chip memory
            end
            6'b101_011, 6'b111_011:begin//sw access global memory through data cache
                Src1_ID0_IB = {1'b1,IF_ID0_Instruction[25:21]};
                Src2_ID0_IB = {1'b1,IF_ID0_Instruction[20:16]};
                Dst_ID0_IB  = {1'b0,IF_ID0_Instruction[15:11]};
                MemWrite_ID0_IB=1'b1;
                if(Opcode_ID0[4]) DotS_ID0_SIMT=1'b1;
            end
            6'b101_111, 6'b111_111:begin//SWS
                Src1_ID0_IB = {1'b1,IF_ID0_Instruction[25:21]};
                Src2_ID0_IB = {1'b1,IF_ID0_Instruction[20:16]};
                Dst_ID0_IB  = {1'b0,IF_ID0_Instruction[15:11]};
                MemWrite_ID0_IB=1'b1;
                if(Opcode_ID0[4]) DotS_ID0_SIMT=1'b1;
                Share_Globalbar_ID0_IB=1'b1;
            end
            6'b000_100, 6'b010_100, 6'b000_111, 6'b010_111:begin//branch instruction
                Src1_ID0_IB = {1'b1,IF_ID0_Instruction[25:21]};
                Src2_ID0_IB = {1'b1,IF_ID0_Instruction[20:16]};
                Dst_ID0_IB  = {1'b0,IF_ID0_Instruction[15:11]};
                if(Opcode_ID0[0]) BLT_ID0_IB=1'b1;
                else BEQ_ID0_IB=1'b1;
                //
                if(Opcode_ID0[4])  DotS_ID0_SIMT=1'b1;
            end
            6'b000_010, 6'b010_010: begin//jmp
                Jmp_ID0=1'b1;
                //
                if(Opcode_ID0[4])  DotS_ID0_SIMT=1'b1;
            end
            6'b000_011: Call_ID0_SIMT=1'b1; 
            6'b000_110: Ret_ID0_SIMT=1'b1;
            6'b010_001: DotS_ID0_SIMT=1'b1;
            6'b100_001: EXIT_ID0_WS=1'b1;
        endcase
        /////////////////
        //ID 1
        case(Opcode_ID1)
            6'b000_000, 6'b010_000:begin //r_type
                Src1_ID1_IB = {1'b1,IF_ID1_Instruction[25:21]};
                Src2_ID1_IB = {1'b1,IF_ID1_Instruction[20:16]};
                Dst_ID1_IB  = {1'b1,IF_ID1_Instruction[15:11]};
                RegWrite_ID1_IB=1'b1;
                if(Opcode_ID1[4]) DotS_ID1_SIMT=1'b1;
                case(Funct_ID1)
                    6'b100_000: ALUop_ID1_IB=4'b0000;//add
                    6'b100_010: ALUop_ID1_IB=4'b0001;//sub
                    6'b011_000: ALUop_ID1_IB=4'b0010;//mul
                    6'b100_100: ALUop_ID1_IB=4'b0011;//and
                    6'b100_101: ALUop_ID1_IB=4'b0100;//or
                    6'b100_110: ALUop_ID1_IB=4'b0101;//xor
                    6'b000_010: ALUop_ID1_IB=4'b0110;//shr
                    6'b000_000: ALUop_ID1_IB=4'b0111;//shl
                endcase
            end
            6'b001_000, 6'b011_000:begin//addi
                Src1_ID1_IB = {1'b1,IF_ID1_Instruction[25:21]};
                Src2_ID1_IB = {1'b0,IF_ID1_Instruction[20:16]};
                Dst_ID1_IB  = {1'b1,IF_ID1_Instruction[20:16]};
                RegWrite_ID1_IB=1'b1;
                ALUop_ID1_IB=4'b0000;
                if(Opcode_ID1[4]) DotS_ID1_SIMT=1'b1;
                Imme_Valid_ID1_IB=1'b1;
            end
            6'b001_100, 6'b011_100:begin//andi
                Src1_ID1_IB = {1'b1,IF_ID1_Instruction[25:21]};
                Src2_ID1_IB = {1'b0,IF_ID1_Instruction[20:16]};
                Dst_ID1_IB  = {1'b1,IF_ID1_Instruction[20:16]};
                RegWrite_ID1_IB=1'b1;
                ALUop_ID1_IB=4'b0011;
                if(Opcode_ID1[4]) DotS_ID1_SIMT=1'b1;
                Imme_Valid_ID1_IB=1'b1;
            end
            6'b001_101, 6'b011_101:begin//ori
                Src1_ID1_IB = {1'b1,IF_ID1_Instruction[25:21]};
                Src2_ID1_IB = {1'b0,IF_ID1_Instruction[20:16]};
                Dst_ID1_IB  = {1'b1,IF_ID1_Instruction[20:16]};
                RegWrite_ID1_IB=1'b1;
                ALUop_ID1_IB=4'b0100;
                if(Opcode_ID1[4]) DotS_ID1_SIMT=1'b1;
                Imme_Valid_ID1_IB=1'b1;
            end
            6'b001_110, 6'b011_110:begin//xori
                Src1_ID1_IB = {1'b1,IF_ID1_Instruction[25:21]};
                Src2_ID1_IB = {1'b0,IF_ID1_Instruction[20:16]};
                Dst_ID1_IB  = {1'b1,IF_ID1_Instruction[20:16]};
                RegWrite_ID1_IB=1'b1;
                ALUop_ID1_IB=4'b0101;
                if(Opcode_ID1[4]) DotS_ID1_SIMT=1'b1;
                Imme_Valid_ID1_IB=1'b1;
            end
            6'b100_011, 6'b110_011:begin//lw
                Src1_ID1_IB = {1'b1,IF_ID1_Instruction[25:21]};
                Src2_ID1_IB = {1'b0,IF_ID1_Instruction[20:16]};
                Dst_ID1_IB  = {1'b1,IF_ID1_Instruction[20:16]};
                RegWrite_ID1_IB=1'b1;
                MemRead_ID1_IB=1'b1;
                if(Opcode_ID1[4]) DotS_ID1_SIMT=1'b1;
            end
            6'b100_111, 6'b110_111:begin//LWS
                Src1_ID1_IB = {1'b1,IF_ID1_Instruction[25:21]};
                Src2_ID1_IB = {1'b0,IF_ID1_Instruction[20:16]};
                Dst_ID1_IB  = {1'b1,IF_ID1_Instruction[20:16]};
                RegWrite_ID1_IB=1'b1;
                MemRead_ID1_IB=1'b1;
                if(Opcode_ID1[4]) DotS_ID1_SIMT=1'b1;
                Share_Globalbar_ID1_IB=1'b1; //access the shared memory, namely data cache
            end
            6'b101_011, 6'b111_011:begin//sw
                Src1_ID1_IB = {1'b1,IF_ID1_Instruction[25:21]};
                Src2_ID1_IB = {1'b1,IF_ID1_Instruction[20:16]};
                Dst_ID1_IB  = {1'b0,IF_ID1_Instruction[15:11]};
                MemWrite_ID1_IB=1'b1;
                if(Opcode_ID1[4]) DotS_ID1_SIMT=1'b1;
            end
            6'b101_111, 6'b111_111:begin//SWS
                Src1_ID1_IB = {1'b1,IF_ID1_Instruction[25:21]};
                Src2_ID1_IB = {1'b1,IF_ID1_Instruction[20:16]};
                Dst_ID1_IB  = {1'b0,IF_ID1_Instruction[15:11]};
                MemWrite_ID1_IB=1'b1;
                if(Opcode_ID1[4]) DotS_ID1_SIMT=1'b1;
                Share_Globalbar_ID1_IB=1'b1;
            end
            6'b000_100, 6'b010_100, 6'b000_111, 6'b010_111:begin//branch instruction
                Src1_ID1_IB = {1'b1,IF_ID1_Instruction[25:21]};
                Src2_ID1_IB = {1'b1,IF_ID1_Instruction[20:16]};
                Dst_ID1_IB  = {1'b0,IF_ID1_Instruction[15:11]};
                if(Opcode_ID1[0]) BLT_ID1_IB=1'b1;
                else BEQ_ID1_IB=1'b1;
                //
                if(Opcode_ID1[4])  DotS_ID1_SIMT=1'b1;
            end
            6'b000_010, 6'b010_010: begin//jmp
                Jmp_ID1=1'b1;
                //
                if(Opcode_ID1[4])  DotS_ID1_SIMT=1'b1;
            end
            6'b000_011: Call_ID1_SIMT=1'b1; 
            6'b000_110: Ret_ID1_SIMT=1'b1;
            6'b010_001: DotS_ID1_SIMT=1'b1;
            6'b100_001: EXIT_ID1_WS=1'b1;
        endcase

    end
    ///////////////////////////////////////////////////////////////
    //combinaitonal logic for generating stall, update signal
    always@(*)begin
        WarpID0_SIMT_IB=IF_ID0_WarpID;
        WarpID1_SIMT_IB=IF_ID1_WarpID;
        //when ID update occurs, it means structural hazard happens, so we should make the warp ID for SIMT and IB to all zeros
        //and keep the warp ID for WS to update the pc of corresponding Warp
        ///////////////////////////////////
        ID0_PCplus4_SIMT_UpdatePC_WS=IF_ID0_PC_Plus4;
        ID1_PCplus4_SIMT_UpdatePC_WS=IF_ID1_PC_Plus4;
        ID0_PC_Update_SIMT_WS='b0;
        ID0_Stall_PC_WS=EXIT_ID0_WS;//by default, if the isntruction in ID is a exit instruction, then activate the stall signal
        //so that the request to priority resolver will be set to zero, and the pc_valid will be locked, instruciton after the exit will be flushed in IF stage
        ID1_PC_Update_SIMT_WS='b0;
        ID1_Stall_PC_WS=EXIT_ID1_WS;
        ID0_Active_Mask_SIMT_IB=IF_ID0_Active_Mask;
        ID1_Active_Mask_SIMT_IB=IF_ID1_Active_Mask;
        ID0_Active_Mask_WS=IF_ID0_Active_Mask;
        ID1_Active_Mask_WS=IF_ID1_Active_Mask;
        ////////////////////////////////
        ID0_Call_ReturnAddr_SIMT=IF_ID0_PC_Plus4;
        ID1_Call_ReturnAddr_SIMT=IF_ID1_PC_Plus4;
        ////////////////////////////////
        //ID0
        //if current instruction in ID stage is a branch, we first think about the structural hazard
        //if this hazard doesn't happen, then we think about if it is .s instruction
        if(|IF_ID0_WarpID)begin//At first make sure the instruction in ID stage is not flushed, then we think about different situation for generating stall and update signal
            case({Ret_ID0_SIMT,Call_ID0_SIMT,Jmp_ID0,Branch_ID0_SIMT})
                4'b0001:begin//branch instruction
                    if(DotS_ID0_SIMT)begin//branch.s requires two free locations in SIMT
                        if(SIMT_ID0_TwoMoreVacant&&!IB_ID0_Full)begin//if the SIMT and Ibuffer can accomodate this branch, then we stall the pc in WS
                            ID0_Stall_PC_WS=1'b1;//let the ws wait for the branch coming out from the WB stage
                        end else begin//otherwise recover the pc and replay the instruction
                            ID0_PC_Update_SIMT_WS=1'b1;
                            ID0_PCplus4_SIMT_UpdatePC_WS=IF_ID0_PC_Plus4-4;
                            //if structural hazard occurs, then clean the warp id so that the instruction to be repalyed will not enter into IB and SIMT
                            WarpID0_SIMT_IB=8'b0000_0000;
                        end
                    end else begin//if it is a normal beq instruction, then just require one free location in SIMT to store PC
                        if(!SIMT_ID0_Full&&!IB_ID0_Full)begin
                            ID0_Stall_PC_WS=1'b1;//let the ws wait for the branch comes out from the WB stage
                        end else begin//structural hazard, replay
                            ID0_PC_Update_SIMT_WS=1'b1;
                            ID0_PCplus4_SIMT_UpdatePC_WS=IF_ID0_PC_Plus4-4;
                            WarpID0_SIMT_IB=8'b0000_0000;
                        end
                    end
                end
                4'b0010:begin//jmp instruciton
                    ID0_PC_Update_SIMT_WS=1'b1;
                    ID0_PCplus4_SIMT_UpdatePC_WS=Jmp_Call_Target_Addr_ID0;
                    WarpID0_SIMT_IB=8'b0000_0000;//NOTE: if instruction itself doesn't enter into IB, we also clean all warp ID bits
                end
                4'b0100:begin//call instruction
                    ID0_PC_Update_SIMT_WS=1'b1;
                    WarpID0_SIMT_IB=8'b0000_0000;
                    if(SIMT_ID0_Full)begin//check if the SIMT is full, Since it want to push the return address into SIMT
                        ID0_PCplus4_SIMT_UpdatePC_WS=IF_ID0_PC_Plus4-4;//replay
                    end else begin
                        ID0_PCplus4_SIMT_UpdatePC_WS=Jmp_Call_Target_Addr_ID0;
                    end
                end
                4'b1000:begin//return instruction
                    ID0_PC_Update_SIMT_WS=1'b1;
                    ID0_PCplus4_SIMT_UpdatePC_WS=SIMT_Poped_PC_ID0;
                    WarpID0_SIMT_IB=8'b0000_0000;
                end
                default:begin//check if a structural hazard occurs
                    if(MemWrite_ID0_IB||MemRead_ID0_IB||RegWrite_ID0_IB)begin//instructions which have to enter into IB
                        if(IB_ID0_Full)begin
                            ID0_PC_Update_SIMT_WS=1'b1;
                            ID0_PCplus4_SIMT_UpdatePC_WS=IF_ID0_PC_Plus4-4;
                            WarpID0_SIMT_IB=8'b0000_0000;
                        end else if(DotS_ID0_SIMT) begin//if it is a .s instruction, pop out the DIV token in SIMT
                            ID0_PC_Update_SIMT_WS=1'b1;
                            ID0_Active_Mask_WS=SIMT_Poped_Active_Mask_ID0;
                            if(SIMT_Div_SyncBar_Token_ID0)begin//DIV
                                ID0_PCplus4_SIMT_UpdatePC_WS=SIMT_Poped_PC_ID0;
                            end 
                            //NOTE: if the popped-out token is a sync, then we should not change the pc value, in this case
                            //since we have to update the active mask, so we set the pc update value to pc+4
                            //if the popped-out token is a DIV, then the pc value to be updated should be one from the SIMT
                        end
                    end else begin//EXIT or NOOP
                        WarpID0_SIMT_IB=8'b0000_0000;
                        if(DotS_ID0_SIMT)begin//NOOP.s
                            ID0_PC_Update_SIMT_WS=1'b1;
                            ID0_Active_Mask_WS=SIMT_Poped_Active_Mask_ID0;
                            if(SIMT_Div_SyncBar_Token_ID0)begin//DIV
                                ID0_PCplus4_SIMT_UpdatePC_WS=SIMT_Poped_PC_ID0;
                            end 
                        end
                    end
                end
            endcase     
        end

        ////////////////////
        //ID1
        if(|IF_ID1_WarpID)begin//At first make sure the instruction in ID stage is not flushed, then we think about different situation for generating stall and update signal
            case({Ret_ID1_SIMT,Call_ID1_SIMT,Jmp_ID1,Branch_ID1_SIMT})
                4'b0001:begin//branch instruction
                    if(DotS_ID1_SIMT)begin//branch.s requires two free locations in SIMT
                        if(SIMT_ID1_TwoMoreVacant&&!IB_ID1_Full)begin//if the SIMT and Ibuffer can accomodate this branch, then we stall the pc in WS
                            ID1_Stall_PC_WS=1'b1;//let the ws wait for the branch coming out from the WB stage
                        end else begin//otherwise recover the pc and replay the instruction
                            ID1_PC_Update_SIMT_WS=1'b1;
                            ID1_PCplus4_SIMT_UpdatePC_WS=IF_ID1_PC_Plus4-4;
                            //if structural hazard occurs, then clean the warp id so that the instruction to be repalyed will not enter into IB and SIMT
                            WarpID1_SIMT_IB=8'b0000_0000;
                        end
                    end else begin//if it is a normal beq instruction, then just require one free location in SIMT to store PC
                        if(!SIMT_ID1_Full&&!IB_ID1_Full)begin
                            ID1_Stall_PC_WS=1'b1;//let the ws wait for the branch comes out from the WB stage
                        end else begin//structural hazard, replay
                            ID1_PC_Update_SIMT_WS=1'b1;
                            ID1_PCplus4_SIMT_UpdatePC_WS=IF_ID1_PC_Plus4-4;
                            WarpID1_SIMT_IB=8'b0000_0000;
                        end
                    end
                end
                4'b0010:begin//jmp instruciton
                    ID1_PC_Update_SIMT_WS=1'b1;
                    ID1_PCplus4_SIMT_UpdatePC_WS=Jmp_Call_Target_Addr_ID1;
                    WarpID1_SIMT_IB=8'b0000_0000;//NOTE: if instruction itself doesn't enter into IB, we also clean all warp ID bits
                end
                4'b0100:begin//call instruction
                    ID1_PC_Update_SIMT_WS=1'b1;
                    WarpID1_SIMT_IB=8'b0000_0000;
                    if(SIMT_ID1_Full)begin//check if the SIMT is full, Since it want to push the return address into SIMT
                        ID1_PCplus4_SIMT_UpdatePC_WS=IF_ID1_PC_Plus4-4;//replay
                    end else begin
                        ID1_PCplus4_SIMT_UpdatePC_WS=Jmp_Call_Target_Addr_ID1;
                    end
                end
                4'b1000:begin//return instruction
                    ID1_PC_Update_SIMT_WS=1'b1;
                    ID1_PCplus4_SIMT_UpdatePC_WS=SIMT_Poped_PC_ID1;
                    WarpID1_SIMT_IB=8'b0000_0000;
                end
                default:begin//check if a structural hazard occurs
                    if(MemWrite_ID1_IB||MemRead_ID1_IB||RegWrite_ID1_IB)begin//instructions which have to enter into IB
                        if(IB_ID1_Full)begin
                            ID1_PC_Update_SIMT_WS=1'b1;
                            ID1_PCplus4_SIMT_UpdatePC_WS=IF_ID1_PC_Plus4-4;
                            WarpID1_SIMT_IB=8'b0000_0000;
                        end else if(DotS_ID1_SIMT) begin//if it is a .s instruction, pop out the DIV token in SIMT
                            ID1_PC_Update_SIMT_WS=1'b1;
                            ID1_Active_Mask_WS=SIMT_Poped_Active_Mask_ID1;
                            if(SIMT_Div_SyncBar_Token_ID1)begin
                                ID1_PCplus4_SIMT_UpdatePC_WS=SIMT_Poped_PC_ID1;
                            end
                        end
                    end else begin//EXIT or NOOP
                        WarpID1_SIMT_IB=8'b0000_0000;
                        if(DotS_ID1_SIMT)begin//NOOP.s
                            ID1_PC_Update_SIMT_WS=1'b1;
                            ID1_Active_Mask_WS=SIMT_Poped_Active_Mask_ID1;
                            if(SIMT_Div_SyncBar_Token_ID1)begin
                                ID1_PCplus4_SIMT_UpdatePC_WS=SIMT_Poped_PC_ID1;
                            end
                        end
                    end
                end
            endcase     
        end
    end
endmodule
