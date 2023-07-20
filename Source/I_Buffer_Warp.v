`timescale 1ns/100ps
module I_Buffer_Warp(
    input clk,
    input rst_n,
    input wen,
    //interface with Score Board
    output [3:0] IB_Inst_Valid_SB,//indicate the validity of the instruction in each entry of IB
    output [5:0] IB_Src1_Entry0_SB,
    output [5:0] IB_Src1_Entry1_SB,
    output [5:0] IB_Src1_Entry2_SB,
    output [5:0] IB_Src1_Entry3_SB,
    output [5:0] IB_Src2_Entry0_SB,
    output [5:0] IB_Src2_Entry1_SB,
    output [5:0] IB_Src2_Entry2_SB,
    output [5:0] IB_Src2_Entry3_SB,//RAW 
    output [5:0] IB_Dst_Entry0_SB,//WAR, WAW
    output [5:0] IB_Dst_Entry1_SB,
    output [5:0] IB_Dst_Entry2_SB,
    output [5:0] IB_Dst_Entry3_SB,
    ////////////////////////////////////
    input [3:0] SB_Ready_Issue_IB, //one-hot code, if one of four bits is 1, means currently the instruction in the corresponding entry is sent to operand collector
    output reg [3:0] IB_Issued_SB,
    input SB_Full,
    //interface with ID stage
    input [5:0] Src1_In, //rs regsiter address MSB is valid bit, used to simplify the score board structure
	input [5:0] Src2_In,//rt regsiter address
	input [5:0] Dst_In,//rt/rd register address
	input [15:0] Imme_Addr_In,
	input RegWrite_In,//similar signals in pipelined cpu
	input MemWrite_In,
	input MemRead_In,//besides using this signal to access the data cache, this signal is also used to select the correct result to write into register file
	input [3:0] ALU_Opcode_In,
	input Share_Globalbar_In,//indicate the type of lw, sw instruction, the local memory can be accessed by all threads and threads block, the global memory is used to exchange the data between GPU and CPU
	input Imme_Valid_In,//used to recongnize I-Type instructions
    input BEQ_In,
    input BLT_In,
    input [7:0] Active_Mask_In,
    ///////////////
    //output to operand collector
    output reg [5:0] Src1_Out, //rs regsiter address
	output reg [5:0] Src2_Out,//rt regsiter address
	output reg [5:0] Dst_Out,//rt/rd register address
	output reg [15:0] Imme_Addr_Out,
	output reg RegWrite_Out,//similar signals in pipelined cpu
	output reg MemWrite_Out,
	output reg MemRead_Out,//besides using this signal to access the data cache, this signal is also used to select the correct result to write into register file
	output reg [3:0] ALU_Opcode_Out,
	output reg Share_Globalbar_Out,//indicate the type of lw, sw instruction, the local memory can be accessed by all threads and threads block, the global memory is used to exchange the data between GPU and CPU
	output reg Imme_Valid_Out,//used to recongnize I-Type instructions
    output reg BEQ_Out_OC,//to operand collector
    output reg BLT_Out_OC,
    output reg [7:0] Active_Mask_Out,
    //output to ID stage
    output IB_Full,
    output IB_Empty,
    /////////////////////////
    //interface with Issue Unit
    output IB_Ready_Issue_IU,
    input IU_Grant
);
    integer i;
    ////this Instruction Buffer should be a queue, the instruction at the bottom of the queue should has a higher priority when multiple instruction are ready to go
    //Four entries
    //--------------------------------------------------------------------------------------------------------------------
    //-- valid bit -- rs address -- rt address -- rd address
    //--------------------------------------------------------------------------------------------------------------------
    //-- opcode  -- reg write -- mem write -- mem read -- local/global -- immediate valid -- 
    //--------------------------------------------------------------------------------------------------------------------
    //-- immediate address -- beq -- blt -- active mask
    //--------------------------------------------------------------------------------------------------------------------
    reg [3:0] Valid;
    reg [3:0] Ready_Issue;
    reg [5:0] Src1_reg [3:0];
    reg [5:0] Src2_reg [3:0];
    reg [5:0] Dst_reg [3:0];
	reg [15:0] Imme_Addr_reg [3:0];
	reg [3:0] RegWrite_reg;
	reg [3:0] MemWrite_reg;
	reg [3:0] MemRead_reg;
	reg [3:0] ALU_Opcode_reg [3:0];
	reg [3:0] Share_Globalbar_reg; 
	reg [3:0] Imme_Valid_reg;
    reg [3:0] BEQ_reg;
    reg [3:0] BLT_reg;
    reg [7:0] Active_Mask_reg [3:0];
    ////////////////////////////////
    //combinational signals for shifting
    //the logic is much simpler than those in Tomosulo CPU in which we have to consider the effect of cdb_flush
    wire [2:0] Shift_En;
    //if the shift signal for an entry is one, it means the contents in its upper entry can shift downward
    // then entry 3 doesn't need a shift enable signal
    assign Shift_En[0]=!Valid[0]||Valid[0]&&Ready_Issue[0]&&IU_Grant;
    assign Shift_En[1]=Shift_En[0]||!Shift_En[0]&&(!Valid[1]||Valid[1]&&Ready_Issue[1]&&!Ready_Issue[0]&&IU_Grant);
    assign Shift_En[2]=Shift_En[1]||!Shift_En[1]&&(!Valid[2]||Valid[2]&&Ready_Issue[2]&&!Ready_Issue[1]&&!Ready_Issue[0]&&IU_Grant);
    ////////////////////
    //NOTE: originally we hope that if current an entry of IB is permitted to be issued, even if the IB is full now, but a new instruction 
    //is allowed to enter into IB, but this cause a great long combinational path
    //Since OC_valid -> OC_full -> IU_Grant -> IB_Full -> ID Stage structural hazard -> pc update/stall -> flush -> fetch
    assign IB_Full=&Valid;
    assign IB_Empty=!(|Valid);
    assign IB_Ready_Issue_IU=|(Ready_Issue&Valid)&&!SB_Full;//NOTE：if the IB want to send a request to issue unit, first the scoreboard should notify the instruction in IB is ready to issue,second, the scoreboard should not be full
    ////////////////////
    assign IB_Inst_Valid_SB=Valid;
    assign IB_Src1_Entry0_SB=Src1_reg[0];
    assign IB_Src1_Entry1_SB=Src1_reg[1];
    assign IB_Src1_Entry2_SB=Src1_reg[2];
    assign IB_Src1_Entry3_SB=Src1_reg[3];
    assign IB_Src2_Entry0_SB=Src2_reg[0];
    assign IB_Src2_Entry1_SB=Src2_reg[1];
    assign IB_Src2_Entry2_SB=Src2_reg[2];
    assign IB_Src2_Entry3_SB=Src2_reg[3];
    assign IB_Dst_Entry0_SB=Dst_reg[0];
    assign IB_Dst_Entry1_SB=Dst_reg[1];
    assign IB_Dst_Entry2_SB=Dst_reg[2];
    assign IB_Dst_Entry3_SB=Dst_reg[3];
    assign IB_RegWrite_SB=RegWrite_reg;
    assign IB_MemWrite_SB=MemWrite_reg;
    assign IB_MemRead_SB=MemRead_reg;
    assign IB_Imme_Valid_SB=Imme_Valid_reg;
    assign IB_Branch_Valid_SB=BEQ_reg|BLT_reg;
    assign IB_RegWrite_SB=RegWrite_reg;
    ////////////////////
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            Valid<='b0;
            Ready_Issue<='bx;
            RegWrite_reg<='bx;
            MemWrite_reg<='bx;
            MemRead_reg<='bx;
            Share_Globalbar_reg<='bx;
            BEQ_reg<='bx;
            BLT_reg<='bx;
            for (i=0;i<4;i=i+1)begin
                Src1_reg[i]<='bx;
                Src2_reg[i]<='bx;
                Dst_reg[i]<='bx;
                Imme_Addr_reg[i]<='bx;
                ALU_Opcode_reg[i]<='bx;
                Active_Mask_reg[i]<='bx;
            end
        end else begin
            //the update of entry 0-2
            for(i=1;i<4;i=i+1)begin
                if(Shift_En[i-1])begin
                    Src1_reg [i-1]<=Src1_reg [i];
                    Src2_reg [i-1]<=Src2_reg [i];
                    Dst_reg  [i-1]<=Dst_reg [i];
	                Imme_Addr_reg [i-1]<=Imme_Addr_reg [i];
	                RegWrite_reg [i-1]<=RegWrite_reg [i];
	                MemWrite_reg[i-1]<=MemWrite_reg[i];
	                MemRead_reg[i-1]<=MemRead_reg[i];
	                ALU_Opcode_reg[i-1]<=ALU_Opcode_reg[i];
	                Share_Globalbar_reg[i-1]<=Share_Globalbar_reg[i]; 
	                Imme_Valid_reg[i-1]<=Imme_Valid_reg[i];
                    BEQ_reg[i-1]<=BEQ_reg[i];
                    BLT_reg[i-1]<=BLT_reg[i];
                    Active_Mask_reg[i-1]<=Active_Mask_reg[i];
                    if(SB_Ready_Issue_IB[i]&&Valid[i])begin
                        Ready_Issue[i-1]<=1'b1;
                    end else begin
                        Ready_Issue[i-1]<=Ready_Issue[i];
                    end
                end else begin
                    if(SB_Ready_Issue_IB[i-1]&&Valid[i-1])begin
                        Ready_Issue[i-1]<=1'b1;
                    end
                end
            end
            ///////////////////////////////////
            //valid bit update
            //NOTE:the value of ready issue is not initialized, so if we only use the ready issue signal to activate the change of valid bit
            //the output of a boolean function with x is x, so it will casue a problem
            if(Shift_En[0])begin
                //how to recognize if the instruction in a certain entry will be issued at the next clock edge?
                //ready issue=1, valid=1 then we can ganrantee the instruciton is really ready to issue, then check the priority
                if(Ready_Issue[1]&&Valid[1]&&!(Ready_Issue[0]&&Valid[0])&&IU_Grant)begin//means the instruction in entry 1 must be valid
                    Valid[0]<=!Valid[1];
                end else begin
                    Valid[0]<=Valid[1];
                end
            end // if the shift enable is 0, it means the instruction in entry 0 is valid and not issued yet, so just keep the value
            if(Shift_En[1])begin
                if(Ready_Issue[2]&&Valid[2]&&!(Ready_Issue[1]&&Valid[1])&&!(Ready_Issue[0]&&Valid[0])&&IU_Grant)begin//means the instruction in entry 1 must be valid
                    Valid[1]<=!Valid[2];
                end else begin
                    Valid[1]<=Valid[2];
                end
            end
            if(Shift_En[2])begin
                if(Ready_Issue[3]&&Valid[3]&&IU_Grant&&!(Ready_Issue[2]&&Valid[2])&&!(Ready_Issue[1]&&Valid[1])&&!(Ready_Issue[0]&&Valid[0]))begin//means the instruction in entry 1 must be valid
                    Valid[2]<=!Valid[3];
                end else begin
                    Valid[2]<=Valid[3];
                end
            end
            ///////////////////////////
            //entry3 update
            //if the wen signal is one, it means the i-buffer must not be full, if it is full, the instruction in ID stage will be replayed
            if(wen)begin
                Valid[3]<=1'b1;
                Ready_Issue[3]<=1'b0;
                Src1_reg [3]<=Src1_In;
                Src2_reg [3]<=Src2_In;
                Dst_reg  [3]<=Dst_In;
                Imme_Addr_reg [3]<=Imme_Addr_In;
                RegWrite_reg [3]<=RegWrite_In;
                MemWrite_reg[3]<=MemWrite_In;
                MemRead_reg[3]<=MemRead_In;
                ALU_Opcode_reg[3]<=ALU_Opcode_In;
                Share_Globalbar_reg[3]<=Share_Globalbar_In; 
                Imme_Valid_reg[3]<=Imme_Valid_In;
                BEQ_reg[3]<=BEQ_In;
                BLT_reg[3]<=BLT_In;
                Active_Mask_reg[3]<=Active_Mask_In;
            end else begin//if no new instruction is written into I-Buffer, it might be full, so we have to consider the situtaion to update the valid bit
                if(Shift_En[2])begin//if shift enable is 1, and no valid new instruction is written into IB, then reset the valid bit to 0
                    Valid[3]<=1'b0;
                    Ready_Issue[3]<=1'b0;
                end else if(Valid[3])begin//if valid[3] is 1, then check if it is issued to operand collector in current clock
                    if(SB_Ready_Issue_IB[3])begin
                        Ready_Issue[3]<=1'b1;
                    end
                    if(Ready_Issue[3]&&!Ready_Issue[2]&&!Ready_Issue[1]&&!Ready_Issue[0]&&IU_Grant)begin
                        Valid[3]<=!Valid[3];
                    end
                end
            end
        end
    end
    ///////////////////////////////
    //combinational always block to select output signal
    always@(*)begin
        IB_Issued_SB=4'b0000;
        casez(Ready_Issue&Valid)
            4'bzz10:begin //by default the output signal is mapped to entry0
                Src1_Out=Src1_reg[1]; 
	            Src2_Out=Src2_reg[1];
	            Dst_Out=Dst_reg[1];
	            Imme_Addr_Out=Imme_Addr_reg[1];
	            RegWrite_Out=RegWrite_reg[1];
	            MemWrite_Out=MemWrite_reg[1];
	            MemRead_Out=MemRead_reg[1];
	            ALU_Opcode_Out=ALU_Opcode_reg[1];
	            Share_Globalbar_Out=Share_Globalbar_reg[1];
	            Imme_Valid_Out=Imme_Valid_reg[1];
                BEQ_Out_OC=BEQ_reg[1];
                BLT_Out_OC=BLT_reg[1];
                Active_Mask_Out=Active_Mask_reg[1];
                IB_Issued_SB[1]=IU_Grant;
            end
            4'bz100:begin //by default the output signal is mapped to entry0
                Src1_Out=Src1_reg[2]; 
	            Src2_Out=Src2_reg[2];
	            Dst_Out=Dst_reg[2];
	            Imme_Addr_Out=Imme_Addr_reg[2];
	            RegWrite_Out=RegWrite_reg[2];
	            MemWrite_Out=MemWrite_reg[2];
	            MemRead_Out=MemRead_reg[2];
	            ALU_Opcode_Out=ALU_Opcode_reg[2];
	            Share_Globalbar_Out=Share_Globalbar_reg[2];
	            Imme_Valid_Out=Imme_Valid_reg[2];
                BEQ_Out_OC=BEQ_reg[2];
                BLT_Out_OC=BLT_reg[2];
                Active_Mask_Out=Active_Mask_reg[2];
                IB_Issued_SB[2]=IU_Grant;
            end
            4'b1000:begin //by default the output signal is mapped to entry0
                Src1_Out=Src1_reg[3]; 
	            Src2_Out=Src2_reg[3];
	            Dst_Out=Dst_reg[3];
	            Imme_Addr_Out=Imme_Addr_reg[3];
	            RegWrite_Out=RegWrite_reg[3];
	            MemWrite_Out=MemWrite_reg[3];
	            MemRead_Out=MemRead_reg[3];
	            ALU_Opcode_Out=ALU_Opcode_reg[3];
	            Share_Globalbar_Out=Share_Globalbar_reg[3];
	            Imme_Valid_Out=Imme_Valid_reg[3];
                BEQ_Out_OC=BEQ_reg[3];
                BLT_Out_OC=BLT_reg[3];
                Active_Mask_Out=Active_Mask_reg[3];
                IB_Issued_SB[3]=IU_Grant;
            end
            default:begin //by default the output signal is mapped to entry0
                Src1_Out=Src1_reg[0]; 
	            Src2_Out=Src2_reg[0];
	            Dst_Out=Dst_reg[0];
	            Imme_Addr_Out=Imme_Addr_reg[0];
	            RegWrite_Out=RegWrite_reg[0];
	            MemWrite_Out=MemWrite_reg[0];
	            MemRead_Out=MemRead_reg[0];
	            ALU_Opcode_Out=ALU_Opcode_reg[0];
	            Share_Globalbar_Out=Share_Globalbar_reg[0];
	            Imme_Valid_Out=Imme_Valid_reg[0];
                BEQ_Out_OC=BEQ_reg[0];
                BLT_Out_OC=BLT_reg[0];
                Active_Mask_Out=Active_Mask_reg[0];
                IB_Issued_SB[0]=IU_Grant;
            end
        endcase
    end

endmodule
