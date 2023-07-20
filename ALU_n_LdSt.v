`timescale 1ns/100ps
module ALU_n_LdSt_WB(
    input clk,
    input rst_n,
    input Uart_clk,
    input DC_Init,
    input Init_Done,
    input DC_WriteBack,
    input [8:0] DC_Init_n_WriteBack_Addr,
    input [255:0] DC_Init_Data,
    output [255:0] DC_WriteBack_Data,
    //interface with OC
    input [2:0] OC_WarpID_ALU,//it is generated  by encoding input IU_Grant
    input [15:0] OC_Imme_Addr_ALU,
	input OC_RegWrite_ALU,
	input OC_MemWrite_ALU,
	input OC_MemRead_ALU,
	input [3:0] OC_ALU_Opcode_ALU,
	input OC_Share_Globalbar_ALU,
	input OC_Imme_Valid_ALU,
    input OC_BEQ_ALU,
    input OC_BLT_ALU,
    input [4:0] OC_Dst_PhyRegAddr_ALU,
    input [255:0] OC_Src1_Date_ALU,
    input [255:0] OC_Src2_Date_ALU,
    input [7:0] OC_Active_Mask_ALU,
    input [1:0] OC_SB_Release_EntNum_ALU,
    input OC_LwSw_Addr_Ready,
    output LdSt_Replay,//the replay signal sent from LD_ST Unit
    output reg [7:0] MSHR_Busy,////used to indicate the mshr of which warp is busy now
    output reg [7:0] Replay_Active_Mask,
    output reg [255:0] ALU_Result,
    //interface with SIMT
    output [2:0] ALU_WarpID_to_SIMT,//warp id sent to SIMT to fetch pc+4 for branch instructions
    input [31:0] SIMT_PCplus4_ALU,//pc+4 used by branch instructions
    //////////////////////////
    output reg [2:0] WB_WarpID,
    output reg WB_Update_SIMT,//the update signal for SIMT is a little different from the one for WS
    output reg [7:0] WB_ActiveMask_SIMT,
    //interface with SB
    output reg WB_Release_SB,
    output reg [1:0] WB_Release_EntNum_SB,
    //interfacec with WS 
    output reg WB_PC_Update_WS,
    output [31:0] WB_PC_Update_Addr_WS,
    output reg [7:0] WB_ActiveMask_WS_RF,//the branch taken active mask or active mask for register update
    //interface with RF
    output reg WB_Regwrite,
    output reg [4:0] WriteBack_PhyRegAddr,
    output [255:0] WriteBack_Data,//select between the alu result and mem out data
    //interface with EX_Issue_Unit
    input [3:0] EX_IU_Grant,
    output reg MSHR_Done//indicate a mshr request has been done by data cache, the next mshr request can be processing
);
    //signals for uart
    wire Ram_clk;
    //global mux
    BUFGMUX BUFGMUX_DC (
    .O(Ram_clk),   // 1-bit output: Clock output
    .I0(clk), // 1-bit input: Clock input (S=0)
    .I1(Uart_clk), // 1-bit input: Clock input (S=1)
    .S(!Init_Done||DC_WriteBack)    // 1-bit input: Clock select
    );
    ///////////////////////////////////////
    integer i;
    reg [7:0] ALU_Branch_Taken_AM;//the active mask for threads of which branch is taken, used for WS when divergence occurs
    wire [7:0] ALU_Branch_Untaken_AM=OC_Active_Mask_ALU^ALU_Branch_Taken_AM;//used for SIMT is divergence is happened
    always@(*)begin:ALU_Block
        //the effective address of lw and sw is also computed in ALU
        ALU_Result='b0;
        ALU_Branch_Taken_AM=OC_Active_Mask_ALU;
        if(|EX_IU_Grant)begin//means a valid instruction is issued to ALU
            for(i=0;i<8;i=i+1)begin//for each thread
                if(OC_RegWrite_ALU&&!OC_MemRead_ALU)begin//r_type + I_Type
                    case(OC_ALU_Opcode_ALU) 
                        4'b0000:begin
                            if(OC_Imme_Valid_ALU)begin//addi                               
                                ALU_Result[32*i +: 32]=OC_Src1_Date_ALU[32*i +: 32]+{{16{OC_Imme_Addr_ALU[15]}},OC_Imme_Addr_ALU};                             
                            end else begin//add                    
                                ALU_Result[32*i +: 32]=OC_Src1_Date_ALU[32*i +: 32]+OC_Src2_Date_ALU[32*i +: 32];                         
                            end
                        end
                        4'b0001:ALU_Result[32*i +: 32]=OC_Src1_Date_ALU[32*i +: 32]-OC_Src2_Date_ALU[32*i +: 32];//sub                                                       
                        4'b0010:ALU_Result[32*i +: 32]=OC_Src1_Date_ALU[32*i +: 16]*OC_Src2_Date_ALU[32*i +: 16];//mul NOTE: the multiplication is signed 16 bit multiplication                                   
                        4'b0011:begin
                            if(OC_Imme_Valid_ALU)begin//andi
                                ALU_Result[32*i +: 32]=OC_Src1_Date_ALU[32*i +: 32]&{{16{OC_Imme_Addr_ALU[15]}},OC_Imme_Addr_ALU};
                            end else begin//and
                                ALU_Result[32*i +: 32]=OC_Src1_Date_ALU[32*i +: 32]&OC_Src2_Date_ALU[32*i +: 32];
                            end
                        end
                        4'b0100:begin
                            if(OC_Imme_Valid_ALU)begin//ori
                                ALU_Result[32*i +: 32]=OC_Src1_Date_ALU[32*i +: 32]|{{16{OC_Imme_Addr_ALU[15]}},OC_Imme_Addr_ALU};
                            end else begin//or
                                ALU_Result[32*i +: 32]=OC_Src1_Date_ALU[32*i +: 32]|OC_Src2_Date_ALU[32*i +: 32];
                            end
                        end
                        4'b0101:begin
                            if(OC_Imme_Valid_ALU)begin//xori
                                ALU_Result[32*i +: 32]=OC_Src1_Date_ALU[32*i +: 32]^{{16{OC_Imme_Addr_ALU[15]}},OC_Imme_Addr_ALU};
                            end else begin//xor
                                ALU_Result[32*i +: 32]=OC_Src1_Date_ALU[32*i +: 32]^OC_Src2_Date_ALU[32*i +: 32];
                            end
                        end
                        4'b0110:begin//shr
                        //for shift operation, the least significant five bits is the number of shifting bits
                            ALU_Result[32*i +: 32]=OC_Src1_Date_ALU[32*i +: 32]>>OC_Src2_Date_ALU[32*i +: 5];
                        end
                        4'b0111:ALU_Result[32*i +: 32]=OC_Src1_Date_ALU[32*i +: 32]<<OC_Src2_Date_ALU[32*i +: 5];//shl
                    endcase
                end else if((OC_MemRead_ALU||OC_MemWrite_ALU)&&!OC_LwSw_Addr_Ready)begin//lw/sw, only calculate the address when the ready bit is 0
                    ALU_Result[32*i +: 32]=OC_Src1_Date_ALU[32*i +: 32]+{{16{OC_Imme_Addr_ALU[15]}},OC_Imme_Addr_ALU};
                end else begin
                    if(OC_BEQ_ALU)begin
                        //in gpu program, we always use entry guarded branch, so the offset is always positive
                        ALU_Result[32*i +: 32]=SIMT_PCplus4_ALU+{{14{OC_Imme_Addr_ALU[15]}},OC_Imme_Addr_ALU,2'b00};//branch target address
                        if(OC_Active_Mask_ALU[i])begin
                            ALU_Branch_Taken_AM[i]=OC_Src1_Date_ALU[32*i +: 32]==OC_Src2_Date_ALU[32*i +: 32];
                        end
                    end
                    //
                    if(OC_BLT_ALU)begin//signed 16bit comparision
                        ALU_Result[32*i +: 32]=SIMT_PCplus4_ALU+{{14{OC_Imme_Addr_ALU[15]}},OC_Imme_Addr_ALU,2'b00};//branch target address
                        if(OC_Active_Mask_ALU[i])begin
                            ALU_Branch_Taken_AM[i]=OC_Src1_Date_ALU[32*i +: 16]<OC_Src2_Date_ALU[32*i +: 16];
                        end
                    end
                end
            end     
        end      
    end
    //************************************************************************************************************************************
    //below logic is for data cache and LD/ST unit
    /////////////////////////////////////////
    //always block for LD/ST unit to generate replay signal and replay active mask
    //and determine current cache line for accessing global memory
    reg [26:0]Access_DCache_LineAddr;//based on current active threa and their memory access, determine the access cache line address
    wire [7:0] Access_DCache_AM=OC_Active_Mask_ALU^Replay_Active_Mask;//the active threads to access data cache
    assign LdSt_Replay=|Replay_Active_Mask;
    always@(*)begin:LD_ST_Unit
        Replay_Active_Mask=8'b0000_0000;
        casez(OC_Active_Mask_ALU)
        //decide which cache line we want to access during current clock
            8'bzzzz_zz10:Access_DCache_LineAddr=OC_Src1_Date_ALU[63 -: 27];
            8'bzzzz_z100:Access_DCache_LineAddr=OC_Src1_Date_ALU[95 -: 27];
            8'bzzzz_1000:Access_DCache_LineAddr=OC_Src1_Date_ALU[127 -: 27];
            8'bzzz1_0000:Access_DCache_LineAddr=OC_Src1_Date_ALU[159 -: 27];
            8'bzz10_0000:Access_DCache_LineAddr=OC_Src1_Date_ALU[191 -: 27];
            8'bz100_0000:Access_DCache_LineAddr=OC_Src1_Date_ALU[223 -: 27];
            8'b1000_0000:Access_DCache_LineAddr=OC_Src1_Date_ALU[255 -: 27];
            default:Access_DCache_LineAddr=OC_Src1_Date_ALU[31 -: 27];
        endcase
        if((OC_MemRead_ALU||OC_MemWrite_ALU)&&OC_LwSw_Addr_Ready)begin
            for(i=1;i<9;i=i+1)begin
                if(OC_Active_Mask_ALU[i-1])begin//based on current active threads
                    if(OC_Src1_Date_ALU[32*i-1 -: 27]!=Access_DCache_LineAddr)begin
                       Replay_Active_Mask[i-1]=1'b1; 
                    end
                end
            end
        end
    end
    ////////////////////////////////////////
    //the data cache accessing is a global memory access operation
    reg [2:0] Cache_Latency_Emulator [31:0];//used to analog the cache access latency , the maximum latency is 8 clock
    wire DataCache_Miss=(|EX_IU_Grant)&&(OC_MemRead_ALU||OC_MemWrite_ALU)&&OC_LwSw_Addr_Ready&&!OC_Share_Globalbar_ALU&&Cache_Latency_Emulator[Access_DCache_LineAddr[4:0]]!=0;
    wire DataCache_Hit=(|EX_IU_Grant)&&(OC_MemRead_ALU||OC_MemWrite_ALU)&&OC_LwSw_Addr_Ready&&!OC_Share_Globalbar_ALU&&Cache_Latency_Emulator[Access_DCache_LineAddr[4:0]]==0;
    //memory initialization
    initial begin
        for(i=0;i<32;i=i+1)begin
            Cache_Latency_Emulator[i]=i;
        end
    end
    ///////////////////////////////////////
    //data cache// signal port output regsitered bram
    //for achieving the control of the active mask, we divide 256x128 into 32x8x128
    ///////////////////////////////////
    //NOTE:
    wire [23:0] Access_Word_Addr;//combinational signal
    reg [23:0] Access_Word_Addr_WB;//used as part of wb stage register
    //used to store the word address of each active threads, so that we can use it to reorder the readout data
    //the reorder process is done at wb stage
    //
    wire [255:0] DataCache_Dout_WB;//output data of data cache, the output register of data cache bram is used as part of wb stage register
    wire [255:0] DC_Dout_After_Reorder_WB;//this reorder process is done in WB stage
    //NOTE: the data out from Data cache should be reorder to match the order shown by Active_Mask_to_MSHR
    //Since thread 1 might be accessing the second word of the cache line, and thread 2 is accessing the first word,
    //so after data is read out from the data cache, we should reorder the data ,put the second word at the first place
    //
    reg [255:0] DC_Din_After_Reorder;//the data in of data cache should also  be reordered, this is done in ALU, not wb stage
    reg [7:0] DC_WE_for_Word;
    always@(*)begin
        if(!Init_Done)begin
            DC_Din_After_Reorder=DC_Init_Data;
            DC_WE_for_Word='b0;
        end else begin
            DC_Din_After_Reorder='b0;
            DC_WE_for_Word='b0;
            for(i=0;i<8;i=i+1)begin
                if(Access_DCache_AM[i])begin
                    DC_Din_After_Reorder[32*Access_Word_Addr[3*i +: 3] +: 32]=OC_Src2_Date_ALU[32*i +: 32];
                    DC_WE_for_Word[Access_Word_Addr[3*i +: 3]]=1'b1;
                end
                //NOTE: for write and read operation, the i stands for word id in a cache line
            end
        end
        //
        
    end
    //
    wire Valid_to_MSHR=|EX_IU_Grant&&DataCache_Miss;//indicate there is a task for mshr
    //singals for simulating the time of data cache delaing with a cache miss
    reg Latency_Cnt_Start;//indicate the latency counter is working
    reg [2:0] Latency_Counter;//used to simulate the time for mshr to deal with the cache miss
    //data cache
    /////////////////////////////////
    //NOTE: if current mshr done is 1, then we send the access address of fifo out to the data cache, if done is 0, then the control signal will indicate 
    //if the output of data cache is valid
    wire [26:0] DC_Access_Address=(!Init_Done||DC_WriteBack)?{18'd0,DC_Init_n_WriteBack_Addr}:(MSHR_Done?MSHR_FIFO_Dout[67:41]:Access_DCache_LineAddr);
    //always for mshr busy update and latency counter operation
    wire [255:0] DC_ReadOut_Data;
    genvar j;
    generate
        //NOTE:
        //only the thread with a active mask can write it data into corresponding word of this cache line
        //the active mask controlled cannot be omitted here, becasue, the thread for writing different cache line may have the same word address
        //if we let each thread write their data into the word location of this cache line, the correct word might be covered by a wrong one
        for(j=0;j<8;j=j+1)begin:DC_Inst
            assign Access_Word_Addr[3*j +: 3]=OC_Src1_Date_ALU[32*j+2 +: 3];//if there is no cache miss, sent to WB stage directly. if there is a cache miss, store it into mshr fifo
            assign DC_Dout_After_Reorder_WB[32*j +: 32]=DataCache_Dout_WB[32*Access_Word_Addr_WB[3*j +: 3] +: 32];
            assign DataCache_Dout_WB[32*j +: 32]=DC_ReadOut_Data[32*j +: 32];
            assign DC_WriteBack_Data[32*j +: 32]=DC_ReadOut_Data[32*j +: 32];
            //NOTE: for writing reorder, the write data of current thread is written into DC_Din_After_Reorder according to its word address
            //but for reading reorder, we use the word address of current thread to access the readout data, then put it into DC_Dout_After_Reorder_WB according to its thread id
            //for reading the same word address of different thread is fine since the same word is written into different location of DC_Dout_After_Reorder_WB
            //but for writing, we have to take care of the same word address
            Single_Port_BRAM  #(.ADDR_WIDTH(9), .DATA_WIDTH(32), .NO_WORD(j), .MEM_TYPE("DC")) Data_Cache
            (
                .clk(Ram_clk),
                //NOTE: only global sw can write data into data cache
                .we(!DC_WriteBack&&(DC_Init||OC_MemWrite_ALU&&OC_LwSw_Addr_Ready&&!OC_Share_Globalbar_ALU&&(|EX_IU_Grant)&&DC_WE_for_Word[j])),
                .addr(DC_Access_Address[8:0]),
                .din(DC_Din_After_Reorder[32*j +: 32]),
                .dout(DC_ReadOut_Data[32*j +: 32])
            );
            //data cache depth only 128, width 32x8
        end
    endgenerate
    
    ////////////////////////////////
    wire MSHR_Empty;//used to indicate the emulator to initialize the latency value and start counting
    wire [73:0] MSHR_FIFO_Dout;  
    //1bit lw/swbar, 27bit cache line address, 24 bit word access address, 3bit warp ID, 3bit latency, 8bit active mask, 1bit release sb valid, 2bit sb release entry number
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            MSHR_Busy<='b0;
            Latency_Counter<='bx;
            MSHR_Done<=1'b0;
            Latency_Cnt_Start<=1'b0;
        end else begin
            MSHR_Done<=1'b0;//default assignment
            //activation of mshr busy signal
            if(Valid_to_MSHR)begin
                MSHR_Busy[OC_WarpID_ALU]<=!MSHR_Busy[OC_WarpID_ALU];
            end
            //active the latency counter
            if(!MSHR_Empty&&!Latency_Cnt_Start)begin
                Latency_Counter<=MSHR_FIFO_Dout[13:11]-1;
                Latency_Cnt_Start<=!Latency_Cnt_Start;
            end else if(Latency_Cnt_Start&&Latency_Counter!=0)begin
                Latency_Counter<=Latency_Counter-1;
            end else if(!MSHR_Done&&Latency_Cnt_Start&&Latency_Counter==0)begin
                //NOTE:when mshr done is 1, since the isntruction in FIFO neeeds one clock to enter into WB, so we want to activate
                //the ren enable of fifo during this clock, so we hope the start signal can be reset at the next cock, so that the latency counter
                //can read a new latency from the next location of fifo
                //however, to achieve this, the next cycle, start is still 1 and cnt is0, then this branch will executed again, so that the done signal is 
                //activate for two clcok not one, so we add the !mshr_done signal to fix this bug
                MSHR_Busy[MSHR_FIFO_Dout[16:14]]<=! MSHR_Busy[MSHR_FIFO_Dout[16:14]];
                if(MSHR_FIFO_Dout[73]||(!MSHR_FIFO_Dout[73]&&MSHR_FIFO_Dout[2]))begin//lw or sw and sb release valid is 1
                    MSHR_Done<=1'b1;
                    //NOTE: if the sw instruction has to be replayed one more time, then we don't need to activate the mshr_done signal
                    //since the sw cannot release the sb entry yet, if replay is zero, means once the cache miss is solved, it can go to wb stage and release the sb entry
                end else begin
                    Latency_Cnt_Start<=!Latency_Cnt_Start;
                end
            end
            ////////////
            //since if the start is zero, the latency number stored in the fifo output entry is going to be written into latency counter
            //however, the fifo's rd pointer should update only when mshr done is 1, then the data stored in the fifo is sent to wb stage,
            //so in this case, the start signal should be set to 0 when mshr done is 1.
            //however, if the output entry of the fifo is a sw and sb release valid is 0, the mshr done is not activated, but the rd pointer should also be updated
            if(MSHR_Done)begin
                Latency_Cnt_Start<=!Latency_Cnt_Start;
            end
        end
    end
    //1bit lw/swbar, 5 bit dst_phyreg addr, 27bit cache line address, 24 bit word access address, 3bit warp ID, 3bit latency, 8bit active mask, 1bit release sb valid, 2bit sb release entry number
    //used to store cache missing request, at most eight from each warp, so the fifo will never be overfull
    //eight requests have to be processed in order of their arrival time
    MSHR_FIFO mshr_fifo(
        .clk(clk),
        .rst_n(rst_n),
        .wen(Valid_to_MSHR),//if the valid bit is 1, it means cache miss occurs, mshr start to deal with cache miss, in this case we activate the latency counter to count
        .ren(MSHR_Done||Latency_Cnt_Start&&Latency_Counter==0&&!MSHR_FIFO_Dout[73]&&!MSHR_FIFO_Dout[2]),
        .din({OC_MemRead_ALU, OC_Dst_PhyRegAddr_ALU, Access_DCache_LineAddr, Access_Word_Addr, OC_WarpID_ALU, Cache_Latency_Emulator[ALU_Result[9:5]], Access_DCache_AM, !LdSt_Replay, OC_SB_Release_EntNum_ALU}),
        .dout(MSHR_FIFO_Dout),
        .Full(),//not used in this situation
        .Empty(MSHR_Empty) 
    );
    //WB stage register
    reg [255:0] Alu_Result_WB;
    reg WB_MemRead;
    assign ALU_WarpID_to_SIMT=OC_WarpID_ALU;
    assign WB_PC_Update_Addr_WS=Alu_Result_WB [31:0];
    ////////////////////
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            WB_Regwrite<=1'b0;
            WB_MemRead<='bx;
            WB_Release_SB<=1'b0;
            WB_Update_SIMT<=1'b0;
            WB_PC_Update_WS<=1'b0;
            Alu_Result_WB<='bx;
            WB_WarpID<='bx;
            WB_ActiveMask_SIMT<='bx;
            WB_Release_EntNum_SB<='bx;
            WB_ActiveMask_WS_RF<='bx;
            WriteBack_PhyRegAddr<='bx;
            Access_Word_Addr_WB<='bx;
        end else begin
            if(!(|EX_IU_Grant)&&!MSHR_Done)begin//no valid instruction is sent to ALU
                WB_Regwrite<=1'b0;
                WB_Release_SB<=1'b0;
                WB_Update_SIMT<=1'b0;
                WB_PC_Update_WS<=1'b0;
            end else if(!(|EX_IU_Grant)&&MSHR_Done)begin//a cache miss is solved by mshr
                WB_Regwrite<=1'b0;
                WB_MemRead<=MSHR_FIFO_Dout[73];
                WB_Release_SB<=1'b0;
                WB_Update_SIMT<=1'b0;
                WB_PC_Update_WS<=1'b0;
                Access_Word_Addr_WB<=MSHR_FIFO_Dout[40:17];
                //default assignment
                if(MSHR_FIFO_Dout[73])begin//lw
                    WB_Regwrite<=1'b1;
                    WB_MemRead<=1'b1;
                end
                WB_Release_SB<=MSHR_FIFO_Dout[2];
                WB_WarpID<=MSHR_FIFO_Dout[16:14];
                WB_Release_EntNum_SB<=MSHR_FIFO_Dout[1:0];
                WB_ActiveMask_WS_RF<=MSHR_FIFO_Dout[10:3];
                WriteBack_PhyRegAddr<=MSHR_FIFO_Dout[72:68];
            end else if(|EX_IU_Grant)begin
                WB_Regwrite<=1'b0;
                WB_MemRead<=1'b0;
                WB_Release_SB<=1'b1;
                WB_Update_SIMT<=1'b0;
                WB_PC_Update_WS<=1'b0;
                Alu_Result_WB<=ALU_Result;
                Access_Word_Addr_WB<=Access_Word_Addr;
                //NOTE: for branch taken address calculation, even if the mask for a thread is 0, but the thread also comopute the address as others,
                //so alu_reslut is always valid
                WB_WarpID<=OC_WarpID_ALU;
                WB_Release_EntNum_SB<=OC_SB_Release_EntNum_ALU;
                WB_ActiveMask_WS_RF<=OC_Active_Mask_ALU;
                WriteBack_PhyRegAddr<=OC_Dst_PhyRegAddr_ALU;
                WB_ActiveMask_SIMT<=ALU_Branch_Untaken_AM;
                //if no divergence occurs, the active mask for ws is the same as alu input active mask
                //if divergence occurs, the active mask for ws is the takn branch mask
                //default assignment
                //if instruction is not a lw or sw 
                if(!OC_MemRead_ALU&&!OC_MemWrite_ALU)begin
                    WB_Regwrite<=OC_RegWrite_ALU;//then we transmit the regwrite signal in alu to wb
                end
                //branch instruction
                if(OC_BEQ_ALU||OC_BLT_ALU)begin
                     WB_PC_Update_WS<=1'b1;//free the locked pc 
                     WB_Update_SIMT<=1'b1;
                     //NOTE:once the branch instruction comes out to wb stage, simt update signal should be 1
                     //the SIMT it self will record if the branch is a dot.s or not
                     //when branch arrives at wb, if no divergence occurs, it will not push div token into SIMT
                     //but if it is a normal branch, it should release the entry which is occupied to store its  pc+4 
                     if(ALU_Branch_Untaken_AM==OC_Active_Mask_ALU)begin//threads all untaken
                        //if divergence  occurs,
                        //the pc update address for ws rbanch target address, which is stored in ALU result
                        //if divergence not occurs, but threads are all taken, the pc update address of ws is also branch target address
                        //otherwise the pc update address for ws is pc+4   
                        Alu_Result_WB<={8{SIMT_PCplus4_ALU}};
                     end
                     if(ALU_Branch_Taken_AM!=OC_Active_Mask_ALU&&ALU_Branch_Untaken_AM!=OC_Active_Mask_ALU)begin
                        //divergence occurs
                        WB_ActiveMask_WS_RF<=ALU_Branch_Taken_AM;
                     end else begin//no divergence
                        WB_ActiveMask_SIMT<=8'b0000_0000;
                     end
                end
                //lw or sw
                if((OC_MemRead_ALU||OC_MemWrite_ALU)&&OC_LwSw_Addr_Ready)begin
                    if(LdSt_Replay||!LdSt_Replay&&DataCache_Miss)begin
                        //if replay is 1, sb release valid should be zero
                        WB_Release_SB<=1'b0;
                    end
                    if(DataCache_Hit)begin//lw/sw can be transmit to the wb stage directly
                        WB_MemRead<=OC_MemRead_ALU;
                        WB_Regwrite<=OC_RegWrite_ALU;
                        //if lw is cache hit, the active mask for updating rf should be the threads which can access the current decided cache line
                        WB_ActiveMask_WS_RF<=Access_DCache_AM;  
                    end
                end else if((OC_MemRead_ALU||OC_MemWrite_ALU)&&!OC_LwSw_Addr_Ready)begin
                    //NOTE: when the lw/sw first arrives at ALU, the SB release signal should also  be 0, since we set the sb_release signal to 1 by default
                    //so in this case, we have to emphasize it specifically
                    WB_Release_SB<=1'b0;
                end
            end
        end
    end
    ///////////////////
    //the rf write back data is selected between alu result and mem dout after reorder
    assign WriteBack_Data=WB_MemRead?DC_Dout_After_Reorder_WB:Alu_Result_WB;
endmodule
