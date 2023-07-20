`timescale 1ns/100ps
module I_Buffer_n_ScoreBoard(
    input clk,
    input rst_n,
    //interface with ID stage
    output [7:0] IB_Full,
    output [7:0] IB_Empty,
    input [5:0] Src1_ID0_IB, //rs regsiter address
	input [5:0] Src1_ID1_IB,
	input [5:0] Src2_ID0_IB,//rt regsiter address
	input [5:0] Src2_ID1_IB,
	input [5:0] Dst_ID0_IB,//rt/rd register address
	input [5:0] Dst_ID1_IB,
	input [15:0] Imme_ID0_IB, //immediate address
	input [15:0] Imme_ID1_IB,
	input RegWrite_ID0_IB,//similar signals in pipelined cpu
	input RegWrite_ID1_IB,
	input MemWrite_ID0_IB,
	input MemWrite_ID1_IB,
	input MemRead_ID0_IB,//besides using this signal to access the data cache, this signal is also used to select the correct result to write into register file
	input MemRead_ID1_IB,
	input [3:0] ALUop_ID0_IB,
	input [3:0] ALUop_ID1_IB,
	input Share_Globalbar_ID0_IB,//indicate the type of lw, sw instruction, the local memory can be accessed by all threads and threads block, the global memory is used to exchange the data between GPU and CPU
	input Share_Globalbar_ID1_IB,
	input Imme_Valid_ID0_IB,//used to indicate current instruction is a immediate type
	input Imme_Valid_ID1_IB,
    input BEQ_ID0_IB,
    input BEQ_ID1_IB,
    input BLT_ID0_IB,
    input BLT_ID1_IB,
    input [7:0] ID0_Active_Mask_SIMT_IB,
    input [7:0] ID1_Active_Mask_SIMT_IB,
    input [7:0] WarpID0_SIMT_IB,
    input [7:0] WarpID1_SIMT_IB,
    ///////////////////////////
    //interface with IU
    output [7:0] IB_Ready_Issue_IU,
    input [7:0] IU_Grant,
    //////////
    //interafce with OC
    output reg [5:0] Src1_Out, 
	output reg [5:0] Src2_Out,
	output reg [5:0] Dst_Out,
    //interface with RAU
	output reg [15:0] Imme_Addr_Out,
	output reg RegWrite_Out,
	output reg MemWrite_Out,
	output reg MemRead_Out,
	output reg [3:0] ALU_Opcode_Out,
	output reg Share_Globalbar_Out,
	output reg Imme_Valid_Out,
    output reg BEQ_Out,
    output reg BLT_Out,
    output reg [7:0] Active_Mask_Out,
    output reg [1:0] SB_EntNum_OC,
    /////////////////
    //interface with WB for SB entry releasing
    input WB_Release_SB,
    input [2:0] WarpID_from_WB,
    input [1:0] WB_Release_EntNum_SB

);
    reg [7:0] WB_WarpID_SB;
    always@(*)begin
        WB_WarpID_SB='b0;
        case(WarpID_from_WB)
            3'b000: WB_WarpID_SB=8'b0000_0001;
            3'b001: WB_WarpID_SB=8'b0000_0010;
            3'b010: WB_WarpID_SB=8'b0000_0100;
            3'b011: WB_WarpID_SB=8'b0000_1000;
            3'b100: WB_WarpID_SB=8'b0001_0000;
            3'b101: WB_WarpID_SB=8'b0010_0000;
            3'b110: WB_WarpID_SB=8'b0100_0000;
            3'b111: WB_WarpID_SB=8'b1000_0000;
        endcase
    end
    /////////////////////////////
    wire [7:0] IB_WriteEn;
    assign IB_WriteEn=WarpID0_SIMT_IB | WarpID1_SIMT_IB;
    //////////////////////////////////
    //the input signal from ID stage wil be farwarded to these signals through a mux
    wire [5:0] Src1_In [7:0];
    wire [5:0] Src2_In[7:0];
    wire [5:0] Dst_In[7:0];
    wire [15:0] Imme_Addr_In[7:0];
    wire [7:0] RegWrite_In;
    wire [7:0] MemWrite_In;
    wire [7:0] MemRead_In;
    wire [3:0] ALU_Opcode_In [7:0];
    wire [7:0] Share_Globalbar_In;
    wire [7:0] Imme_Valid_In;
    wire [7:0] BEQ_In;
    wire [7:0] BLT_In;
    wire [7:0] Active_Mask_In [7:0];
    //////////////////////////////////
    //signals for OC
    wire [5:0] Src1_Out_x8 [7:0];
    wire [5:0] Src2_Out_x8 [7:0];
    wire [5:0] Dst_Out_x8 [7:0];
    wire [15:0] Imme_Addr_Out_x8 [7:0];
    wire [7:0] RegWrite_Out_x8;
    wire [7:0] MemWrite_Out_x8;
    wire [7:0] MemRead_Out_x8;
    wire [3:0] ALU_Opcode_Out_x8 [7:0];
    wire [7:0] Share_Globalbar_Out_x8;
    wire [7:0] Imme_Valid_Out_x8;
    wire [7:0] BEQ_Out_x8;
    wire [7:0] BLT_Out_x8;
    wire [7:0] Active_Mask_Out_x8 [7:0];
    wire [1:0] SB_EntNum_OC_x8 [7:0];
    always @(*) begin
        case(IU_Grant)
            8'b0000_0010:begin
                Src1_Out=Src1_Out_x8[1];
                Src2_Out=Src2_Out_x8 [1];
                Dst_Out=Dst_Out_x8 [1];
                Imme_Addr_Out=Imme_Addr_Out_x8[1];
                RegWrite_Out=RegWrite_Out_x8[1];
                MemWrite_Out=MemWrite_Out_x8[1];
                MemRead_Out=MemRead_Out_x8[1];
                ALU_Opcode_Out=ALU_Opcode_Out_x8 [1];
                Share_Globalbar_Out=Share_Globalbar_Out_x8[1];
                Imme_Valid_Out=Imme_Valid_Out_x8[1];
                BEQ_Out=BEQ_Out_x8[1];
                BLT_Out=BLT_Out_x8[1];
                Active_Mask_Out=Active_Mask_Out_x8 [1];
                SB_EntNum_OC= SB_EntNum_OC_x8[1];
            end
            8'b0000_0100:begin
                Src1_Out=Src1_Out_x8[2];
                Src2_Out=Src2_Out_x8 [2];
                Dst_Out=Dst_Out_x8 [2];
                Imme_Addr_Out=Imme_Addr_Out_x8[2];
                RegWrite_Out=RegWrite_Out_x8[2];
                MemWrite_Out=MemWrite_Out_x8[2];
                MemRead_Out=MemRead_Out_x8[2];
                ALU_Opcode_Out=ALU_Opcode_Out_x8 [2];
                Share_Globalbar_Out=Share_Globalbar_Out_x8[2];
                Imme_Valid_Out=Imme_Valid_Out_x8[2];
                BEQ_Out=BEQ_Out_x8[2];
                BLT_Out=BLT_Out_x8[2];
                Active_Mask_Out=Active_Mask_Out_x8 [2];
                SB_EntNum_OC= SB_EntNum_OC_x8[2];
            end
            8'b0000_1000:begin
                Src1_Out=Src1_Out_x8[3];
                Src2_Out=Src2_Out_x8 [3];
                Dst_Out=Dst_Out_x8[3];
                Imme_Addr_Out=Imme_Addr_Out_x8[3];
                RegWrite_Out=RegWrite_Out_x8[3];
                MemWrite_Out=MemWrite_Out_x8[3];
                MemRead_Out=MemRead_Out_x8[3];
                ALU_Opcode_Out=ALU_Opcode_Out_x8 [3];
                Share_Globalbar_Out=Share_Globalbar_Out_x8[3];
                Imme_Valid_Out=Imme_Valid_Out_x8[3];
                BEQ_Out=BEQ_Out_x8[3];
                BLT_Out=BLT_Out_x8[3];
                Active_Mask_Out=Active_Mask_Out_x8 [3];
                SB_EntNum_OC= SB_EntNum_OC_x8[3];
            end
            8'b0001_0000:begin
                Src1_Out=Src1_Out_x8[4];
                Src2_Out=Src2_Out_x8 [4];
                Dst_Out=Dst_Out_x8 [4];
                Imme_Addr_Out=Imme_Addr_Out_x8[4];
                RegWrite_Out=RegWrite_Out_x8[4];
                MemWrite_Out=MemWrite_Out_x8[4];
                MemRead_Out=MemRead_Out_x8[4];
                ALU_Opcode_Out=ALU_Opcode_Out_x8 [4];
                Share_Globalbar_Out=Share_Globalbar_Out_x8[4];
                Imme_Valid_Out=Imme_Valid_Out_x8[4];
                BEQ_Out=BEQ_Out_x8[4];
                BLT_Out=BLT_Out_x8[4];
                Active_Mask_Out=Active_Mask_Out_x8 [4];
                SB_EntNum_OC= SB_EntNum_OC_x8[4];
            end
            8'b0010_0000:begin
                Src1_Out=Src1_Out_x8[5];
                Src2_Out=Src2_Out_x8 [5];
                Dst_Out=Dst_Out_x8 [5];
                Imme_Addr_Out=Imme_Addr_Out_x8[5];
                RegWrite_Out=RegWrite_Out_x8[5];
                MemWrite_Out=MemWrite_Out_x8[5];
                MemRead_Out=MemRead_Out_x8[5];
                ALU_Opcode_Out=ALU_Opcode_Out_x8 [5];
                Share_Globalbar_Out=Share_Globalbar_Out_x8[5];
                Imme_Valid_Out=Imme_Valid_Out_x8[5];
                BEQ_Out=BEQ_Out_x8[5];
                BLT_Out=BLT_Out_x8[5];
                Active_Mask_Out=Active_Mask_Out_x8 [5];
                SB_EntNum_OC= SB_EntNum_OC_x8[5];
            end
            8'b0100_0000:begin
                Src1_Out=Src1_Out_x8[6];
                Src2_Out=Src2_Out_x8 [6];
                Dst_Out=Dst_Out_x8 [6];
                Imme_Addr_Out=Imme_Addr_Out_x8[6];
                RegWrite_Out=RegWrite_Out_x8[6];
                MemWrite_Out=MemWrite_Out_x8[6];
                MemRead_Out=MemRead_Out_x8[6];
                ALU_Opcode_Out=ALU_Opcode_Out_x8 [6];
                Share_Globalbar_Out=Share_Globalbar_Out_x8[6];
                Imme_Valid_Out=Imme_Valid_Out_x8[6];
                BEQ_Out=BEQ_Out_x8[6];
                BLT_Out=BLT_Out_x8[6];
                Active_Mask_Out=Active_Mask_Out_x8 [6];
                SB_EntNum_OC= SB_EntNum_OC_x8[6];
            end
            8'b1000_0000:begin
                Src1_Out=Src1_Out_x8[7];
                Src2_Out=Src2_Out_x8 [7];
                Dst_Out=Dst_Out_x8 [7];
                Imme_Addr_Out=Imme_Addr_Out_x8[7];
                RegWrite_Out=RegWrite_Out_x8[7];
                MemWrite_Out=MemWrite_Out_x8[7];
                MemRead_Out=MemRead_Out_x8[7];
                ALU_Opcode_Out=ALU_Opcode_Out_x8 [7];
                Share_Globalbar_Out=Share_Globalbar_Out_x8[7];
                Imme_Valid_Out=Imme_Valid_Out_x8[7];
                BEQ_Out=BEQ_Out_x8[7];
                BLT_Out=BLT_Out_x8[7];
                Active_Mask_Out=Active_Mask_Out_x8 [7];
                SB_EntNum_OC= SB_EntNum_OC_x8[7];
            end
            default:begin
                Src1_Out=Src1_Out_x8[0];
                Src2_Out=Src2_Out_x8 [0];
                Dst_Out=Dst_Out_x8 [0];
                Imme_Addr_Out=Imme_Addr_Out_x8[0];
                RegWrite_Out=RegWrite_Out_x8[0];
                MemWrite_Out=MemWrite_Out_x8[0];
                MemRead_Out=MemRead_Out_x8[0];
                ALU_Opcode_Out=ALU_Opcode_Out_x8 [0];
                Share_Globalbar_Out=Share_Globalbar_Out_x8[0];
                Imme_Valid_Out=Imme_Valid_Out_x8[0];
                BEQ_Out=BEQ_Out_x8[0];
                BLT_Out=BLT_Out_x8[0];
                Active_Mask_Out=Active_Mask_Out_x8 [0];
                SB_EntNum_OC= SB_EntNum_OC_x8[0];
            end
        endcase
    end
    //////////////////////////////
    //signals between SB and IB
    wire [7:0] SB_Full;
    wire [3:0] IB_Inst_Valid_SB [7:0];
    wire [5:0] IB_Src1_Entry0_SB [7:0];
    wire [5:0] IB_Src1_Entry1_SB[7:0];
    wire [5:0] IB_Src1_Entry2_SB[7:0];
    wire [5:0] IB_Src1_Entry3_SB[7:0];
    wire [5:0] IB_Src2_Entry0_SB[7:0];
    wire [5:0] IB_Src2_Entry1_SB[7:0];
    wire [5:0] IB_Src2_Entry2_SB[7:0];
    wire [5:0] IB_Src2_Entry3_SB[7:0];
    wire [5:0] IB_Dst_Entry0_SB[7:0];
    wire [5:0] IB_Dst_Entry1_SB[7:0];
    wire [5:0] IB_Dst_Entry2_SB[7:0];
    wire [5:0] IB_Dst_Entry3_SB[7:0];
    wire [3:0] SB_Ready_Issue_IB[7:0];
    wire [3:0] IB_Issued_SB[7:0];
    /////////////////////////////
    genvar i;
    generate
        for(i=0;i<8;i=i+1)begin:IB_SB_Generate_Block
            //if the data can be written into IB is controlled by write_en signal
            assign Src1_In [i]=WarpID0_SIMT_IB[i]?Src1_ID0_IB:Src1_ID1_IB;
            assign Src2_In [i]=WarpID0_SIMT_IB[i]?Src2_ID0_IB:Src2_ID1_IB;
            assign Dst_In [i]=WarpID0_SIMT_IB[i]?Dst_ID0_IB:Dst_ID1_IB;
            assign Imme_Addr_In[i]=WarpID0_SIMT_IB[i]?Imme_ID0_IB:Imme_ID1_IB;
            assign RegWrite_In[i]=WarpID0_SIMT_IB[i]?RegWrite_ID0_IB:RegWrite_ID1_IB;
            assign MemWrite_In[i]=WarpID0_SIMT_IB[i]?MemWrite_ID0_IB:MemWrite_ID1_IB;
            assign MemRead_In[i]=WarpID0_SIMT_IB[i]?MemRead_ID0_IB:MemRead_ID1_IB;
            assign ALU_Opcode_In [i]=WarpID0_SIMT_IB[i]?ALUop_ID0_IB:ALUop_ID1_IB;
            assign Share_Globalbar_In[i]=WarpID0_SIMT_IB[i]?Share_Globalbar_ID0_IB:Share_Globalbar_ID1_IB;
            assign Imme_Valid_In[i]=WarpID0_SIMT_IB[i]?Imme_Valid_ID0_IB:Imme_Valid_ID1_IB;
            assign BEQ_In[i]=WarpID0_SIMT_IB[i]?BEQ_ID0_IB:BEQ_ID1_IB;
            assign BLT_In[i]=WarpID0_SIMT_IB[i]?BLT_ID0_IB:BLT_ID1_IB;
            assign Active_Mask_In[i]=WarpID0_SIMT_IB[i]?ID0_Active_Mask_SIMT_IB:ID1_Active_Mask_SIMT_IB;
            I_Buffer_Warp IB(
                .clk(clk),
                .rst_n(rst_n),
                .wen(IB_WriteEn[i]),
                .IB_Inst_Valid_SB(IB_Inst_Valid_SB[i]),
                .IB_Src1_Entry0_SB(IB_Src1_Entry0_SB[i]),
                .IB_Src1_Entry1_SB(IB_Src1_Entry1_SB[i]),
                .IB_Src1_Entry2_SB(IB_Src1_Entry2_SB[i]),
                .IB_Src1_Entry3_SB(IB_Src1_Entry3_SB[i]),
                .IB_Src2_Entry0_SB(IB_Src2_Entry0_SB[i]),
                .IB_Src2_Entry1_SB(IB_Src2_Entry1_SB[i]),
                .IB_Src2_Entry2_SB(IB_Src2_Entry2_SB[i]),
                .IB_Src2_Entry3_SB(IB_Src2_Entry3_SB[i]),
                .IB_Dst_Entry0_SB(IB_Dst_Entry0_SB[i]),
                .IB_Dst_Entry1_SB(IB_Dst_Entry1_SB[i]),
                .IB_Dst_Entry2_SB(IB_Dst_Entry2_SB[i]),
                .IB_Dst_Entry3_SB(IB_Dst_Entry3_SB[i]),
                .SB_Ready_Issue_IB(SB_Ready_Issue_IB[i]),
                .IB_Issued_SB(IB_Issued_SB[i]),
                .SB_Full(SB_Full[i]),
                /////////////////////////////
                .Src1_In(Src1_In[i]),
                .Src2_In(Src2_In[i]),
                .Dst_In(Dst_In[i]),
                .Imme_Addr_In(Imme_Addr_In[i]),
                .RegWrite_In(RegWrite_In[i]),
                .MemWrite_In(MemWrite_In[i]),
                .MemRead_In(MemRead_In[i]),
                .ALU_Opcode_In(ALU_Opcode_In[i]),
                .Share_Globalbar_In(Share_Globalbar_In[i]),
                .Imme_Valid_In(Imme_Valid_In[i]),
                .BEQ_In(BEQ_In[i]),
                .BLT_In(BLT_In[i]),
                .Active_Mask_In(Active_Mask_In[i]),
                ////////////////////////////
                .Src1_Out(Src1_Out_x8[i]), 
                .Src2_Out(Src2_Out_x8[i]),
                .Dst_Out(Dst_Out_x8[i]),
                .Imme_Addr_Out(Imme_Addr_Out_x8[i]),
                .RegWrite_Out(RegWrite_Out_x8[i]),
                .MemWrite_Out(MemWrite_Out_x8[i]),
                .MemRead_Out(MemRead_Out_x8[i]),
                .ALU_Opcode_Out(ALU_Opcode_Out_x8[i]),
                .Share_Globalbar_Out(Share_Globalbar_Out_x8[i]),
                .Imme_Valid_Out(Imme_Valid_Out_x8[i]),
                .BEQ_Out_OC(BEQ_Out_x8[i]),
                .BLT_Out_OC(BLT_Out_x8[i]),
                .Active_Mask_Out(Active_Mask_Out_x8[i]),
                .IB_Full(IB_Full[i]),
                .IB_Empty(IB_Empty[i]),
                .IB_Ready_Issue_IU(IB_Ready_Issue_IU[i]),
                .IU_Grant(IU_Grant[i])
            );
            ///////////////////
            ScoreBoard_Warp SB(
                .clk(clk),
                .rst_n(rst_n),
                .IB_Inst_Valid_SB(IB_Inst_Valid_SB[i]),
                .IB_Src1_Entry0_SB(IB_Src1_Entry0_SB[i]),
                .IB_Src1_Entry1_SB(IB_Src1_Entry1_SB[i]),
                .IB_Src1_Entry2_SB(IB_Src1_Entry2_SB[i]),
                .IB_Src1_Entry3_SB(IB_Src1_Entry3_SB[i]),
                .IB_Src2_Entry0_SB(IB_Src2_Entry0_SB[i]),
                .IB_Src2_Entry1_SB(IB_Src2_Entry1_SB[i]),
                .IB_Src2_Entry2_SB(IB_Src2_Entry2_SB[i]),
                .IB_Src2_Entry3_SB(IB_Src2_Entry3_SB[i]),
                .IB_Dst_Entry0_SB(IB_Dst_Entry0_SB[i]),
                .IB_Dst_Entry1_SB(IB_Dst_Entry1_SB[i]),
                .IB_Dst_Entry2_SB(IB_Dst_Entry2_SB[i]),
                .IB_Dst_Entry3_SB(IB_Dst_Entry3_SB[i]),
                .SB_Ready_Issue_IB(SB_Ready_Issue_IB[i]),
                .IB_Issued_SB(IB_Issued_SB[i]),
                .SB_Full(SB_Full[i]),
                .SB_EntNum_OC(SB_EntNum_OC_x8[i]),
                .WB_Release_SB(WB_WarpID_SB[i]&&WB_Release_SB),//the warp id is one cannot stand for the entry can be released
                .WB_Release_EntNum_SB(WB_Release_EntNum_SB)//since for replayed lw, part of its result can be writen into RF in advance, but the release sb valid signal is 0
            );
        end
    endgenerate
endmodule