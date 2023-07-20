`timescale 1ns/100ps
module Operand_Collector(
    input clk,
    input rst_n,
    ///////////////
    //interface with IB
    input [5:0] IB_Src1_Out, //used to identify the case that the source register is $8 or $16, then we get the data from RAU not RF
	input [5:0] IB_Src2_Out,
	input [15:0] IB_Imme_Addr_OC,
	input IB_RegWrite_OC,
	input IB_MemWrite_OC,
	input IB_MemRead_OC,
	input [3:0] IB_ALU_Opcode_OC,
	input IB_Share_Globalbar_OC,
	input IB_Imme_Valid_OC,
    input IB_BEQ_OC,
    input IB_BLT_OC,
    input [7:0] IB_Active_Mask_OC,
    input [1:0] SB_Release_EntNum_OC,//the entry number of Score board used for releasing the entry when isntrucitons comes out on WB stage
    //interface with IU
    input [7:0] IU_Grant,//used to indicate the warp ID of coming-up instructioin
    output OC_Full,
    //interface with Ex_Issue_Unit
    output reg [3:0] OC_IssReq_EX_IU,//the issue request sent to EX issue unit
    input [3:0] EX_IU_Grant,
    //interface with RAU
    output reg [1:0] OC_EntryNum_RAU,//indicate the entry where the readout information should enter, it will be carried with the source register information into RF
    input [4:0] RAU_Dst_PhyRegAddr,//MSB -> valid bit
    input [255:0] RAU_Src1_Reg8_16_Data,//Special registers value for $8->thread ID, $16->sw warp ID
    input [255:0] RAU_Src2_Reg8_16_Data,
    //interface with RF
    input [255:0] RF_Out_Bank0,
    input [255:0] RF_Out_Bank1,
    input [255:0] RF_Out_Bank2,
    input [255:0] RF_Out_Bank3,
    input [1:0] RF_Bank0_EntryNum_OC,
    input [1:0] RF_Bank1_EntryNum_OC,
    input [1:0] RF_Bank2_EntryNum_OC,
    input [1:0] RF_Bank3_EntryNum_OC,
    input [3:0] RF_Dout_Valid,//indicate if the data out of each register file is valid
    input [3:0] RF_SrcNum_OC,//indicate the output data of each regsiter file bank belongs to src1 or src2
    //interface with ALU and LD/ST
    output reg [2:0] OC_WarpID_ALU,//it is generated  by encoding input IU_Grant
    output reg [15:0] OC_Imme_Addr_ALU,
	output reg OC_RegWrite_ALU,
	output reg OC_MemWrite_ALU,
	output reg OC_MemRead_ALU,
	output reg [3:0] OC_ALU_Opcode_ALU,
	output reg OC_Share_Globalbar_ALU,
	output reg OC_Imme_Valid_ALU,
    output reg OC_BEQ_ALU,
    output reg OC_BLT_ALU,
    output reg [4:0] OC_Dst_PhyRegAddr_ALU,
    output reg [255:0] OC_Src1_Date_ALU,
    output reg [255:0] OC_Src2_Date_ALU,
    output reg [7:0] OC_Active_Mask_ALU,
    output reg [1:0] OC_SB_Release_EntNum_ALU,
    output reg OC_LwSw_Addr_Ready,
    input [255:0] ALU_Result,//used to update the effective address of lw/sw instruction in OC
    input LdSt_Replay,//the replay signal sent from LD_ST Unit
    input [7:0] LdSt_Busy,//indicate the LD/ST unit of which warp is busy, meaning its MSHR are processing a cache miss
    input [7:0] Replay_Active_Mask//the threads which didn't access the memory during current clock will be recored in this active mask
);
    integer fp;
    initial fp=$fopen("oc_received_instruction.txt","w");
    integer i;
    reg [3:0] OC_Valid;//indicate if the entry of OC is occupied
    reg [2:0] OC_WarpID [3:0];//the warp ID of current stored instruction
    reg [3:0] OC_Imme_Valid;
    reg [15:0] OC_Imme_Addr [3:0];
    reg [3:0] OC_Share_GlobalBar;
    reg [3:0] OC_ALU_Opcode [3:0];
    reg [3:0] OC_RegWrite;
    reg [3:0] OC_MemWrite;
    reg [3:0] OC_MemRead;
    reg [4:0] OC_Dst_PhyRegAddr [3:0];
    reg [255:0] OC_Src1_Data [3:0];
    reg [3:0] OC_Src1_Ready;
    reg [255:0] OC_Src2_Data [3:0];
    reg [3:0] OC_Src2_Ready;
    reg [7:0] OC_Active_Mask [3:0];
    reg [3:0] OC_BLT;
    reg [3:0] OC_BEQ;
    reg [1:0] OC_SB_Release_EntNum [3:0];
    reg [3:0] OC_Lw_Sw_Addr_Ready;
    /////////
    reg [2:0] Encoded_WarpID;
    ///////////////////////////////////////////////
    //when an instruction is issued from IB, then update below entries of OC
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            OC_Valid<='b0;
            OC_Lw_Sw_Addr_Ready<='b0;
            for(i=0;i<4;i=i+1)begin
                OC_WarpID[i]<='bx;
                OC_Imme_Valid[i]<='bx;
                OC_Imme_Addr[i]<='bx;
                OC_Share_GlobalBar[i]<='bx;
                OC_ALU_Opcode[i]<='bx;
                OC_RegWrite[i]<='bx;
                OC_MemWrite[i]<='bx;
                OC_MemRead[i]<='bx;
                OC_Dst_PhyRegAddr[i]<='bx;
                OC_Active_Mask[i]<='bx;
                OC_BLT[i]<='bx;
                OC_BEQ[i]<='bx;
                OC_SB_Release_EntNum[i]<='bx;
            end
        end else begin
            //Allocate a new entry in OC
            if(|IU_Grant)begin
                OC_Valid[OC_EntryNum_RAU]<=!OC_Valid[OC_EntryNum_RAU];
                OC_WarpID[OC_EntryNum_RAU]<=Encoded_WarpID;
                OC_Imme_Valid[OC_EntryNum_RAU]<=IB_Imme_Valid_OC;
                OC_Imme_Addr[OC_EntryNum_RAU]<=IB_Imme_Addr_OC;
                OC_Share_GlobalBar[OC_EntryNum_RAU]<=IB_Share_Globalbar_OC;
                OC_ALU_Opcode[OC_EntryNum_RAU]<=IB_ALU_Opcode_OC;
                OC_RegWrite[OC_EntryNum_RAU]<=IB_RegWrite_OC;
                OC_MemWrite[OC_EntryNum_RAU]<=IB_MemWrite_OC;
                OC_MemRead[OC_EntryNum_RAU]<=IB_MemRead_OC;
                OC_Dst_PhyRegAddr[OC_EntryNum_RAU]<=RAU_Dst_PhyRegAddr;
                OC_Active_Mask[OC_EntryNum_RAU]<=IB_Active_Mask_OC;
                OC_BLT[OC_EntryNum_RAU]<=IB_BLT_OC;
                OC_BEQ[OC_EntryNum_RAU]<=IB_BEQ_OC;
                OC_SB_Release_EntNum[OC_EntryNum_RAU]<=SB_Release_EntNum_OC;
                //This signal will used to judge if the entry can be released
                //so for normal instruciton, it will be set to 1 when an instruction is sent from IB and enter into OC
                //but for lw/sw, the first time issue, the instruction goes into ALU and calculate the address and write back then set address ready to 1
                //the next time issue to ld/st
                OC_Lw_Sw_Addr_Ready[OC_EntryNum_RAU]<=1'b0;
                
            end
            //////////////////////
            //Release a OC entry
            for(i=0;i<4;i=i+1)begin
                //if a lw/sw is issued to ALU and LD/ST unit, and the memory accessing address of all threads cannot be accomadated by one cache line
                //the replay signal will be activated, then the valid bit cannot be flipped 
                if(EX_IU_Grant[i])begin
                    if(OC_MemWrite[i]||OC_MemRead[i])begin//the issued instruction is a lw/sw
                        if(OC_Lw_Sw_Addr_Ready[i])begin//if the address is ready we check the replay signal
                            if(!LdSt_Replay)begin
                                OC_Valid[i]<=!OC_Valid[i];
                            end else begin
                                OC_Active_Mask[i]<=Replay_Active_Mask;
                            end
                        end else begin//not ready, update src1 data to effective address
                            OC_Lw_Sw_Addr_Ready[i]<= !OC_Lw_Sw_Addr_Ready[i];
                        end
                    end else begin//normal instruction , just release the OC entry
                        OC_Valid[i]<=!OC_Valid[i];
                    end
                end 
            end
        end
    end
    /////////////////////////
    //when source register date is read out from the RF, then update below entries
    always@(posedge clk)begin
        //NOTE: the ready bit don't need to reset ,since every time if a new instruction is issued from the 
        //IB, we will write into the ready correct value
        ////////////////////////////
        //take account for the cases when the source register is $8 or $16
        //src1
        if(|IU_Grant)begin//the ready bit of the OC should be sent only when a valid instruction comes out from the IB
            if(IB_Src1_Out[5])begin
            //if the source is not valid, then we directly set its ready bit to 1,
            //if it is ready but it is a  special regsiter which means we can get the data for this register from RAU within current clock
            //then we also set the ready bit to 1, otherwise we set the ready bit to zero and wait for it comes out from RF
                if(IB_Src1_Out[4:0]==8||IB_Src1_Out[4:0]==16)begin
                    OC_Src1_Ready[OC_EntryNum_RAU]<=1'b1;  
                    OC_Src1_Data[OC_EntryNum_RAU]<=RAU_Src1_Reg8_16_Data;
                end else begin
                    OC_Src1_Ready[OC_EntryNum_RAU]<=1'b0; 
                end
            end else begin
                OC_Src1_Ready[OC_EntryNum_RAU]<=1'b1;
            end
            //src2
            if(IB_Src2_Out[5])begin
                if(IB_Src2_Out[4:0]==8||IB_Src2_Out[4:0]==16)begin
                    OC_Src2_Ready[OC_EntryNum_RAU]<=1'b1;  
                    OC_Src2_Data[OC_EntryNum_RAU]<=RAU_Src2_Reg8_16_Data;
                end else begin
                    OC_Src2_Ready[OC_EntryNum_RAU]<=1'b0; 
                end
            end else begin
                OC_Src2_Ready[OC_EntryNum_RAU]<=1'b1;
            end
        end    
        //when data are read out from RF
        //RF bank0 output data
        if(RF_Dout_Valid[0])begin
            if(!RF_SrcNum_OC[0])begin//src1
                OC_Src1_Data[RF_Bank0_EntryNum_OC]<=RF_Out_Bank0;
                OC_Src1_Ready[RF_Bank0_EntryNum_OC]<=1'b1;
            end else begin//src2
                OC_Src2_Data[RF_Bank0_EntryNum_OC]<=RF_Out_Bank0;
                OC_Src2_Ready[RF_Bank0_EntryNum_OC]<=1'b1;
            end
        end
        //RF bank1 output data
        if(RF_Dout_Valid[1])begin
            if(!RF_SrcNum_OC[1])begin//src1
                OC_Src1_Data[RF_Bank1_EntryNum_OC]<=RF_Out_Bank1;
                OC_Src1_Ready[RF_Bank1_EntryNum_OC]<=1'b1;
            end else begin//src2
                OC_Src2_Data[RF_Bank1_EntryNum_OC]<=RF_Out_Bank1;
                OC_Src2_Ready[RF_Bank1_EntryNum_OC]<=1'b1;
            end
        end
        //RF bank2 output data
        if(RF_Dout_Valid[2])begin
            if(!RF_SrcNum_OC[2])begin//src1
                OC_Src1_Data[RF_Bank2_EntryNum_OC]<=RF_Out_Bank2;
                OC_Src1_Ready[RF_Bank2_EntryNum_OC]<=1'b1;
            end else begin//src2
                OC_Src2_Data[RF_Bank2_EntryNum_OC]<=RF_Out_Bank2;
                OC_Src2_Ready[RF_Bank2_EntryNum_OC]<=1'b1;
            end
        end
        //RF bank3 output data
        if(RF_Dout_Valid[3])begin
            if(!RF_SrcNum_OC[3])begin//src1
                OC_Src1_Data[RF_Bank3_EntryNum_OC]<=RF_Out_Bank3;
                OC_Src1_Ready[RF_Bank3_EntryNum_OC]<=1'b1;
            end else begin//src2
                OC_Src2_Data[RF_Bank3_EntryNum_OC]<=RF_Out_Bank3;
                OC_Src2_Ready[RF_Bank3_EntryNum_OC]<=1'b1;
            end
        end
        ////////////////////////////////
        //update the src1 data to lw/sw effective address
        for(i=0;i<4;i=i+1)begin
            //if a lw/sw is issued to ALU and LD/ST unit, and the memory accessing address of all threads cannot be accomadated by one cache line
            //the replay signal will be activated, then the valid bit cannot be flipped 
            if(EX_IU_Grant[i]&&(OC_MemWrite[i]||OC_MemRead[i])&&!OC_Lw_Sw_Addr_Ready[i])begin
                OC_Src1_Data[i]<=ALU_Result;
            end 
        end
    end
    //////////////////////////
    //always block for encoding the input 8bit warp ID into 3 bit
    always@(*)begin
        case(IU_Grant)
            8'b0000_0010:Encoded_WarpID=3'b001;
            8'b0000_0100:Encoded_WarpID=3'b010;
            8'b0000_1000:Encoded_WarpID=3'b011;
            8'b0001_0000:Encoded_WarpID=3'b100;
            8'b0010_0000:Encoded_WarpID=3'b101;
            8'b0100_0000:Encoded_WarpID=3'b110;
            8'b1000_0000:Encoded_WarpID=3'b111;
            default:Encoded_WarpID=3'b000;
        endcase
    end
    //always block for generating output the aviable OC entry sequence number
    always@(*)begin
        casez(OC_Valid)
            4'bzz01:OC_EntryNum_RAU=2'b01;
            4'bz011:OC_EntryNum_RAU=2'b10;
            4'b0111:OC_EntryNum_RAU=2'b11;
            default:OC_EntryNum_RAU=2'b00;
        endcase
    end
    assign OC_Full=&OC_Valid;
    ///////////////////////////////////////////////////
    //always blocks for generating issue request to EX Issue Unit
    //if two source data are both ready, then we check if the instruciton is a lw or sw,
    //if it is, then we check if current the MSHR of corresponding warp is busy, if it is busy,
    //then then OC should not send a request to EX issue unit
    //if the instruction is a normal one, it can send a request to Issue unit,
    //but the Issue unit will see if one of 8 MSHR has done with cache miss for a lw, since the lw need to go to
    //the wb stage and write the fetch-out date bake to register file, if there is a case, the issue unit will not give 
    //any grants for OC until the MSHR done signal is zero.
    always@(*)begin
        OC_IssReq_EX_IU='b0;
        for(i=0;i<4;i=i+1)begin
            //since once the instruction has left from the OC, we just reset the valid, so the src ready bit will keep the same value
            //so we have to use the valid bit to make sure the instruction is qualified to be issued
            if(OC_Src1_Ready[i]&&OC_Src2_Ready[i]&&OC_Valid[i])begin
                if(OC_MemRead[i]||OC_MemWrite[i])begin
                    if(!LdSt_Busy[OC_WarpID[i]])begin
                        OC_IssReq_EX_IU[i]=1'b1;
                    end
                end else begin
                    OC_IssReq_EX_IU[i]=1'b1;
                end
            end
        end
    end
    /////////////////////////////
    //always for generating the oc output for alu and ld/st unit
    always@(*)begin
        OC_WarpID_ALU=OC_WarpID[0];
        OC_Imme_Addr_ALU=OC_Imme_Addr[0];
	    OC_RegWrite_ALU=OC_RegWrite[0];
	    OC_MemWrite_ALU=OC_MemWrite[0];
	    OC_MemRead_ALU=OC_MemRead[0];
	    OC_ALU_Opcode_ALU=OC_ALU_Opcode[0];
	    OC_Share_Globalbar_ALU=OC_Share_GlobalBar[0];
	    OC_Imme_Valid_ALU=OC_Imme_Valid[0];
        OC_BEQ_ALU=OC_BEQ[0];
        OC_BLT_ALU=OC_BLT[0];
        OC_Dst_PhyRegAddr_ALU=OC_Dst_PhyRegAddr[0];
        OC_Src1_Date_ALU=OC_Src1_Data[0];
        OC_Src2_Date_ALU=OC_Src2_Data[0];
        OC_Active_Mask_ALU=OC_Active_Mask[0];
        OC_SB_Release_EntNum_ALU=OC_SB_Release_EntNum[0];
        OC_LwSw_Addr_Ready=OC_Lw_Sw_Addr_Ready[0];
        //default assignment
        for(i=1;i<4;i=i+1)begin
            if(EX_IU_Grant[i])begin
                OC_WarpID_ALU=OC_WarpID[i];
                OC_Imme_Addr_ALU=OC_Imme_Addr[i];
                OC_RegWrite_ALU=OC_RegWrite[i];
                OC_MemWrite_ALU=OC_MemWrite[i];
                OC_MemRead_ALU=OC_MemRead[i];
                OC_ALU_Opcode_ALU=OC_ALU_Opcode[i];
                OC_Share_Globalbar_ALU=OC_Share_GlobalBar[i];
                OC_Imme_Valid_ALU=OC_Imme_Valid[i];
                OC_BEQ_ALU=OC_BEQ[i];
                OC_BLT_ALU=OC_BLT[i];
                OC_Dst_PhyRegAddr_ALU=OC_Dst_PhyRegAddr[i];
                OC_Src1_Date_ALU=OC_Src1_Data[i];
                OC_Src2_Date_ALU=OC_Src2_Data[i];
                OC_Active_Mask_ALU=OC_Active_Mask[i];
                OC_SB_Release_EntNum_ALU=OC_SB_Release_EntNum[i];
                OC_LwSw_Addr_Ready=OC_Lw_Sw_Addr_Ready[i];
            end
        end
    end
    //注意：SIMT中WB warp�?8bit,记得在SIMT 中将WB传回的Warp ID 变为3bit
endmodule