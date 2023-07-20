`timescale 1ns/100ps
module Banked_Register_File(
    input clk,
    input rst_n,
    //////////////
    //interface with RAU
    input [1:0] RAU_EntryNum_RF,//the entry of the instruction allocated at the OC
    input [5:0] Src1_PhyRegAddr,
    input [5:0] Src2_PhyRegAddr,
    /////////////
    //interface with OC
    output [255:0] RF_Out_Bank0,
    output [255:0] RF_Out_Bank1,
    output [255:0] RF_Out_Bank2,
    output [255:0] RF_Out_Bank3,
    output [1:0] RF_Bank0_EntryNum_OC,
    output [1:0] RF_Bank1_EntryNum_OC,
    output [1:0] RF_Bank2_EntryNum_OC,
    output [1:0] RF_Bank3_EntryNum_OC,
    output reg [3:0] RF_Dout_Valid,//indicate if the data out of each register file is valid
    output reg [3:0] RF_SrcNum_OC, //0 means src1, 1 means src2, used to determine the entry of OC to be written into
    //interface with WB write back
    input WB_Regwrite,
    input [7:0] WB_Active_Mask,
    input [4:0] WriteBack_PhyRegAddr,
    input [255:0] WriteBack_Data
);
    //*********************************************************************************************//
    //this module contains the 4 request fifos, each fifo has 8 locations, then each fifo is responsible for
    //sending requst to corresponding bank of regiser file, then register file sends the readout data 
    //to operand collector
    //*********************************************************************************************//
    genvar i,k;
    integer j;
    ////////////////////////////
    wire [3:0] FIFO_Wen_1st, FIFO_Wen_2nd, FIFO_Ren;
    reg [3:0] Src1_to_FIFO, Src2_to_FIFO;//the request signals of src1 and src2 regsiters for each fifo 
    wire [5:0] FIFO_din1 [3:0];//2 bit OC entry number + upper 3bits of  register address, lower 2bits is used to select the request fifo, they don't need enter into fifo
    wire [5:0] FIFO_din2 [3:0];//din1 means the data from src1, din2 stands for the data from src2
    //NOTE: 1 extral bit in data_in for indicating the request is from Src1 or 2, 0->src1, 1->src2
    wire [3:0] Empty;
    reg [3:0] WriteBack_to_RF_Bank;
    wire [5:0] FIFO_dout [3:0];//fifo's output is the input for each bank of register file
    wire [2:0] RF_Access_Addr [3:0];//register file input address, it is multiplexed by write enable signal of the register file bank
    wire [255:0] RF_Dout [3:0];
    //NOTE: we use below alwasys block to generate the request signal of each source registers to request fifos
    //if source 1 is valid, then set the corresponding bit of Src1_to_FIFO to 1, it is same for src2
    //then use this two signals to activate the we_1st and we_2nd of each fifo
    //if two write enable signals of a single request fifo are both one, write two data into this fifo at the same time
    //if only one of them is 1, just write one data into FIFO
    /////////////////////
    //it is the same for generating writeback_to_RF_bank， if there is a write request for one of four regsiter file banks
    //then don't activate the read enable signal for corresponding request fifo
    always@(*)begin
        Src1_to_FIFO='b0; 
        Src2_to_FIFO='b0;
        WriteBack_to_RF_Bank='b0;
        //generate the src1 request to fifos
        if(Src1_PhyRegAddr[5])begin
            case(Src1_PhyRegAddr[1:0])
                2'b00:Src1_to_FIFO=4'b0001; 
                2'b01:Src1_to_FIFO=4'b0010; 
                2'b10:Src1_to_FIFO=4'b0100; 
                2'b11:Src1_to_FIFO=4'b1000; 
            endcase
        end
        //generate the src2 request to fifos
        if(Src2_PhyRegAddr[5])begin
            case(Src2_PhyRegAddr[1:0])
                2'b00:Src2_to_FIFO=4'b0001; 
                2'b01:Src2_to_FIFO=4'b0010; 
                2'b10:Src2_to_FIFO=4'b0100; 
                2'b11:Src2_to_FIFO=4'b1000; 
            endcase
        end   
        //generate write back request to fifos
        if(WB_Regwrite)begin
            case(WriteBack_PhyRegAddr[1:0])
                2'b00:WriteBack_to_RF_Bank=4'b0001;
                2'b01:WriteBack_to_RF_Bank=4'b0010;
                2'b10:WriteBack_to_RF_Bank=4'b0100;
                2'b11:WriteBack_to_RF_Bank=4'b1000;
            endcase
        end
    end
    ///////////////////////////////////////////
    reg [1:0] RF_EntryNum_OC [3:0];
    ///////////////////////////////////////////
    assign RF_Out_Bank0=RF_Dout[0];
    assign RF_Out_Bank1=RF_Dout[1];
    assign RF_Out_Bank2=RF_Dout[2];
    assign RF_Out_Bank3=RF_Dout[3];
    assign RF_Bank0_EntryNum_OC=RF_EntryNum_OC[0];
    assign RF_Bank1_EntryNum_OC=RF_EntryNum_OC[1];
    assign RF_Bank2_EntryNum_OC=RF_EntryNum_OC[2];
    assign RF_Bank3_EntryNum_OC=RF_EntryNum_OC[3];
    //always block for generatng output valid signal for OC
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            RF_Dout_Valid<='b0;
            RF_SrcNum_OC<='bx;
            for(j=0;j<4;j=j+1)begin
                RF_EntryNum_OC[j]<='bx;
            end
        end else begin
            for(j=0;j<4;j=j+1)begin
                RF_EntryNum_OC[j]<=FIFO_dout[j][4:3];
                RF_Dout_Valid[j]<=FIFO_Ren[j];
                RF_SrcNum_OC[j]<=FIFO_dout[j][5];
            end      
        end
    end
    ///////////////////////////////////////////
    //instantiate request fifo and register file banks
    generate
        for(i=0;i<4;i=i+1)begin:Request_FIFO_Inst
            assign FIFO_Wen_1st[i]=Src1_to_FIFO[i];
            assign FIFO_Wen_2nd[i]=Src2_to_FIFO[i];
            assign FIFO_din1[i]={1'b0,RAU_EntryNum_RF,Src1_PhyRegAddr[4:2]};
            assign FIFO_din2[i]={1'b1,RAU_EntryNum_RF,Src2_PhyRegAddr[4:2]};
            assign FIFO_Ren[i]=!Empty[i]&&!WriteBack_to_RF_Bank[i];//if the request fifo is not empty and no conflict between write back and read source
            assign RF_Access_Addr[i]=WriteBack_to_RF_Bank[i]?WriteBack_PhyRegAddr[4:2]:FIFO_dout[i][2:0];
            //NOTE: the write back operation has a higher priority than read operation to RF
            //4 request fifos
            Req_FIFO fifo(
                .clk(clk),
                .rst_n(rst_n),
                .Wen_1st(FIFO_Wen_1st[i]),
                .wen_2nd(FIFO_Wen_2nd[i]),
                .Ren(FIFO_Ren[i]),
                .din1(FIFO_din1[i]),
                .din2(FIFO_din2[i]),
                .dout(FIFO_dout[i]),
                .Empty(Empty[i])
            );
            //////
            //4 banks single port bram used as register files
            //each 32bit to be written into RF should be controlled by active mask, so the total rf is divided into 4 banks, for each bank, the register is divided into 8 parts for each thread
            for(k=0;k<8;k=k+1)begin
                 Single_Port_BRAM Banked_RF(
                    .clk(clk),
                    .we(WriteBack_to_RF_Bank[i]&&WB_Active_Mask[k]),//only if the wb_active_mask is 1, the data can be written into register file
                    .addr(RF_Access_Addr[i]),
                    .din(WriteBack_Data[32*k +: 32]),
                    .dout(RF_Dout[i][32*k +: 32]) 
                ); 
            end
        end
        
    endgenerate
endmodule