`timescale 1ns/100ps
module GPGPU_TOP(
    input ClkIn,
    input rst_pin,
    input rxd_pin,
    output txd_pin,
    //////////
    input BTNL,
    output LED0,
    output LED1,
    output LED2,
    output LED3,
    output LED4,
    output LED5,
    output LED7
);
    //interface between WS and IF
    wire [31:0] WS_IF_PC_Warp0;//the instruction fetch address for instruction cache
    wire [31:0] WS_IF_PC_Warp1;
    wire [7:0] WS_IF_Active_Mask0;//active mask for current warp
    wire [7:0] WS_IF_Active_Mask1;
    wire [7:0] WS_IF_WarpID0;//the warp id  for instruction cache; you can also considered it as a valid bit for instruction; if the instruction is flushed; the signalis 0
    wire [7:0] WS_IF_WarpID1;
    wire [31:0] WS_IF_PC0_Plus4;
    wire [31:0] WS_IF_PC1_Plus4;
    wire Flush_IF;//the flush signal for IF stage
    wire [7:0] Flush_Warp;//the sequence number of warp to be deleted in IF stage
    //////////////////////////////////
    //Interface between WS and RAU
    wire [7:0] RAU_Release_Warp_WS;
    //the numebr of available register sent from regsiter allocation unit
    wire [5:0] Num_Of_AviReg;//NOTE: The maximum value is 32; so we need 6bit to accomodate this value
    wire [4:0] New_AllocReg_Num;//the maximum value is 16; so needs five bits
    wire [7:0] New_Scheduled_HW_WarpID;//at most two HW warps can be scheduled at the same time
    wire [31:0] WS_WarpID_Even_RAU;//sw warp ID
    wire [31:0] WS_WarpID_Odd_RAU;
    ///////////////
    //inteface between IF and Decode
    wire [31:0] IF_ID0_Instruction;
    wire [31:0] IF_ID1_Instruction;
    wire [7:0] IF_ID0_Active_Mask;
    wire [7:0] IF_ID1_Active_Mask;
    wire [7:0] IF_ID0_WarpID;
    wire [7:0] IF_ID1_WarpID;
    wire [31:0] IF_ID0_PC_Plus4;
    wire [31:0] IF_ID1_PC_Plus4;
    wire [7:0] IB_Full;
    wire [7:0] IB_Empty;
    //interface between IB and SIMT and IB
    wire [5:0] Src1_ID0_IB; 
	wire [5:0] Src1_ID1_IB;
	wire [5:0] Src2_ID0_IB;
	wire [5:0] Src2_ID1_IB;
	wire [5:0] Dst_ID0_IB;
	wire [5:0] Dst_ID1_IB;
	wire [15:0] Imme_ID0_IB; 
	wire [15:0] Imme_ID1_IB;
	wire RegWrite_ID0_IB;
	wire RegWrite_ID1_IB;
	wire MemWrite_ID0_IB;
	wire MemWrite_ID1_IB;
	wire MemRead_ID0_IB;
	wire MemRead_ID1_IB;
	wire [3:0] ALUop_ID0_IB;
	wire [3:0] ALUop_ID1_IB;
	wire Share_Globalbar_ID0_IB;
	wire Share_Globalbar_ID1_IB;
	wire Imme_Valid_ID0_IB;
	wire Imme_Valid_ID1_IB;
    wire BEQ_ID0_IB;
    wire BEQ_ID1_IB;
    wire BLT_ID0_IB;
    wire BLT_ID1_IB;
    wire [7:0] SIMT_Full;
    wire [7:0] SIMT_TwoMoreVacant;
    wire [31:0] SIMT_Poped_PC_ID0;
    wire [31:0] SIMT_Poped_PC_ID1;
    wire [7:0] SIMT_Poped_Active_Mask_ID0;
    wire [7:0] SIMT_Poped_Active_Mask_ID1;
    wire [7:0] ID0_Active_Mask_SIMT_IB;
    wire [7:0] ID1_Active_Mask_SIMT_IB;
	wire DotS_ID0_SIMT;
	wire DotS_ID1_SIMT;
    wire SIMT_Div_SyncBar_Token_ID0;
    wire SIMT_Div_SyncBar_Token_ID1;
	wire Call_ID0_SIMT;
	wire Call_ID1_SIMT;
	wire Ret_ID0_SIMT;
	wire Ret_ID1_SIMT;
	wire Branch_ID0_SIMT;
	wire Branch_ID1_SIMT;
    //interface between ID and RAU
    wire [7:0] ID_Warp_Release_RAU;
    //interface between ID and SIMT and WS
    wire [31:0] ID0_PCplus4_SIMT_UpdatePC_WS;
	wire [31:0] ID1_PCplus4_SIMT_UpdatePC_WS;
    wire [31:0] ID0_Call_ReturnAddr_SIMT;
    wire [31:0] ID1_Call_ReturnAddr_SIMT;
    wire [7:0] ID0_Active_Mask_WS;
    wire ID0_PC_Update_SIMT_WS;
    wire ID0_Stall_PC_WS;
    wire [7:0] WarpID0_SIMT_IB;
    wire [7:0] WarpID0_WS;
    wire ID1_PC_Update_SIMT_WS;
    wire [7:0] ID1_Active_Mask_WS;
    wire ID1_Stall_PC_WS;
    wire [7:0] WarpID1_SIMT_IB;
    wire[7:0] WarpID1_WS;//from ID to WS
    //interfacebetween IB and IU
    wire [7:0] IB_Ready_Issue_IU;
    wire [7:0] IU_Grant;
    //interafce between IB and OC
    wire [5:0] Src1_Out; 
	wire [5:0] Src2_Out;
	wire [5:0] Dst_Out;
	wire [15:0] Imme_Addr_Out;
	wire RegWrite_Out;
	wire MemWrite_Out;
	wire MemRead_Out;
	wire [3:0] ALU_Opcode_Out;
	wire Share_Globalbar_Out;
	wire Imme_Valid_Out;
    wire BEQ_Out;
    wire BLT_Out;
    wire [7:0] Active_Mask_Out;
    wire [1:0] SB_EntNum_OC;
    //interface between OC and IU
    wire OC_Full;
    //interface between OC and Ex_Issue_Unit
    wire [3:0] OC_IssReq_EX_IU;//the issue request sent to EX issue unit
    wire [3:0] EX_IU_Grant;
    //interface between OC and RAU
    wire [1:0] OC_EntryNum_RAU;//indicate the entry where the readout information should enter; it will be carried with the source register information into RF
    wire [4:0] RAU_Dst_PhyRegAddr;//MSB -> valid bit
    wire [255:0] RAU_Src1_Reg8_16_Data;//Special registers value for $8->thread ID; $16->sw warp ID
    wire [255:0] RAU_Src2_Reg8_16_Data;
    //interface between OC and RF
    wire [255:0] RF_Out_Bank0;
    wire [255:0] RF_Out_Bank1;
    wire [255:0] RF_Out_Bank2;
    wire [255:0] RF_Out_Bank3;
    wire [1:0] RF_Bank0_EntryNum_OC;
    wire [1:0] RF_Bank1_EntryNum_OC;
    wire [1:0] RF_Bank2_EntryNum_OC;
    wire [1:0] RF_Bank3_EntryNum_OC;
    wire [3:0] RF_Dout_Valid;//indicate if the data out of each register file is valid
    wire [3:0] RF_SrcNum_OC;//indicate the wire data of each regsiter file bank belongs to src1 or src2
    //interface between OC and ALU  LD/ST
    wire [2:0] OC_WarpID_ALU;//it is generated  by encoding reg IU_Grant
    wire [15:0] OC_Imme_Addr_ALU;
	wire OC_RegWrite_ALU;
	wire OC_MemWrite_ALU;
	wire OC_MemRead_ALU;
	wire [3:0] OC_ALU_Opcode_ALU;
	wire OC_Share_Globalbar_ALU;
	wire OC_Imme_Valid_ALU;
    wire OC_BEQ_ALU;
    wire OC_BLT_ALU;
    wire [4:0] OC_Dst_PhyRegAddr_ALU;
    wire [255:0] OC_Src1_Date_ALU;
    wire [255:0] OC_Src2_Date_ALU;
    wire [7:0] OC_Active_Mask_ALU;
    wire [1:0] OC_SB_Release_EntNum_ALU;
    wire OC_LwSw_Addr_Ready;
    wire LdSt_Replay;//the replay signal sent from LD_ST Unit
    wire [7:0] LdSt_Busy;//indicate the LD/ST unit of which warp is busy; meaning its MSHR are processing a cache miss
    wire [7:0] Replay_Active_Mask;//the threads which didn't access the memory during current clock will be recored in this active mask
    wire [255:0] ALU_Result;
    //interface between RF and RAU
    wire [1:0] RAU_EntryNum_RF;//the entry of the instruction allocated at the OC
    wire [5:0] Src1_PhyRegAddr;
    wire [5:0] Src2_PhyRegAddr;
    //interface between ALU and SIMT
    wire [2:0] ALU_WarpID_to_SIMT;//warp id sent to SIMT to fetch pc+4 for branch instructions
    wire [31:0] SIMT_PCplus4_ALU;//pc+4 used by branch instructions
    //interface between WB and SIMT
    wire [2:0] WB_WarpID;
    wire WB_Update_SIMT;//the update signal for SIMT is a little different from the one for WS
    wire [7:0] WB_ActiveMask_SIMT;
    //interface between WB and SB
    wire WB_Release_SB;
    wire [1:0] WB_Release_EntNum_SB;
    //interface between WB and WS
    wire WB_PC_Update_WS;
    wire [31:0] WB_PC_Update_Addr_WS;
    wire [7:0] WB_ActiveMask_WS_RF;//the branch taken active mask or active mask for register update
    //interface between WB and RF
    wire WB_Regwrite;
    wire [4:0] WriteBack_PhyRegAddr;
    wire [255:0] WriteBack_Data;//select between the alu result and mem out data
    //interface with EX_Issue_Unit
    wire MSHR_Done;
    ////////////////////////
    wire [9:0] Bram_WrAddr;//share mem address line
    wire [10:0] Bram_RdAddr1;//only readout data in ws
    wire [10:0] Bram_RdAddr2;//only readout data in ic
    wire [10:0] Bram_RdAddr3;//only readout data in dc
    wire [255:0] Data_OneRow;//data for initializing mem
    wire [31:0] Bram_Dout1;//write back dat
    wire [31:0] Bram_Dout2;//write back dat
    wire [255:0] Bram_Dout3;//write back dat
    wire btnl_scen;//used for debug
    ///////
    reg Init_Done;//indicate the warp scheduler can start activating a new warp
    reg Write_Back;
    //interface between  uart and ws
    wire Uart_clk;
    wire Task_Init;//write enable for task memory
    wire [28:0] Task_Init_Data=Data_OneRow[31 -:29];
    wire [7:0] Task_Init_Addr=Bram_WrAddr[7:0];
    wire [7:0] Task_WriteBack_Addr=Bram_RdAddr1[7:0];
    wire [28:0] Task_WriteBack_Data;
    //interface between uart and ic
    wire IC_Init;
    wire [9:0] IC_Init_Addr=Bram_WrAddr;
    wire [31:0] IC_Init_Data=Data_OneRow[31:0];
    wire [9:0] IC_WriteBack_Addr=Bram_RdAddr2[9:0];
    wire [31:0] IC_WriteBack_Data;
    //interface with uart and dc
    wire DC_Init;
    wire [8:0] DC_Init_n_WriteBack_Addr=(!Init_Done)?Bram_WrAddr[8:0]:Bram_RdAddr3[8:0];
    wire [255:0] DC_Init_Data=Data_OneRow;
    wire [255:0] DC_WriteBack_Data;
    assign Bram_Dout1={Task_WriteBack_Data,3'b000};
    assign Bram_Dout2=IC_WriteBack_Data;
    assign Bram_Dout3=DC_WriteBack_Data;

    wire ClkOutBuf, ClkBufG;
    wire rst_high50, rst_high100;
    wire clk, rst_n, rst_uart;
    ///////
    wire rxd_i, txd_o;
    wire LED0_toBuf, LED1_toBuf, LED2_toBuf, LED3_toBuf, LED5_toBuf;
    reg LED4_toBuf, LED7_toBuf;
    IBUF IBUF_CLK       (.I(ClkIn),            .O(ClkOutBuf));
    BUFG BUFG_CLK_50    (.I(ClkBufG),          .O(clk));
    BUFG BUFG_CLK_100   (.I(ClkOutBuf),        .O(Uart_clk));
    BUFG BUFG_rst50     (.I(!rst_high50),      .O(rst_n));
    BUFG BUFG_rst100    (.I(rst_high100),      .O(rst_uart));
    ///
    IBUF IBUF_rxd     (.I (rxd_pin),      .O(rxd_i));
    OBUF OBUF_txd         (.I(txd_o),         .O(txd_pin));
    //
    OBUF OBUF_led0      (.I(LED0_toBuf),      .O(LED0));
    OBUF OBUF_led1      (.I(LED1_toBuf),      .O(LED1));
    OBUF OBUF_led2      (.I(LED2_toBuf),      .O(LED2));
    OBUF OBUF_led3      (.I(LED3_toBuf),      .O(LED3));
    OBUF OBUF_led4      (.I(LED4_toBuf),      .O(LED4));
    OBUF OBUF_led5      (.I(LED5_toBuf),      .O(LED5));
    OBUF OBUF_led7      (.I(LED7_toBuf),      .O(LED7));
    //clock wizard
    clk_wiz_0 clk_wiz_inst1
   (
    // Clock out ports
    .clk_out1(ClkBufG),     // output clk_out1 50MHZ
    // Status and control signals    
   // Clock in ports
    .clk_in1(ClkOutBuf));      // input clk_in1

    //convert asynchrounous reset input to synchronous
    rst_gen rst50( 
        //reset signal for CPU
        .clk_i(clk),          // Receive clock
        .rst_i(rst_pin),           
        .rst_o(rst_high50)     //synchronizaed active high  
    );
    rst_gen rst100( 
        //reset signal for CPU
        .clk_i(Uart_clk),          // Receive clock
        .rst_i(rst_pin),           
        .rst_o(rst_high100)     //synchronizaed active high  
    );

    Warp_Scheduler #(.Test("16x16_draw_circle")) WS (
        .clk(clk),
        .rst_n(rst_n),
        .Uart_clk(Uart_clk),
        .Task_Init(Task_Init),
        .Init_Done(Init_Done),
        .Write_Back(Write_Back),
        .Task_WriteBack_Addr(Task_WriteBack_Addr),
        .Task_WriteBack_Data(Task_WriteBack_Data),
        .Task_Init_Data(Task_Init_Data),
        .Task_Init_Addr(Task_Init_Addr),
        .PC_Update_WB(WB_PC_Update_WS),
        .PC_Update_WB_Addr(WB_PC_Update_Addr_WS),
        .WarpID_from_WB(WB_WarpID),
        .Update_ActiveMask_WB(WB_ActiveMask_WS_RF),
        .PC_Update_ID0_SIMT(ID0_PC_Update_SIMT_WS),
        .Stall_PC_ID0(ID0_Stall_PC_WS),
        .PC_Update_ID0_SIMT_Addr(ID0_PCplus4_SIMT_UpdatePC_WS),
        .WarpID_from_ID0(WarpID0_WS),
        .Update_ActiveMask_ID0(ID0_Active_Mask_WS),
        .PC_Update_ID1_SIMT(ID1_PC_Update_SIMT_WS),
        .Stall_PC_ID1(ID1_Stall_PC_WS),
        .PC_Update_ID1_SIMT_Addr(ID1_PCplus4_SIMT_UpdatePC_WS),
        .WarpID_from_ID1(WarpID1_WS),
        .Update_ActiveMask_ID1(ID1_Active_Mask_WS),
        .WS_IF_PC_Warp0(WS_IF_PC_Warp0),
        .WS_IF_PC_Warp1(WS_IF_PC_Warp1),
        .WS_IF_Active_Mask0(WS_IF_Active_Mask0),
        .WS_IF_Active_Mask1(WS_IF_Active_Mask1),
        .WS_IF_WarpID0(WS_IF_WarpID0),
        .WS_IF_WarpID1(WS_IF_WarpID1),
        .WS_IF_PC0_Plus4(WS_IF_PC0_Plus4),
        .WS_IF_PC1_Plus4(WS_IF_PC1_Plus4),
        .Flush_IF(Flush_IF),
        .Flush_Warp(Flush_Warp),
        .RAU_Release_Warp_WS(RAU_Release_Warp_WS),
        .Num_Of_AviReg(Num_Of_AviReg),
        .New_AllocReg_Num(New_AllocReg_Num),
        .New_Scheduled_HW_WarpID(New_Scheduled_HW_WarpID),
        .WS_WarpID_Even_RAU(WS_WarpID_Even_RAU),
        .WS_WarpID_Odd_RAU(WS_WarpID_Odd_RAU)
    );
    
    Fetch #(.Test("16x16_Draw_Circle")) fetch(
        .clk(clk),
        .rst_n(rst_n),
        .Uart_clk(Uart_clk),
        .IC_Init(IC_Init),
        .Init_Done(Init_Done),
        .IC_Init_Addr(IC_Init_Addr),
        .IC_Init_Data(IC_Init_Data),
        .IC_WriteBack_Addr(IC_WriteBack_Addr),
        .IC_WriteBack_Data(IC_WriteBack_Data),
        .WS_IF_PC_Warp0(WS_IF_PC_Warp0),
        .WS_IF_PC_Warp1(WS_IF_PC_Warp1),
        .WS_IF_Active_Mask0(WS_IF_Active_Mask0),
        .WS_IF_Active_Mask1(WS_IF_Active_Mask1),
        .WS_IF_WarpID0(WS_IF_WarpID0),
        .WS_IF_WarpID1(WS_IF_WarpID1),
        .WS_IF_PC0_Plus4(WS_IF_PC0_Plus4),
        .WS_IF_PC1_Plus4(WS_IF_PC1_Plus4),
        .Flush_IF(Flush_IF),
        .Flush_Warp(Flush_Warp),
        .IF_ID0_Instruction(IF_ID0_Instruction),
        .IF_ID1_Instruction(IF_ID1_Instruction),
        .IF_ID0_Active_Mask(IF_ID0_Active_Mask),
        .IF_ID1_Active_Mask(IF_ID1_Active_Mask),
        .IF_ID0_WarpID(IF_ID0_WarpID),
        .IF_ID1_WarpID(IF_ID1_WarpID),
        .IF_ID0_PC_Plus4(IF_ID0_PC_Plus4),
        .IF_ID1_PC_Plus4(IF_ID1_PC_Plus4)
    );

    Decode decode(
        .clk(clk),
        .rst_n(rst_n),
        .IF_ID0_Instruction(IF_ID0_Instruction),
        .IF_ID1_Instruction(IF_ID1_Instruction),
        .IF_ID0_Active_Mask(IF_ID0_Active_Mask),
        .IF_ID1_Active_Mask(IF_ID1_Active_Mask),
        .IF_ID0_WarpID(IF_ID0_WarpID),
        .IF_ID1_WarpID(IF_ID1_WarpID),
        .IF_ID0_PC_Plus4(IF_ID0_PC_Plus4),
        .IF_ID1_PC_Plus4(IF_ID1_PC_Plus4),
        .IB_Full(IB_Full), 
        .IB_Empty(IB_Empty),
        .Src1_ID0_IB(Src1_ID0_IB),
        .Src1_ID1_IB(Src1_ID1_IB),
        .Src2_ID0_IB(Src2_ID0_IB),
        .Src2_ID1_IB(Src2_ID1_IB),
        .Dst_ID0_IB(Dst_ID0_IB),
        .Dst_ID1_IB(Dst_ID1_IB),
        .Imme_ID0_IB(Imme_ID0_IB), 
        .Imme_ID1_IB(Imme_ID1_IB),
        .RegWrite_ID0_IB(RegWrite_ID0_IB),
        .RegWrite_ID1_IB(RegWrite_ID1_IB),
        .MemWrite_ID0_IB(MemWrite_ID0_IB),
        .MemWrite_ID1_IB(MemWrite_ID1_IB),
        .MemRead_ID0_IB(MemRead_ID0_IB),
        .MemRead_ID1_IB(MemRead_ID1_IB),
        .ALUop_ID0_IB(ALUop_ID0_IB),
        .ALUop_ID1_IB(ALUop_ID1_IB),
        .Share_Globalbar_ID0_IB(Share_Globalbar_ID0_IB),
        .Share_Globalbar_ID1_IB(Share_Globalbar_ID1_IB),
        .Imme_Valid_ID0_IB(Imme_Valid_ID0_IB),
        .Imme_Valid_ID1_IB(Imme_Valid_ID1_IB),
        .BEQ_ID0_IB(BEQ_ID0_IB),
        .BEQ_ID1_IB(BEQ_ID1_IB),
        .BLT_ID0_IB(BLT_ID0_IB),
        .BLT_ID1_IB(BLT_ID1_IB),
        .SIMT_Full(SIMT_Full),
        .SIMT_TwoMoreVacant(SIMT_TwoMoreVacant),
        .SIMT_Poped_PC_ID0(SIMT_Poped_PC_ID0),
        .SIMT_Poped_PC_ID1(SIMT_Poped_PC_ID1),
        .SIMT_Poped_Active_Mask_ID0(SIMT_Poped_Active_Mask_ID0),
        .SIMT_Poped_Active_Mask_ID1(SIMT_Poped_Active_Mask_ID1),
        .ID0_Active_Mask_SIMT_IB(ID0_Active_Mask_SIMT_IB),
        .ID1_Active_Mask_SIMT_IB(ID1_Active_Mask_SIMT_IB),
        .DotS_ID0_SIMT(DotS_ID0_SIMT),
        .DotS_ID1_SIMT(DotS_ID1_SIMT),
        .SIMT_Div_SyncBar_Token_ID0(SIMT_Div_SyncBar_Token_ID0),
        .SIMT_Div_SyncBar_Token_ID1(SIMT_Div_SyncBar_Token_ID1),
        .Call_ID0_SIMT(Call_ID0_SIMT),
        .Call_ID1_SIMT(Call_ID1_SIMT),
        .Ret_ID0_SIMT(Ret_ID0_SIMT),
        .Ret_ID1_SIMT(Ret_ID1_SIMT),
        .Branch_ID0_SIMT(Branch_ID0_SIMT),
        .Branch_ID1_SIMT(Branch_ID1_SIMT),
        .ID_Warp_Release_RAU(ID_Warp_Release_RAU),
        .ID0_PCplus4_SIMT_UpdatePC_WS(ID0_PCplus4_SIMT_UpdatePC_WS),
        .ID1_PCplus4_SIMT_UpdatePC_WS(ID1_PCplus4_SIMT_UpdatePC_WS),
        .ID0_Call_ReturnAddr_SIMT(ID0_Call_ReturnAddr_SIMT),
        .ID1_Call_ReturnAddr_SIMT(ID1_Call_ReturnAddr_SIMT),
        .ID0_Active_Mask_WS(ID0_Active_Mask_WS),
        .ID0_PC_Update_SIMT_WS(ID0_PC_Update_SIMT_WS),
        .ID0_Stall_PC_WS(ID0_Stall_PC_WS),
        .WarpID0_SIMT_IB(WarpID0_SIMT_IB),
        .WarpID0_WS(WarpID0_WS),
        .ID1_PC_Update_SIMT_WS(ID1_PC_Update_SIMT_WS),
        .ID1_Active_Mask_WS(ID1_Active_Mask_WS),
        .ID1_Stall_PC_WS(ID1_Stall_PC_WS),
        .WarpID1_SIMT_IB(WarpID1_SIMT_IB),
        .WarpID1_WS(WarpID1_WS)
    );

    I_Buffer_n_ScoreBoard IB_n_SB (
        .clk(clk),
        .rst_n(rst_n),
        .IB_Full(IB_Full), 
        .IB_Empty(IB_Empty),
        .Src1_ID0_IB(Src1_ID0_IB),
        .Src1_ID1_IB(Src1_ID1_IB),
        .Src2_ID0_IB(Src2_ID0_IB),
        .Src2_ID1_IB(Src2_ID1_IB),
        .Dst_ID0_IB(Dst_ID0_IB),
        .Dst_ID1_IB(Dst_ID1_IB),
        .Imme_ID0_IB(Imme_ID0_IB), 
        .Imme_ID1_IB(Imme_ID1_IB),
        .RegWrite_ID0_IB(RegWrite_ID0_IB),
        .RegWrite_ID1_IB(RegWrite_ID1_IB),
        .MemWrite_ID0_IB(MemWrite_ID0_IB),
        .MemWrite_ID1_IB(MemWrite_ID1_IB),
        .MemRead_ID0_IB(MemRead_ID0_IB),
        .MemRead_ID1_IB(MemRead_ID1_IB),
        .ALUop_ID0_IB(ALUop_ID0_IB),
        .ALUop_ID1_IB(ALUop_ID1_IB),
        .Share_Globalbar_ID0_IB(Share_Globalbar_ID0_IB),
        .Share_Globalbar_ID1_IB(Share_Globalbar_ID1_IB),
        .Imme_Valid_ID0_IB(Imme_Valid_ID0_IB),
        .Imme_Valid_ID1_IB(Imme_Valid_ID1_IB),
        .BEQ_ID0_IB(BEQ_ID0_IB),
        .BEQ_ID1_IB(BEQ_ID1_IB),
        .BLT_ID0_IB(BLT_ID0_IB),
        .BLT_ID1_IB(BLT_ID1_IB),
        .ID0_Active_Mask_SIMT_IB(ID0_Active_Mask_SIMT_IB),
        .ID1_Active_Mask_SIMT_IB(ID1_Active_Mask_SIMT_IB),
        .WarpID0_SIMT_IB(WarpID0_SIMT_IB),
        .WarpID1_SIMT_IB(WarpID1_SIMT_IB),
        .IB_Ready_Issue_IU(IB_Ready_Issue_IU),
        .IU_Grant(IU_Grant),
        .Src1_Out(Src1_Out), 
	    .Src2_Out(Src2_Out),
	    .Dst_Out(Dst_Out),
	    .Imme_Addr_Out(Imme_Addr_Out),
	    .RegWrite_Out(RegWrite_Out),
	    .MemWrite_Out(MemWrite_Out),
	    .MemRead_Out(MemRead_Out),
	    .ALU_Opcode_Out(ALU_Opcode_Out),
	    .Share_Globalbar_Out(Share_Globalbar_Out),
	    .Imme_Valid_Out(Imme_Valid_Out),
        .BEQ_Out(BEQ_Out),
        .BLT_Out(BLT_Out),
        .Active_Mask_Out(Active_Mask_Out),
        .SB_EntNum_OC(SB_EntNum_OC),
		.WB_Release_SB(WB_Release_SB),
        .WarpID_from_WB(WB_WarpID),
        .WB_Release_EntNum_SB(WB_Release_EntNum_SB)
    );

    SIMT simt(
        .clk(clk),
        .rst_n(rst_n),
        .WarpID_from_ALU(ALU_WarpID_to_SIMT),
        .SIMT_PCplus4_ALU(SIMT_PCplus4_ALU),
        .SIMT_Full(SIMT_Full),
        .SIMT_TwoMoreVacant(SIMT_TwoMoreVacant),
        .SIMT_Poped_PC_ID0(SIMT_Poped_PC_ID0),
        .SIMT_Poped_PC_ID1(SIMT_Poped_PC_ID1),
        .SIMT_Poped_Active_Mask_ID0(SIMT_Poped_Active_Mask_ID0),
        .SIMT_Poped_Active_Mask_ID1(SIMT_Poped_Active_Mask_ID1),
        .ID0_Active_Mask_SIMT_IB(ID0_Active_Mask_SIMT_IB),
        .ID1_Active_Mask_SIMT_IB(ID1_Active_Mask_SIMT_IB),
        .DotS_ID0_SIMT(DotS_ID0_SIMT),
        .DotS_ID1_SIMT(DotS_ID1_SIMT),
        .SIMT_Div_SyncBar_Token_ID0(SIMT_Div_SyncBar_Token_ID0),
        .SIMT_Div_SyncBar_Token_ID1(SIMT_Div_SyncBar_Token_ID1),
        .Call_ID0_SIMT(Call_ID0_SIMT),
        .Call_ID1_SIMT(Call_ID1_SIMT),
        .Ret_ID0_SIMT(Ret_ID0_SIMT),
        .Ret_ID1_SIMT(Ret_ID1_SIMT),
        .Branch_ID0_SIMT(Branch_ID0_SIMT),
        .Branch_ID1_SIMT(Branch_ID1_SIMT),
        .ID0_PCplus4_SIMT_UpdatePC_WS(ID0_PCplus4_SIMT_UpdatePC_WS),
        .ID1_PCplus4_SIMT_UpdatePC_WS(ID1_PCplus4_SIMT_UpdatePC_WS),
        .ID0_Call_ReturnAddr_SIMT(ID0_Call_ReturnAddr_SIMT),
        .ID1_Call_ReturnAddr_SIMT(ID1_Call_ReturnAddr_SIMT),
        .WarpID0_SIMT_IB(WarpID0_SIMT_IB),
        .WarpID1_SIMT_IB(WarpID1_SIMT_IB),
        .WarpID_from_WB(WB_WarpID),
        .WB_Update_SIMT(WB_Update_SIMT),
        .WB_AM_SIMT(WB_ActiveMask_SIMT)
    );

    Issue_Unit IU(
        .clk(clk),
        .rst_n(rst_n),
        .IB_Ready_Issue_IU(IB_Ready_Issue_IU),
        .OC_Full(OC_Full),//operand collector full signal
        .IU_Grant(IU_Grant)
    );

    RAU rau(
        .clk(clk),
        .rst_n(rst_n),
        .IU_Grant(IU_Grant),
        .IB_Src1_Out_RAU(Src1_Out),
	    .IB_Src2_Out_RAU(Src2_Out),
	    .IB_Dst_Out_RAU(Dst_Out),
        .RAU_EntryNum_RF(RAU_EntryNum_RF),//OC entry number
        .Src1_PhyRegAddr(Src1_PhyRegAddr),
        .Src2_PhyRegAddr(Src2_PhyRegAddr),
        .OC_EntryNum_RAU(OC_EntryNum_RAU),
        .Dst_PhyRegAddr(RAU_Dst_PhyRegAddr),
        .Src1_Reg8_16_Data(RAU_Src1_Reg8_16_Data),
        .Src2_Reg8_16_Data(RAU_Src2_Reg8_16_Data),
        .ID_Warp_Release_RAU(ID_Warp_Release_RAU), 
        .Num_Of_AviReg(Num_Of_AviReg),
        .WS_New_AllocReg_Num(New_AllocReg_Num),
        .New_Scheduled_HW_WarpID(New_Scheduled_HW_WarpID),
        .WS_WarpID_Even_RAU(WS_WarpID_Even_RAU),
        .WS_WarpID_Odd_RAU(WS_WarpID_Odd_RAU),
        .RAU_Release_Warp_WS(RAU_Release_Warp_WS)
    );

    Operand_Collector OC(
        .clk(clk),
        .rst_n(rst_n),
        .IB_Src1_Out(Src1_Out), 
        .IB_Src2_Out(Src2_Out),
        .IB_Imme_Addr_OC(Imme_Addr_Out),
        .IB_RegWrite_OC(RegWrite_Out),
        .IB_MemWrite_OC(MemWrite_Out),
        .IB_MemRead_OC(MemRead_Out),
        .IB_ALU_Opcode_OC(ALU_Opcode_Out),
        .IB_Share_Globalbar_OC(Share_Globalbar_Out),
        .IB_Imme_Valid_OC(Imme_Valid_Out),
        .IB_BEQ_OC(BEQ_Out),
        .IB_BLT_OC(BLT_Out),
        .IB_Active_Mask_OC(Active_Mask_Out),
        .SB_Release_EntNum_OC(SB_EntNum_OC),
        .IU_Grant(IU_Grant),
        .OC_Full(OC_Full),
        .OC_IssReq_EX_IU(OC_IssReq_EX_IU),
        .EX_IU_Grant(EX_IU_Grant),
        .OC_EntryNum_RAU(OC_EntryNum_RAU),
        .RAU_Dst_PhyRegAddr(RAU_Dst_PhyRegAddr),
        .RAU_Src1_Reg8_16_Data(RAU_Src1_Reg8_16_Data),
        .RAU_Src2_Reg8_16_Data(RAU_Src2_Reg8_16_Data),
        .RF_Out_Bank0(RF_Out_Bank0),
        .RF_Out_Bank1(RF_Out_Bank1),
        .RF_Out_Bank2(RF_Out_Bank2),
        .RF_Out_Bank3(RF_Out_Bank3),
        .RF_Bank0_EntryNum_OC(RF_Bank0_EntryNum_OC),
        .RF_Bank1_EntryNum_OC(RF_Bank1_EntryNum_OC),
        .RF_Bank2_EntryNum_OC(RF_Bank2_EntryNum_OC),
        .RF_Bank3_EntryNum_OC(RF_Bank3_EntryNum_OC),
        .RF_Dout_Valid(RF_Dout_Valid),
        .RF_SrcNum_OC(RF_SrcNum_OC),
        .OC_WarpID_ALU(OC_WarpID_ALU),
        .OC_Imme_Addr_ALU(OC_Imme_Addr_ALU),
        .OC_RegWrite_ALU(OC_RegWrite_ALU),
        .OC_MemWrite_ALU(OC_MemWrite_ALU),
        .OC_MemRead_ALU(OC_MemRead_ALU),
        .OC_ALU_Opcode_ALU(OC_ALU_Opcode_ALU),
        .OC_Share_Globalbar_ALU(OC_Share_Globalbar_ALU),
        .OC_Imme_Valid_ALU(OC_Imme_Valid_ALU),
        .OC_BEQ_ALU(OC_BEQ_ALU),
        .OC_BLT_ALU(OC_BLT_ALU),
        .OC_Dst_PhyRegAddr_ALU(OC_Dst_PhyRegAddr_ALU),
        .OC_Src1_Date_ALU(OC_Src1_Date_ALU),
        .OC_Src2_Date_ALU(OC_Src2_Date_ALU),
        .OC_Active_Mask_ALU(OC_Active_Mask_ALU),
        .OC_SB_Release_EntNum_ALU(OC_SB_Release_EntNum_ALU),
        .OC_LwSw_Addr_Ready(OC_LwSw_Addr_Ready),
        .ALU_Result(ALU_Result),
        .LdSt_Replay(LdSt_Replay),
        .LdSt_Busy(LdSt_Busy),
        .Replay_Active_Mask(Replay_Active_Mask)
    );

    Banked_Register_File RF(
        .clk(clk),
        .rst_n(rst_n),
        .RAU_EntryNum_RF(RAU_EntryNum_RF),
        .Src1_PhyRegAddr(Src1_PhyRegAddr),
        .Src2_PhyRegAddr(Src2_PhyRegAddr),
        .RF_Out_Bank0(RF_Out_Bank0),
        .RF_Out_Bank1(RF_Out_Bank1),
        .RF_Out_Bank2(RF_Out_Bank2),
        .RF_Out_Bank3(RF_Out_Bank3),
        .RF_Bank0_EntryNum_OC(RF_Bank0_EntryNum_OC),
        .RF_Bank1_EntryNum_OC(RF_Bank1_EntryNum_OC),
        .RF_Bank2_EntryNum_OC(RF_Bank2_EntryNum_OC),
        .RF_Bank3_EntryNum_OC(RF_Bank3_EntryNum_OC),
        .RF_Dout_Valid(RF_Dout_Valid),//indicate if the data out of each register file is valid
        .RF_SrcNum_OC(RF_SrcNum_OC), //0 means src1, 1 means src2, used to determine the entry of OC to be written into
        .WB_Regwrite(WB_Regwrite),
        .WB_Active_Mask(WB_ActiveMask_WS_RF),
        .WriteBack_PhyRegAddr(WriteBack_PhyRegAddr),
        .WriteBack_Data(WriteBack_Data)
    );

    EX_Issue_Unit EX_IU(
        .clk(clk),
        .rst_n(rst_n),
        .OC_IssReq_EX_IU(OC_IssReq_EX_IU),
        .EX_IU_Grant(EX_IU_Grant),
        .MSHR_Done(MSHR_Done)
    );

    ALU_n_LdSt_WB alu_n_ld_st_n_wb(
        .clk(clk),
        .rst_n(rst_n),
        .Uart_clk(Uart_clk),
        .DC_Init(DC_Init),
        .Init_Done(Init_Done),
        .DC_WriteBack(Write_Back),
        .DC_Init_n_WriteBack_Addr(DC_Init_n_WriteBack_Addr),
        .DC_Init_Data(DC_Init_Data),
        .DC_WriteBack_Data(DC_WriteBack_Data),
        .OC_WarpID_ALU(OC_WarpID_ALU),
        .OC_Imme_Addr_ALU(OC_Imme_Addr_ALU),
        .OC_RegWrite_ALU(OC_RegWrite_ALU),
        .OC_MemWrite_ALU(OC_MemWrite_ALU),
        .OC_MemRead_ALU(OC_MemRead_ALU),
        .OC_ALU_Opcode_ALU(OC_ALU_Opcode_ALU),
        .OC_Share_Globalbar_ALU(OC_Share_Globalbar_ALU),
        .OC_Imme_Valid_ALU(OC_Imme_Valid_ALU),
        .OC_BEQ_ALU(OC_BEQ_ALU),
        .OC_BLT_ALU(OC_BLT_ALU),
        .OC_Dst_PhyRegAddr_ALU(OC_Dst_PhyRegAddr_ALU),
        .OC_Src1_Date_ALU(OC_Src1_Date_ALU),
        .OC_Src2_Date_ALU(OC_Src2_Date_ALU),
        .OC_Active_Mask_ALU(OC_Active_Mask_ALU),
        .ALU_Result(ALU_Result),
        .OC_SB_Release_EntNum_ALU(OC_SB_Release_EntNum_ALU),
        .OC_LwSw_Addr_Ready(OC_LwSw_Addr_Ready),
        .LdSt_Replay(LdSt_Replay),
        .MSHR_Busy(LdSt_Busy),
        .Replay_Active_Mask(Replay_Active_Mask),
        .ALU_WarpID_to_SIMT(ALU_WarpID_to_SIMT),
        .SIMT_PCplus4_ALU(SIMT_PCplus4_ALU),
        .WB_WarpID(WB_WarpID),
        .WB_Update_SIMT(WB_Update_SIMT),
        .WB_ActiveMask_SIMT(WB_ActiveMask_SIMT),
        .WB_Release_SB(WB_Release_SB),
        .WB_Release_EntNum_SB(WB_Release_EntNum_SB),
        .WB_PC_Update_WS(WB_PC_Update_WS),
        .WB_PC_Update_Addr_WS(WB_PC_Update_Addr_WS),
        .WB_ActiveMask_WS_RF(WB_ActiveMask_WS_RF),
        .WB_Regwrite(WB_Regwrite),
        .WriteBack_PhyRegAddr(WriteBack_PhyRegAddr),
        .WriteBack_Data(WriteBack_Data),
        .EX_IU_Grant(EX_IU_Grant),
        .MSHR_Done(MSHR_Done)
    );

    //uart
    uart_gpgpu uart(
        .clk_sys(Uart_clk),      // Clock input (from pin)
        .rst_clk(rst_uart),        // Active HIGH reset (from pin)
        // RS232 signals
        .rxd_i(rxd_i),        // RS232 RXD pin
        .txd_o(txd_o),        // RS232 RXD pin
        .LED0(LED0_toBuf),
        .LED1(LED1_toBuf),
        .LED2(LED2_toBuf),
        .LED3(LED3_toBuf),
        .LED5(LED5_toBuf),
        .Task_Init(Task_Init),//task mem
        .IC_Init(IC_Init),//ic
        .DC_Init(DC_Init),
        .Bram_WrAddr(Bram_WrAddr),//share mem address line
        .Bram_RdAddr1(Bram_RdAddr1),
        .Bram_RdAddr2(Bram_RdAddr2),
        .Bram_RdAddr3(Bram_RdAddr3),//only readout data in dc
        .Data_OneRow(Data_OneRow),//data for initializing mem
        .Bram_Dout1(Bram_Dout1),
        .Bram_Dout2(Bram_Dout2),
        .Bram_Dout3(Bram_Dout3),//write back dat
        // // button L
        .BTNL(BTNL), //used for debug,
        .btnl_scen(btnl_scen)
    );
    reg [14:0] Cnt_5000;
    reg [2:0] Cnt_4;
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            LED4_toBuf<=1'b0;
            Cnt_5000<='b0;
            Cnt_4<='b0;
            Write_Back<=1'b0;
            Init_Done<=1'b0;//the GPGPU can start running up
        end else begin
            if(LED3_toBuf&&!Cnt_4[2])begin
                Cnt_4<=Cnt_4+1;
            end else if(Cnt_4[2])begin
                Init_Done<=1'b1;  
            end
            //
            if(Init_Done&&!Cnt_5000[13])begin
                Cnt_5000<=Cnt_5000+1;
            end else if(Cnt_5000[13])begin
                LED4_toBuf<=1'b1;//indicate it is time to send data back
                Write_Back<=1'b1;
            end
        end
    end
    //////////
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            LED7_toBuf<=1'b0;
        end else begin
            if(WB_Regwrite)begin
                LED7_toBuf<=1'b1;
            end
        end
    end
endmodule