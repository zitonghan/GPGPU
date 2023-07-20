`timescale 1ns/100ps
module Warp_Scheduler #(
    parameter Test="16x16_matrix_multiply"
)(
    input clk,
    input rst_n,
    input Uart_clk,
    input Task_Init,
    input Init_Done,
    input Write_Back,
    input [28:0] Task_Init_Data,
    input [7:0] Task_Init_Addr,
    input [7:0] Task_WriteBack_Addr,
    output [28:0] Task_WriteBack_Data,
    /////////////////////////////////
    //the signals for file IO will be added later
    /////////////////////////////////
    //the pc update address is sent from ID stage if current instruction in ID is a jump, call
    //the pc will be sent from SIMT stack if current instruction in ID is a return and non branch .s instruction
    //if the instruction in ID stage is a branch.s, then the pc of this specific warp will be paused, and the instruction in IF stage will be flushed, and the target address
    //will be sent to this module when it comes out from the ALU. Moreover, if this instruciton cause a divergence among threads, it will push a div token into the SIMT stack. 
    //////////////////////////////////////////////////////////////////////////////////////////////
    //Interafce with WB stage
    //NOTE:the pc update value may be sent from WB or ID, but the stall signal will only be sent from ID stage
    input PC_Update_WB,//indicate a valid pc update request from WB stage
    // since the warp id also has to be decoded at this module, so we hope to cut-off the critical path from the alu to this module
    input [31:0] PC_Update_WB_Addr,
    input [2:0] WarpID_from_WB,//instead of eight bit one-hot fashion, we put a decoder to decode the warp ID sent from WB stage, which can relieve the routing stress
    input [7:0] Update_ActiveMask_WB,//the active mask should be updated if a branch comes out from the WB stage and divergence occurs
    ////////////////////////////////////////////////////////////////////////////////////
    //Interface with ID stage
    //since the ID stage is really close to the warp scheduler, so we use one-hot fashion to transmit warp id,
    //before the instruction goes into instruction buffer, it will be encoded
    /////////////////////////////////////////////////////////////////////////////////////
    //first decode unit
    //for branch and structural hazard, the pc valid should be frozen.
    //however, for jump, call, return instruction, if we don't need to freeze the pc valid, we just need to inactivate the valid bit for sending request to rotate priority resolver
    //so we also need a flush signal from ID stage for these kind of instruction
    input PC_Update_ID0_SIMT,
    input Stall_PC_ID0,
    input [31:0] PC_Update_ID0_SIMT_Addr,
    input [7:0] WarpID_from_ID0,//the warp id send from ID stage, it will be used to stall the updaate of a pc value 
    input [7:0] Update_ActiveMask_ID0,//if this update is caused by a div token from SIMT stack, then update the active mask of certain warp
    //second decode unit
    input PC_Update_ID1_SIMT,
    input Stall_PC_ID1,
    input [31:0] PC_Update_ID1_SIMT_Addr,
    input [7:0] WarpID_from_ID1,
    input [7:0] Update_ActiveMask_ID1,
    ////////////////////////
    output reg [31:0] WS_IF_PC_Warp0,//the instruction fetch address for instruction cache
    output reg [31:0] WS_IF_PC_Warp1,
    output reg [7:0] WS_IF_Active_Mask0,//active mask for current warp
    output reg [7:0] WS_IF_Active_Mask1,
    output reg [7:0] WS_IF_WarpID0,//the warp id  for instruction cache, you can also considered it as a valid bit for instruction, if the instruction is flushed, the signalis 0
    output reg [7:0] WS_IF_WarpID1,
    output reg [31:0] WS_IF_PC0_Plus4,
    output reg [31:0] WS_IF_PC1_Plus4,
    output Flush_IF,//the flush signal for IF stage
    output [7:0] Flush_Warp,//the sequence number of warp to be deleted in IF stage
    //////////////////////////////////
    //Interface with RAU
    input [7:0] RAU_Release_Warp_WS,
    //the numebr of available register sent from regsiter allocation unit
    input [5:0] Num_Of_AviReg,//NOTE: The maximum value is 32, so we need 6bit to accomodate this value
    output [4:0] New_AllocReg_Num,//the maximum value is 16, so needs five bits
    output [7:0] New_Scheduled_HW_WarpID,//at most two HW warps can be scheduled at the same time
    output [31:0] WS_WarpID_Even_RAU,//sw warp ID
    output [31:0] WS_WarpID_Odd_RAU
    //NOTE: The WS should schedule a new warp only  when a exit instruction is detected in ID stage and IB is empty, which means all instructions of this warp 
    //have already get a register mapping information from the RAU, then the new sw warp can be scheduled
);
    //****************************************************************************************************************
    //single port distributed ram
    (* ram_style="distributed" *) reg [28:0] Task [255:0];//all tasks of a program will be initialized in this register
    wire [7:0] Addr1=(!Init_Done)?Task_Init_Addr:Rd_Ptr0; 
    wire [7:0] Addr2=Write_Back?Task_WriteBack_Addr:Rd_Ptr1;
    wire Ram_clk, Wen; 
    wire [28:0] Dout1, Dout2;
    //currently the task is initialized by initial block, once total design is finished, it will be changed to be updated by uart file io
    //each location has 29bit information, 
    //Valid - 1 bit Binary, Software Warp ID - 8 bits (Decimal < 256), PC Value - 9 bits (Decimal <512), Active Mask - 8 bits Binary, #Register Pairs - 3 bits (no more than 4)    
    //valid bit -> 28, register pair -> [2:0], active mask -> [10:3], pc -> [19:11], sw warp id -> [27:20]
    ////////////////////////////////
    //global mux
    BUFGMUX BUFGMUX_WS (
    .O(Ram_clk),   // 1-bit output: Clock output
    .I0(clk), // 1-bit input: Clock input (S=0)
    .I1(Uart_clk), // 1-bit input: Clock input (S=1)
    .S(!Init_Done||Write_Back)    // 1-bit input: Clock select
    );
    always@(posedge Ram_clk)begin
        if(Wen)begin
            Task[Addr1]<=Task_Init_Data;
        end
    end
    assign Wen=Task_Init;
    assign Dout1=Task[Addr1];//port 1 is ued to initialize the task ram
    assign Dout2=Task[Addr2];
    assign Task_WriteBack_Data=Dout2;
    //******************************************************************************************************************
    // initial begin
    //     if(Test=="16x16_draw_circle")begin
    //         $readmemb("Task_Init_16x16_draw_circle.mem", Task);
    //     end else if (Test=="16x16_matrix_multiply")begin
    //         $readmemb("Task_Init.mem", Task);
    //     end  
    // end
    //////////////////////////////////
    reg [7:0] Rd_Ptr0, Rd_Ptr1;//2 read pointers for reading information from the task registers
    ////////////////////////////////////////////////////////////
    reg [7:0] Avi_HW_Warp;//indicate the number of available hardware warps 
    reg [31:0] Program_Counter [7:0]; //eight program counters for eight warp
    reg [7:0] PC_Valid;//indicate if current warp is activated, if it is, it will send a request to rotate priority resolver
    reg [7:0] Active_Mask [7:0]; //the active mask for each warp
    ///////////////////////////////////////////////
    //interface with rotate priority resolver
    wire [7:0] PC_Grant0, PC_Grant1;
    wire [7:0] PC_Valid_After_Stall;
    wire [7:0] Stall_Warp;
    reg [7:0] WarpID_from_WB_After_Decode;
    //////////////////////////////////////////////////
    //signals for indicating the newly scheduled hw Warp ID
    reg [7:0] New_Scheduled_WarpID_Even, New_Scheduled_WarpID_Odd;
    //////////////////////////////////////////////////
    //request signal to rotate priority resolver
    wire [7:0] Request_to_Resolver;
    //every time if a update or stall occurs, it means current value of PC is out-of-data, we should stop it from sending request to resolver
    assign Request_to_Resolver=~({8{PC_Update_WB}}&WarpID_from_WB_After_Decode|{8{PC_Update_ID0_SIMT}}&WarpID_from_ID0|{8{PC_Update_ID1_SIMT}}&WarpID_from_ID1|Stall_Warp)&PC_Valid;
    ///////////////////////////////////////////////
    //the stall can only be caused by branch instruction in ID stage
    assign Stall_Warp={8{Stall_PC_ID0}}&WarpID_from_ID0|{8{Stall_PC_ID1}}&WarpID_from_ID1;
    assign PC_Valid_After_Stall=(~Stall_Warp)&PC_Valid;
    //////////////////////////////////////////////////
    //generate the flush signal and flused sequence number of warp for IF stage
    //since the stall signal is activaed at the ID stage, so we don't need a flush signal for ID stage
    assign Flush_IF=Stall_PC_ID0||Stall_PC_ID1||PC_Update_ID0_SIMT||PC_Update_ID1_SIMT;//NOTE: The the update signal from WB stage should not cause any flushes, since the pc of correponding warp has been locked
    assign Flush_Warp={8{PC_Update_ID0_SIMT}}&WarpID_from_ID0|{8{PC_Update_ID1_SIMT}}&WarpID_from_ID1|Stall_Warp;
    
    ///////////////////////////////////////////////
    integer i;
    /////////////////////////////////////////////
    //always for generating the newly scheduled HW warp ID and the number of registers occupied by these scheduled warp 
    reg [3:0] New_AllocReg_Num_Even,  New_AllocReg_Num_Odd;
    always@(*)begin
        New_Scheduled_WarpID_Even=8'b0000_0000;
        New_Scheduled_WarpID_Odd=8'b0000_0000;
        //////////
        New_AllocReg_Num_Even=4'b0000;
        New_AllocReg_Num_Odd=4'b0000;
        if(Init_Done)begin//start schedule hw warp after the init signal is off
            //Even Warp
            casez({Avi_HW_Warp[6],Avi_HW_Warp[4],Avi_HW_Warp[2],Avi_HW_Warp[0]})
                4'bzzz1: begin
                    if(Dout1[28]&&Num_Of_AviReg>=Dout1[2:0])begin
                        New_Scheduled_WarpID_Even=8'b0000_0001;
                    end
                end
                4'bzz10: begin
                    if(Dout1[28]&&Num_Of_AviReg>=Dout1[2:0])begin
                        New_Scheduled_WarpID_Even=8'b0000_0100;
                    end
                end
                4'bz100: begin
                    if(Dout1[28]&&Num_Of_AviReg>=Dout1[2:0])begin
                        New_Scheduled_WarpID_Even=8'b0001_0000;
                    end
                end
                4'b1000: begin
                    if(Dout1[28]&&Num_Of_AviReg>=Dout1[2:0])begin
                        New_Scheduled_WarpID_Even=8'b0100_0000;
                    end
                end
                //if no available hardware warp, then wait
            endcase
            //Odd Warp
            casez({Avi_HW_Warp[7],Avi_HW_Warp[5],Avi_HW_Warp[3],Avi_HW_Warp[1]})
                4'bzzz1: begin
                    if(Dout2[28]&&(Num_Of_AviReg>=Dout2[2:0]+8&&(|{Avi_HW_Warp[6],Avi_HW_Warp[4],Avi_HW_Warp[2],Avi_HW_Warp[0]})||Num_Of_AviReg>=Dout2[2:0]&&!(|{Avi_HW_Warp[6],Avi_HW_Warp[4],Avi_HW_Warp[2],Avi_HW_Warp[0]})))begin
                        New_Scheduled_WarpID_Odd=8'b0000_0010;
                    end
                end
                
                4'bzz10: begin
                    if(Dout2[28]&&(Num_Of_AviReg>=Dout2[2:0]+8&&(|{Avi_HW_Warp[6],Avi_HW_Warp[4],Avi_HW_Warp[2],Avi_HW_Warp[0]})||Num_Of_AviReg>=Dout2[2:0]&&!(|{Avi_HW_Warp[6],Avi_HW_Warp[4],Avi_HW_Warp[2],Avi_HW_Warp[0]})))begin
                        New_Scheduled_WarpID_Odd=8'b0000_1000;
                    end
                end
                4'bz100: begin
                    if(Dout2[28]&&(Num_Of_AviReg>=Dout2[2:0]+8&&(|{Avi_HW_Warp[6],Avi_HW_Warp[4],Avi_HW_Warp[2],Avi_HW_Warp[0]})||Num_Of_AviReg>=Dout2[2:0]&&!(|{Avi_HW_Warp[6],Avi_HW_Warp[4],Avi_HW_Warp[2],Avi_HW_Warp[0]})))begin
                        New_Scheduled_WarpID_Odd=8'b0010_0000;
                    end
                end
                4'b1000: begin
                    if(Dout2[28]&&(Num_Of_AviReg>=Dout2[2:0]+8&&(|{Avi_HW_Warp[6],Avi_HW_Warp[4],Avi_HW_Warp[2],Avi_HW_Warp[0]})||Num_Of_AviReg>=Dout2[2:0]&&!(|{Avi_HW_Warp[6],Avi_HW_Warp[4],Avi_HW_Warp[2],Avi_HW_Warp[0]})))begin
                        New_Scheduled_WarpID_Odd=8'b1000_0000;
                    end
                end
            endcase
        end
        /////////////
        //the last three bits shows the number of register pairs of this warp
        //so to get the number of registers required by this warp ,we should double the number of regsiter pairs
        if(|New_Scheduled_WarpID_Even)begin
            New_AllocReg_Num_Even={Dout1[2:0],1'b0};
        end
        if(|New_Scheduled_WarpID_Odd)begin
            New_AllocReg_Num_Odd={Dout2[2:0],1'b0};
        end
    end
    assign New_Scheduled_HW_WarpID=New_Scheduled_WarpID_Odd|New_Scheduled_WarpID_Even;
    assign WS_WarpID_Even_RAU=Dout1[27:20];
    assign WS_WarpID_Odd_RAU=Dout2[27:20];
    assign New_AllocReg_Num=New_AllocReg_Num_Even+New_AllocReg_Num_Odd;
    ////////////////////////////////////////
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            Avi_HW_Warp<=8'hff;
            PC_Valid<='b0;//it has to be reset to zero, since this signal will be sent to instruction cache and generate a grant signal, will cause confusion for the following modules
            Rd_Ptr0<='b0;//the even sw id warp is fetched out by read_ptr0
            Rd_Ptr1<='b1;//the odd sw id warp is fetched out by read_ptr1
            for(i=0;i<8;i=i+1)begin
                Program_Counter[i]<='bx;
                Active_Mask[i]<='bx;
            end
        end else begin
            //NOTE:if a structural hazard occurs at ID stage, then We just simply recovery the pc and replay
            ///////////////////////
            //only when stall signal is active we freeze the pc_valid bit
            //update pc valid
            for(i=0;i<8;i=i+1)begin
                if(PC_Valid[i])begin
                    PC_Valid[i]<=PC_Valid_After_Stall[i];
                end else begin//if current pc is locked, then free it if below condition is satisfied
                    if(!Avi_HW_Warp[i]&&PC_Update_WB&&WarpID_from_WB_After_Decode[i])begin
                        PC_Valid[i]<=!PC_Valid[i];
                    end
                end
            end
            //even if current instruction in ID stage fetches sync token from the SIMT stack, and it is unnecessary to update the pc in this time
            //but the active mask should be updated, so we can also update the pc but the pc should be the next instruction after the instruction in ID stage
            //update logic for program counter update
            for(i=0;i<8;i=i+1)begin//the wb update will never conflict with the update from ID stage, since the warp of this branch instruction has been locked
                if(PC_Grant0[i]|PC_Grant1[i])begin//the pc should be incremented by 4 if a grant is given to it
                   Program_Counter[i]<=Program_Counter[i]+4;//default update 
                end
                if(!Avi_HW_Warp[i]&&PC_Update_WB&&WarpID_from_WB_After_Decode[i])begin
                    Program_Counter[i]<=PC_Update_WB_Addr;
                    Active_Mask[i]<=Update_ActiveMask_WB;
                end
                if(!Avi_HW_Warp[i]&&PC_Update_ID0_SIMT&&WarpID_from_ID0[i])begin
                    Program_Counter[i]<=PC_Update_ID0_SIMT_Addr;
                    Active_Mask[i]<=Update_ActiveMask_ID0;
                end
                if(!Avi_HW_Warp[i]&&PC_Update_ID1_SIMT&&WarpID_from_ID1[i])begin
                    Program_Counter[i]<=PC_Update_ID1_SIMT_Addr;
                    Active_Mask[i]<=Update_ActiveMask_ID1;
                end
            end
            //the eight warp can be divided two part, each part every time can only activate at most 1 warp
            for(i=0;i<4;i=i+1)begin
                if(New_Scheduled_WarpID_Even[2*i])begin
                    PC_Valid[2*i]<=!PC_Valid[2*i];
                    Avi_HW_Warp[2*i]<=!Avi_HW_Warp[2*i];//flip the available hardware warp signal
                    Active_Mask[2*i]<=Dout1[10:3];
                    Program_Counter[2*i]<=Dout1[19:11];
                    Rd_Ptr0<=Rd_Ptr0+2;
                end
                if(New_Scheduled_WarpID_Odd[2*i+1])begin
                    PC_Valid[2*i+1]<=!PC_Valid[2*i+1];
                    Avi_HW_Warp[2*i+1]<=!Avi_HW_Warp[2*i+1];//flip the available hardware warp signal
                    Active_Mask[2*i+1]<=Dout2[10:3];
                    Program_Counter[2*i+1]<=Dout2[19:11];
                    Rd_Ptr1<=Rd_Ptr1+2;
                end
            end
            ////////////////////////////////////
            //once a exit instruction is decoded at the ID stage, then reset the pc valid and set the available hardware warp signal
            //NOTE：For the update of Avi_HW_Warp signal, when the Warp-Done is 1, the IB might not be empty yet, some of instruction might still stay in
            //the IB. In this case, warp Scheduler can not schedule a new sw warp in order to avoiding some problems in register mapping
            for(i=0;i<8;i=i+1)begin
                if(!Avi_HW_Warp[i]&&RAU_Release_Warp_WS[i])begin
                    Avi_HW_Warp[i]<=!Avi_HW_Warp[i];
                end
            end
        end
    end
    ///////////////////
    //always block to generate instruction fetch pc
    always@(*)begin
        WS_IF_WarpID0=PC_Grant0;//all zeros means instruction is invalid
        WS_IF_WarpID1=PC_Grant1;
        ////
        WS_IF_PC_Warp0=Program_Counter[0];
        WS_IF_Active_Mask0=Active_Mask[0];
        WS_IF_PC0_Plus4=Program_Counter[0]+4;
        ////
        WS_IF_PC_Warp1=Program_Counter[0];
        WS_IF_Active_Mask1=Active_Mask[0];
        WS_IF_PC1_Plus4=Program_Counter[0]+4;
        //default assignment
        /////////////////////////////////////
        for(i=1;i<8;i=i+1)begin
            if(PC_Grant0[i])begin
                WS_IF_PC_Warp0=Program_Counter[i];
                WS_IF_Active_Mask0=Active_Mask[i];
                WS_IF_PC0_Plus4=Program_Counter[i]+4;
            end
            //
            if(PC_Grant1[i])begin
                WS_IF_PC_Warp1=Program_Counter[i];
                WS_IF_Active_Mask1=Active_Mask[i];
                WS_IF_PC1_Plus4=Program_Counter[i]+4;
            end
        end
    end
    /////////////////////////////////
    //always combinational block used for generating decoded warp ID sent from WB
    always@(*)begin
         case(WarpID_from_WB)
            3'b001:WarpID_from_WB_After_Decode=8'b0000_0010;
            3'b010:WarpID_from_WB_After_Decode=8'b0000_0100;
            3'b011:WarpID_from_WB_After_Decode=8'b0000_1000;
            3'b100:WarpID_from_WB_After_Decode=8'b0001_0000;
            3'b101:WarpID_from_WB_After_Decode=8'b0010_0000;
            3'b110:WarpID_from_WB_After_Decode=8'b0100_0000;
            3'b111:WarpID_from_WB_After_Decode=8'b1000_0000;
            default:WarpID_from_WB_After_Decode=8'b0000_0001;
        endcase
    end
    ///////////////////
    Rotate_Priority_2Grant RP(
        .clk(clk),
        .rst_n(rst_n),
        .Icache_Fetch_Request(Request_to_Resolver),
        .Grant1(PC_Grant0),
        .Grant2(PC_Grant1)
    );
endmodule
