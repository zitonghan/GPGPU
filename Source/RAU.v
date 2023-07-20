`timescale 1ns/100ps
module RAU(
    input clk,
    input rst_n,
    ////////////
    //interface with IU
    input [7:0] IU_Grant,//indicate the validity and warp ID of the current instruction coming out from the IB
    //interface with  IB 
    input [5:0] IB_Src1_Out_RAU, //MSB -> valid bit
	input [5:0] IB_Src2_Out_RAU,
	input [5:0] IB_Dst_Out_RAU,
    //////////////
    //interface with RF
    output [1:0] RAU_EntryNum_RF,//the entry of the instruction allocated at the OC
    output reg [5:0] Src1_PhyRegAddr,
    output reg [5:0] Src2_PhyRegAddr,
    //interface with OC
    input [1:0] OC_EntryNum_RAU,//indicate the entry where the readout information should enter, it will be carried with the source register information into RF
    output reg [4:0] Dst_PhyRegAddr,//
    //the destinatinal physical register's valid is not needed, since the ALU has ohter signals to identify if the destination register is valid
    //NOTE:the valid bit for input destinational logic register is needed becasue we use it to see if the instruction needs to allocate a new physical tag
    //if the logic source register number is 8 or 16, then directly fetch out the data from special registers , don't goes to RF
    output reg [255:0] Src1_Reg8_16_Data,//Special registers value for $8->thread ID, $16->sw warp ID
    output reg [255:0] Src2_Reg8_16_Data,
    //interface with ID
    input [7:0] ID_Warp_Release_RAU, //indicate which warp's register mapping information should be released
    //interface with WS
    output reg [5:0] Num_Of_AviReg,
    input [4:0] WS_New_AllocReg_Num, 
    input [7:0] New_Scheduled_HW_WarpID,//at most two HW warps can be scheduled at the same time
    input [31:0] WS_WarpID_Even_RAU,//software warp ID
    input [31:0] WS_WarpID_Odd_RAU,
    output [7:0] RAU_Release_Warp_WS
    //we can get the sw thread ID by multiplying the sw warp ID with 8
);
    integer i, j, k;
    //The entire Free physical register list is divided into four banks, which is matched to the real register file
    reg [4:0] PhyReg_Num_Bank [3:0] [7:0]; //used to store physical register number, it should be a memory since the contents in this memory is never changed
    //so we use below initial block to initialize it
    reg [7:0] PhyReg_Valid_Bank [3:0];//these two signals are regsiters, used to store valid bit and warp ID
    reg [2:0] PhyReg_WarpID_Bank[3:0] [7:0];
    initial begin
        for(i=0;i<8;i=i+1)begin
            for(j=0;j<4;j=j+1)begin
                PhyReg_Num_Bank[j][i]=4*i+j;
            end
        end
    end 
    ////////////////////////////////////////////////////
    assign RAU_EntryNum_RF=OC_EntryNum_RAU;
    ////////////////////////////////////////////////////
    //special registers for storing sw thread and warp ID
    reg [255:0] Logic_Reg8_ThreadID [7:0];
    reg [255:0] Logic_Reg16_WarpID [7:0];
    ////////////////////////////////////////////////////
    //The output phyreg tag of each bank of the entry which is indexed by PhyReg_Bank_AccAddr signals
    reg [4:0] PhyRegNum_Bank_Out[3:0];
    reg [1:0] Warp_Bank_Ptr;
    //only one ptr is needed, all hw warp share the same pointer, if current warp0 request a tag in bank0, then pointer ->2'b01, then next warp
    //can get the physical tag from bank1
    //////////////////////////////////////////////////
    // the address of the first entry from entry0 ->7 in each bank, which contains a valid phytag 
    reg [2:0] PhyReg_Bank_AccAddr [3:0];
    always@(*)begin
        for(i=0;i<4;i=i+1)begin
            casez(PhyReg_Valid_Bank[i])
                8'bzzzz_zz10:PhyReg_Bank_AccAddr[i]=3'd1;
                8'bzzzz_z100:PhyReg_Bank_AccAddr[i]=3'd2;
                8'bzzzz_1000:PhyReg_Bank_AccAddr[i]=3'd3;
                8'bzzz1_0000:PhyReg_Bank_AccAddr[i]=3'd4;
                8'bzz10_0000:PhyReg_Bank_AccAddr[i]=3'd5;
                8'bz100_0000:PhyReg_Bank_AccAddr[i]=3'd6;
                8'b1000_0000:PhyReg_Bank_AccAddr[i]=3'd7;
                default:PhyReg_Bank_AccAddr[i]=3'd0;
            endcase
            PhyRegNum_Bank_Out[i]=PhyReg_Num_Bank[i][PhyReg_Bank_AccAddr[i]];
        end
    end
    //combinational logic for generating output phyreg tag of each bank
    //NOTE: before the program starts using some registers to do computation, it has to do initialization.
    //the first instruction of any program must be xor $A $A $A to get 0 at $A, then using $A and immediate instruction to initialize other registers
    //so each time at most one new phyreg tag will be allocated from the free phyreg list
    reg Dst_Mapping_Unfound;
    reg [5:0] PhyReg_Mapping_Table [7:0] [7:0];//eanch warp has a table, each table has 8 entries , corresponding to at most 8 registers
    always@(*)begin
        Dst_PhyRegAddr=PhyReg_Mapping_Table[0][IB_Dst_Out_RAU[4:0]][4:0];//default assignment
        for(i=0;i<8;i=i+1)begin
            //if the dst register need to allocate a new phy tag, we assign the output of free physical register list to output
            if(IU_Grant[i]&&Dst_Mapping_Unfound&&IB_Dst_Out_RAU[5])begin//if current instruction belongs to warp i, then check its bank poiner to find the idealest bank to get a physical tag
                case(Warp_Bank_Ptr)//the pointer will always points to a bank which still has free physical registers
                    2'b00:Dst_PhyRegAddr=PhyRegNum_Bank_Out[0];
                    2'b01:Dst_PhyRegAddr=PhyRegNum_Bank_Out[1];
                    2'b10:Dst_PhyRegAddr=PhyRegNum_Bank_Out[2];
                    2'b11:Dst_PhyRegAddr=PhyRegNum_Bank_Out[3];
                endcase
            end else if(IU_Grant[i]&&!Dst_Mapping_Unfound&&IB_Dst_Out_RAU[5]) begin
                //NOTE: if the destination register is valid and a corresponding phy register is found in mapping table
                //then we assign the stored physical register address in mapping to the output dst_phyregaddr
                Dst_PhyRegAddr=PhyReg_Mapping_Table[i][IB_Dst_Out_RAU[4:0]][4:0];
            end
        end
    end
    //////////////////////////////
    always@(*)begin
        Dst_Mapping_Unfound=1'b1;
        for(i=0;i<8;i=i+1)begin
            if(IU_Grant[i])begin
                ///Note: when we search the mapping table to see if the destination register of current instruction alreay has physical tag
                //so we just need to check if the valid bit of corresponding of a warp is 1, the value store in this entry is physical register address
                //however, we want to see if the logic destination register has a physical tag
                if(PhyReg_Mapping_Table[i][IB_Dst_Out_RAU[4:0]][5])begin
                    Dst_Mapping_Unfound=1'b0;
                end
            end
        end
    end
    //the always block for updating free phy reg list and mapping table
    reg [7:0] Warp_Release_Reg;
    reg [3:0] Release_Even_Warp, Release_Odd_Warp;
    assign RAU_Release_Warp_WS={Release_Odd_Warp[3],Release_Even_Warp[3],Release_Odd_Warp[2],Release_Even_Warp[2],Release_Odd_Warp[1],Release_Even_Warp[1],Release_Odd_Warp[0],Release_Even_Warp[0]};
    //
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            for(i=0;i<4;i=i+1)begin
                PhyReg_Valid_Bank[i]<=8'hff;
                for(j=0;j<8;j=j+1)begin
                    PhyReg_WarpID_Bank[i][j]<='bx;
                end
            end
            /////////////
            Warp_Release_Reg<='b0;
            /////////////
            for(i=0;i<8;i=i+1)begin
                for(j=0;j<8;j=j+1)begin
                    PhyReg_Mapping_Table[i][j][5]<=1'b0;//reset valid bit
                    PhyReg_Mapping_Table[i][j][4:0]<='bx;
                end
            end
        end else begin
             Warp_Release_Reg<=Warp_Release_Reg|ID_Warp_Release_RAU;
             //default assignment, not warp finishes releasing during current clock, if a warp did finished the work, then set the specific bit to correct value
            if(Dst_Mapping_Unfound&&IB_Dst_Out_RAU[5])begin
                case(IU_Grant)
                    8'b0000_0001:begin
                        PhyReg_Mapping_Table[0][IB_Dst_Out_RAU[4:0]][5]<=!PhyReg_Mapping_Table[0][IB_Dst_Out_RAU[4:0]][5];
                        case(Warp_Bank_Ptr)
                            2'b00:begin
                                PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]]<=!PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]];
                                PhyReg_WarpID_Bank[0][PhyReg_Bank_AccAddr[0]]<=0;
                                PhyReg_Mapping_Table[0][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[0];      
                            end
                            2'b01:begin
                                PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]]<=!PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]];
                                PhyReg_WarpID_Bank[1][PhyReg_Bank_AccAddr[1]]<=0;
                                PhyReg_Mapping_Table[0][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[1];                              
                            end
                            2'b10:begin                       
                                PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]]<=!PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]];
                                PhyReg_WarpID_Bank[2][PhyReg_Bank_AccAddr[2]]<=0;
                                PhyReg_Mapping_Table[0][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[2];
                            end
                            2'b11:begin
                                PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]]<=!PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]];
                                PhyReg_WarpID_Bank[3][PhyReg_Bank_AccAddr[3]]<=0;
                                PhyReg_Mapping_Table[0][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[3];        
                            end
                        endcase
                    end
                    8'b0000_0010:begin
                        PhyReg_Mapping_Table[1][IB_Dst_Out_RAU[4:0]][5]<=!PhyReg_Mapping_Table[1][IB_Dst_Out_RAU[4:0]][5];
                        case(Warp_Bank_Ptr)
                            2'b00:begin
                                PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]]<=!PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]];
                                PhyReg_WarpID_Bank[0][PhyReg_Bank_AccAddr[0]]<=1;
                                PhyReg_Mapping_Table[1][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[0];      
                            end
                            2'b01:begin
                                PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]]<=!PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]];
                                PhyReg_WarpID_Bank[1][PhyReg_Bank_AccAddr[1]]<=1;
                                PhyReg_Mapping_Table[1][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[1];                              
                            end
                            2'b10:begin                       
                                PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]]<=!PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]];
                                PhyReg_WarpID_Bank[2][PhyReg_Bank_AccAddr[2]]<=1;
                                PhyReg_Mapping_Table[1][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[2];
                            end
                            2'b11:begin
                                PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]]<=!PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]];
                                PhyReg_WarpID_Bank[3][PhyReg_Bank_AccAddr[3]]<=1;
                                PhyReg_Mapping_Table[1][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[3];        
                            end
                        endcase
                    end
                    8'b0000_0100:begin
                        PhyReg_Mapping_Table[2][IB_Dst_Out_RAU[4:0]][5]<=!PhyReg_Mapping_Table[2][IB_Dst_Out_RAU[4:0]][5];
                        case(Warp_Bank_Ptr)
                            2'b00:begin
                                PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]]<=!PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]];
                                PhyReg_WarpID_Bank[0][PhyReg_Bank_AccAddr[0]]<=2;
                                PhyReg_Mapping_Table[2][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[0];      
                            end
                            2'b01:begin
                                PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]]<=!PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]];
                                PhyReg_WarpID_Bank[1][PhyReg_Bank_AccAddr[1]]<=2;
                                PhyReg_Mapping_Table[2][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[1];                              
                            end
                            2'b10:begin                       
                                PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]]<=!PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]];
                                PhyReg_WarpID_Bank[2][PhyReg_Bank_AccAddr[2]]<=2;
                                PhyReg_Mapping_Table[2][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[2];
                            end
                            2'b11:begin
                                PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]]<=!PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]];
                                PhyReg_WarpID_Bank[3][PhyReg_Bank_AccAddr[3]]<=2;
                                PhyReg_Mapping_Table[2][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[3];        
                            end
                        endcase
                    end
                    8'b0000_1000:begin
                        PhyReg_Mapping_Table[3][IB_Dst_Out_RAU[4:0]][5]<=!PhyReg_Mapping_Table[3][IB_Dst_Out_RAU[4:0]][5];
                        case(Warp_Bank_Ptr)
                            2'b00:begin
                                PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]]<=!PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]];
                                PhyReg_WarpID_Bank[0][PhyReg_Bank_AccAddr[0]]<=3;
                                PhyReg_Mapping_Table[3][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[0];      
                            end
                            2'b01:begin
                                PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]]<=!PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]];
                                PhyReg_WarpID_Bank[1][PhyReg_Bank_AccAddr[1]]<=3;
                                PhyReg_Mapping_Table[3][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[1];                              
                            end
                            2'b10:begin                       
                                PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]]<=!PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]];
                                PhyReg_WarpID_Bank[2][PhyReg_Bank_AccAddr[2]]<=3;
                                PhyReg_Mapping_Table[3][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[2];
                            end
                            2'b11:begin
                                PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]]<=!PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]];
                                PhyReg_WarpID_Bank[3][PhyReg_Bank_AccAddr[3]]<=3;
                                PhyReg_Mapping_Table[3][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[3];        
                            end
                        endcase
                    end
                    8'b0001_0000:begin
                        PhyReg_Mapping_Table[4][IB_Dst_Out_RAU[4:0]][5]<=!PhyReg_Mapping_Table[4][IB_Dst_Out_RAU[4:0]][5];
                        case(Warp_Bank_Ptr)
                            2'b00:begin
                                PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]]<=!PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]];
                                PhyReg_WarpID_Bank[0][PhyReg_Bank_AccAddr[0]]<=4;
                                PhyReg_Mapping_Table[4][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[0];      
                            end
                            2'b01:begin
                                PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]]<=!PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]];
                                PhyReg_WarpID_Bank[1][PhyReg_Bank_AccAddr[1]]<=4;
                                PhyReg_Mapping_Table[4][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[1];                              
                            end
                            2'b10:begin                       
                                PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]]<=!PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]];
                                PhyReg_WarpID_Bank[2][PhyReg_Bank_AccAddr[2]]<=4;
                                PhyReg_Mapping_Table[4][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[2];
                            end
                            2'b11:begin
                                PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]]<=!PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]];
                                PhyReg_WarpID_Bank[3][PhyReg_Bank_AccAddr[3]]<=4;
                                PhyReg_Mapping_Table[4][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[3];        
                            end
                        endcase
                    end
                    8'b0010_0000:begin
                        PhyReg_Mapping_Table[5][IB_Dst_Out_RAU[4:0]][5]<=!PhyReg_Mapping_Table[5][IB_Dst_Out_RAU[4:0]][5];
                        case(Warp_Bank_Ptr)
                            2'b00:begin
                                PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]]<=!PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]];
                                PhyReg_WarpID_Bank[0][PhyReg_Bank_AccAddr[0]]<=5;
                                PhyReg_Mapping_Table[5][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[0];      
                            end
                            2'b01:begin
                                PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]]<=!PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]];
                                PhyReg_WarpID_Bank[1][PhyReg_Bank_AccAddr[1]]<=5;
                                PhyReg_Mapping_Table[5][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[1];                              
                            end
                            2'b10:begin                       
                                PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]]<=!PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]];
                                PhyReg_WarpID_Bank[2][PhyReg_Bank_AccAddr[2]]<=5;
                                PhyReg_Mapping_Table[5][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[2];
                            end
                            2'b11:begin
                                PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]]<=!PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]];
                                PhyReg_WarpID_Bank[3][PhyReg_Bank_AccAddr[3]]<=5;
                                PhyReg_Mapping_Table[5][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[3];        
                            end
                        endcase
                    end
                    8'b0100_0000:begin
                        PhyReg_Mapping_Table[6][IB_Dst_Out_RAU[4:0]][5]<=!PhyReg_Mapping_Table[6][IB_Dst_Out_RAU[4:0]][5];
                        case(Warp_Bank_Ptr)
                            2'b00:begin
                                PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]]<=!PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]];
                                PhyReg_WarpID_Bank[0][PhyReg_Bank_AccAddr[0]]<=6;
                                PhyReg_Mapping_Table[6][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[0];      
                            end
                            2'b01:begin
                                PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]]<=!PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]];
                                PhyReg_WarpID_Bank[1][PhyReg_Bank_AccAddr[1]]<=6;
                                PhyReg_Mapping_Table[6][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[1];                              
                            end
                            2'b10:begin                       
                                PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]]<=!PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]];
                                PhyReg_WarpID_Bank[2][PhyReg_Bank_AccAddr[2]]<=6;
                                PhyReg_Mapping_Table[6][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[2];
                            end
                            2'b11:begin
                                PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]]<=!PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]];
                                PhyReg_WarpID_Bank[3][PhyReg_Bank_AccAddr[3]]<=6;
                                PhyReg_Mapping_Table[6][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[3];        
                            end
                        endcase
                    end
                    8'b1000_0000:begin
                        PhyReg_Mapping_Table[7][IB_Dst_Out_RAU[4:0]][5]<=!PhyReg_Mapping_Table[7][IB_Dst_Out_RAU[4:0]][5];
                        case(Warp_Bank_Ptr)
                            2'b00:begin
                                PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]]<=!PhyReg_Valid_Bank[0][PhyReg_Bank_AccAddr[0]];
                                PhyReg_WarpID_Bank[0][PhyReg_Bank_AccAddr[0]]<=7;
                                PhyReg_Mapping_Table[7][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[0];      
                            end
                            2'b01:begin
                                PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]]<=!PhyReg_Valid_Bank[1][PhyReg_Bank_AccAddr[1]];
                                PhyReg_WarpID_Bank[1][PhyReg_Bank_AccAddr[1]]<=7;
                                PhyReg_Mapping_Table[7][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[1];                              
                            end
                            2'b10:begin                       
                                PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]]<=!PhyReg_Valid_Bank[2][PhyReg_Bank_AccAddr[2]];
                                PhyReg_WarpID_Bank[2][PhyReg_Bank_AccAddr[2]]<=7;
                                PhyReg_Mapping_Table[7][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[2];
                            end
                            2'b11:begin
                                PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]]<=!PhyReg_Valid_Bank[3][PhyReg_Bank_AccAddr[3]];
                                PhyReg_WarpID_Bank[3][PhyReg_Bank_AccAddr[3]]<=7;
                                PhyReg_Mapping_Table[7][IB_Dst_Out_RAU[4:0]][4:0]<=PhyRegNum_Bank_Out[3];        
                            end
                        endcase
                    end
                endcase
            end
            //////////////////////////////
            //release at most one even warp
            case(Release_Even_Warp)
                4'b0001:begin
                   for(j=0;j<8;j=j+1)begin
                        //release Free Physical Register list
                        for(i=0;i<4;i=i+1)begin
                            if(!PhyReg_Valid_Bank[i][j]&&PhyReg_WarpID_Bank[i][j]==0)begin
                                PhyReg_Valid_Bank[i][j]<=!PhyReg_Valid_Bank[i][j];
                            end
                        end 
                        //release Mapping Table
                        if(PhyReg_Mapping_Table[0][j][5])begin
                            PhyReg_Mapping_Table[0][j][5]<=!PhyReg_Mapping_Table[0][j][5];
                        end 
                    end
                    //set the Warp_Release_Reg
                    if(Warp_Release_Reg[0])begin
                        Warp_Release_Reg[0]<=!Warp_Release_Reg[0];
                    end else if(ID_Warp_Release_RAU[0])begin
                        Warp_Release_Reg[0]<=Warp_Release_Reg[0];
                    end
                end
                4'b0010:begin
                   for(j=0;j<8;j=j+1)begin
                        //release Free Physical Register list
                        for(i=0;i<4;i=i+1)begin
                            if(!PhyReg_Valid_Bank[i][j]&&PhyReg_WarpID_Bank[i][j]==2)begin
                                PhyReg_Valid_Bank[i][j]<=!PhyReg_Valid_Bank[i][j];
                            end
                        end 
                        //release Mapping Table
                        if(PhyReg_Mapping_Table[2][j][5])begin
                            PhyReg_Mapping_Table[2][j][5]<=!PhyReg_Mapping_Table[2][j][5];
                        end 
                    end
                    //set the Warp_Release_Reg
                    if(Warp_Release_Reg[2])begin
                        Warp_Release_Reg[2]<=!Warp_Release_Reg[2];
                    end else if(ID_Warp_Release_RAU[2])begin
                        Warp_Release_Reg[2]<=Warp_Release_Reg[2];
                    end
                end
                4'b0100:begin
                   for(j=0;j<8;j=j+1)begin
                        //release Free Physical Register list
                        for(i=0;i<4;i=i+1)begin
                            if(!PhyReg_Valid_Bank[i][j]&&PhyReg_WarpID_Bank[i][j]==4)begin
                                PhyReg_Valid_Bank[i][j]<=!PhyReg_Valid_Bank[i][j];
                            end
                        end 
                        //release Mapping Table
                        if(PhyReg_Mapping_Table[4][j][5])begin
                            PhyReg_Mapping_Table[4][j][5]<=!PhyReg_Mapping_Table[4][j][5];
                        end 
                    end
                    //set the Warp_Release_Reg
                    if(Warp_Release_Reg[4])begin
                        Warp_Release_Reg[4]<=!Warp_Release_Reg[4];
                    end else if(ID_Warp_Release_RAU[4])begin
                        Warp_Release_Reg[4]<=Warp_Release_Reg[4];
                    end
                end
                4'b1000:begin
                   for(j=0;j<8;j=j+1)begin
                        //release Free Physical Register list
                        for(i=0;i<4;i=i+1)begin
                            if(!PhyReg_Valid_Bank[i][j]&&PhyReg_WarpID_Bank[i][j]==6)begin
                                PhyReg_Valid_Bank[i][j]<=!PhyReg_Valid_Bank[i][j];
                            end
                        end 
                        //release Mapping Table
                        if(PhyReg_Mapping_Table[6][j][5])begin
                            PhyReg_Mapping_Table[6][j][5]<=!PhyReg_Mapping_Table[6][j][5];
                        end 
                    end
                    //set the Warp_Release_Reg
                    if(Warp_Release_Reg[6])begin
                        Warp_Release_Reg[6]<=!Warp_Release_Reg[6];
                    end else if(ID_Warp_Release_RAU[6])begin
                        Warp_Release_Reg[6]<=Warp_Release_Reg[6];
                    end
                end
            endcase
            //release at most one even warp
            case(Release_Odd_Warp)
                4'b0001:begin
                   for(j=0;j<8;j=j+1)begin
                        //release Free Physical Register list
                        for(i=0;i<4;i=i+1)begin
                            if(!PhyReg_Valid_Bank[i][j]&&PhyReg_WarpID_Bank[i][j]==1)begin
                                PhyReg_Valid_Bank[i][j]<=!PhyReg_Valid_Bank[i][j];
                            end
                        end 
                        //release Mapping Table
                        if(PhyReg_Mapping_Table[1][j][5])begin
                            PhyReg_Mapping_Table[1][j][5]<=!PhyReg_Mapping_Table[1][j][5];
                        end 
                    end
                    //set the Warp_Release_Reg
                    if(Warp_Release_Reg[1])begin
                        Warp_Release_Reg[1]<=!Warp_Release_Reg[1];
                    end else if(ID_Warp_Release_RAU[1])begin
                        Warp_Release_Reg[1]<=Warp_Release_Reg[1];
                    end
                end
                4'b0010:begin
                   for(j=0;j<8;j=j+1)begin
                        //release Free Physical Register list
                        for(i=0;i<4;i=i+1)begin
                            if(!PhyReg_Valid_Bank[i][j]&&PhyReg_WarpID_Bank[i][j]==3)begin
                                PhyReg_Valid_Bank[i][j]<=!PhyReg_Valid_Bank[i][j];
                            end
                        end 
                        //release Mapping Table
                        if(PhyReg_Mapping_Table[3][j][5])begin
                            PhyReg_Mapping_Table[3][j][5]<=!PhyReg_Mapping_Table[3][j][5];
                        end 
                    end
                    //set the Warp_Release_Reg
                    if(Warp_Release_Reg[3])begin
                        Warp_Release_Reg[3]<=!Warp_Release_Reg[3];
                    end else if(ID_Warp_Release_RAU[3])begin
                        Warp_Release_Reg[3]<=Warp_Release_Reg[3];
                    end
                end
                4'b0100:begin
                   for(j=0;j<8;j=j+1)begin
                        //release Free Physical Register list
                        for(i=0;i<4;i=i+1)begin
                            if(!PhyReg_Valid_Bank[i][j]&&PhyReg_WarpID_Bank[i][j]==5)begin
                                PhyReg_Valid_Bank[i][j]<=!PhyReg_Valid_Bank[i][j];
                            end
                        end 
                        //release Mapping Table
                        if(PhyReg_Mapping_Table[5][j][5])begin
                            PhyReg_Mapping_Table[5][j][5]<=!PhyReg_Mapping_Table[5][j][5];
                        end 
                    end
                    //set the Warp_Release_Reg
                    if(Warp_Release_Reg[5])begin
                        Warp_Release_Reg[5]<=!Warp_Release_Reg[5];
                    end else if(ID_Warp_Release_RAU[5])begin
                        Warp_Release_Reg[5]<=Warp_Release_Reg[5];
                    end
                end
                4'b1000:begin
                   for(j=0;j<8;j=j+1)begin
                        //release Free Physical Register list
                        for(i=0;i<4;i=i+1)begin
                            if(!PhyReg_Valid_Bank[i][j]&&PhyReg_WarpID_Bank[i][j]==7)begin
                                PhyReg_Valid_Bank[i][j]<=!PhyReg_Valid_Bank[i][j];
                            end
                        end 
                        //release Mapping Table
                        if(PhyReg_Mapping_Table[7][j][5])begin
                            PhyReg_Mapping_Table[7][j][5]<=!PhyReg_Mapping_Table[7][j][5];
                        end 
                    end
                    //set the Warp_Release_Reg
                    if(Warp_Release_Reg[7])begin
                        Warp_Release_Reg[7]<=!Warp_Release_Reg[7];
                    end else if(ID_Warp_Release_RAU[7])begin
                        Warp_Release_Reg[7]<=Warp_Release_Reg[7];
                    end
                end
            endcase
        end
    end
    ////////////////
    //Free Physical Register List Full signals
    wire [3:0] FRL_Empty;
    reg PhyReg_RunOut;//flag regsiter for inidating currently no free physical reg tag available
    //after this flag is on, if some phy tags are released, then we set the bank pointer to the bank which has a free tag
    //NOTE: a bug is caused when all physical regs are run out, then the bank pointer is pointed to a invalid bank
    //however, when some phytag is released, the bank pointers is still pointing to an invalid bank, which will cause problem
    assign FRL_Empty[0]=!(|PhyReg_Valid_Bank[0]);
    assign FRL_Empty[1]=!(|PhyReg_Valid_Bank[1]);
    assign FRL_Empty[2]=!(|PhyReg_Valid_Bank[2]);
    assign FRL_Empty[3]=!(|PhyReg_Valid_Bank[3]);
    //Warp_Bank_Ptr update logic, make it always points to a unfull bank
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            Warp_Bank_Ptr<=2'b00;
            PhyReg_RunOut<=1'b0;
        end else begin
            if(|IU_Grant&&Dst_Mapping_Unfound&&IB_Dst_Out_RAU[5])begin//a new physical register is allocated, then update the bank pointer
                case(Warp_Bank_Ptr)
                    2'b00:begin
                        if(!FRL_Empty[1])begin
                            Warp_Bank_Ptr<=Warp_Bank_Ptr+1;
                        end else if(!FRL_Empty[2])begin
                            Warp_Bank_Ptr<=Warp_Bank_Ptr+2;
                        end else if(!FRL_Empty[3])begin
                            Warp_Bank_Ptr<=Warp_Bank_Ptr+3;
                        end//if all other three banks are full, then keep the same value
                    end
                    2'b01:begin
                        if(!FRL_Empty[2])begin
                            Warp_Bank_Ptr<=Warp_Bank_Ptr+1;
                        end else if(!FRL_Empty[3])begin
                            Warp_Bank_Ptr<=Warp_Bank_Ptr+2;
                        end else if(!FRL_Empty[0])begin
                            Warp_Bank_Ptr<=Warp_Bank_Ptr+3;
                        end//if all other three banks are full, then keep the same value
                    end
                    2'b10:begin
                        if(!FRL_Empty[3])begin
                            Warp_Bank_Ptr<=Warp_Bank_Ptr+1;
                        end else if(!FRL_Empty[0])begin
                            Warp_Bank_Ptr<=Warp_Bank_Ptr+2;
                        end else if(!FRL_Empty[1])begin
                            Warp_Bank_Ptr<=Warp_Bank_Ptr+3;
                        end//if all other three banks are full, then keep the same value
                    end
                    2'b11:begin
                        if(!FRL_Empty[0])begin
                            Warp_Bank_Ptr<=Warp_Bank_Ptr+1;
                        end else if(!FRL_Empty[1])begin
                            Warp_Bank_Ptr<=Warp_Bank_Ptr+2;
                        end else if(!FRL_Empty[2])begin
                            Warp_Bank_Ptr<=Warp_Bank_Ptr+3;
                        end//if all other three banks are full, then keep the same value
                    end
                endcase
            end
            //////////////////
            //when all frl are empty, we set the flag to 1
            //when flag is one and one of the frl becomes non-empty, then we reset the flag and bank pointer
            if(&FRL_Empty&&!PhyReg_RunOut)begin
                PhyReg_RunOut<=!PhyReg_RunOut;
            end else if(PhyReg_RunOut&&!(&FRL_Empty))begin
                PhyReg_RunOut<=!PhyReg_RunOut;
                casez(FRL_Empty)
                    4'bzzz0:Warp_Bank_Ptr<=2'b00;
                    4'bzz01:Warp_Bank_Ptr<=2'b01;
                    4'bz011:Warp_Bank_Ptr<=2'b10;
                    4'b0111:Warp_Bank_Ptr<=2'b11;
                endcase
            end
        end
    end
    //update each warp's special register value
    wire [31:0] WS_ThreadID_Even_RAU={WS_WarpID_Even_RAU[28:0],3'b000};//warp id *8
    wire [31:0] WS_ThreadID_Odd_RAU={WS_WarpID_Odd_RAU[28:0],3'b000};
    always@(posedge clk)begin
        for(i=0;i<4;i=i+1)begin
            if(New_Scheduled_HW_WarpID[2*i])begin
                Logic_Reg8_ThreadID [2*i]<={WS_ThreadID_Even_RAU+7,WS_ThreadID_Even_RAU+6,WS_ThreadID_Even_RAU+5,WS_ThreadID_Even_RAU+4,WS_ThreadID_Even_RAU+3,WS_ThreadID_Even_RAU+2,WS_ThreadID_Even_RAU+1,WS_ThreadID_Even_RAU};
                Logic_Reg16_WarpID [2*i]<={8{WS_WarpID_Even_RAU}};
            end  
            if(New_Scheduled_HW_WarpID[2*i+1])begin
                Logic_Reg8_ThreadID [2*i+1]<={WS_ThreadID_Odd_RAU+7,WS_ThreadID_Odd_RAU+6,WS_ThreadID_Odd_RAU+5,WS_ThreadID_Odd_RAU+4,WS_ThreadID_Odd_RAU+3,WS_ThreadID_Odd_RAU+2,WS_ThreadID_Odd_RAU+1,WS_ThreadID_Odd_RAU};
                Logic_Reg16_WarpID [2*i+1]<={8{WS_WarpID_Odd_RAU}};
            end
        end
    end
    always @(*) begin
        if(IB_Src1_Out_RAU[4:0]==8)begin
            Src1_Reg8_16_Data=Logic_Reg8_ThreadID[0];
        end else begin
            Src1_Reg8_16_Data=Logic_Reg16_WarpID[0];
        end
        //
        if(IB_Src2_Out_RAU[4:0]==8)begin
            Src2_Reg8_16_Data=Logic_Reg8_ThreadID[0];
        end else begin
            Src2_Reg8_16_Data=Logic_Reg16_WarpID[0];
        end
        /////////////default assignment
        for(i=1;i<8;i=i+1)begin
            if(IU_Grant[i])begin
                if(IB_Src1_Out_RAU[4:0]==8)begin
                    Src1_Reg8_16_Data=Logic_Reg8_ThreadID[i];
                end else begin
                    Src1_Reg8_16_Data=Logic_Reg16_WarpID[i];
                end
                //
                if(IB_Src2_Out_RAU[4:0]==8)begin
                    Src2_Reg8_16_Data=Logic_Reg8_ThreadID[i];
                end else begin
                    Src2_Reg8_16_Data=Logic_Reg16_WarpID[i];
                end
            end
        end
    end
    ////////////////////////////////////////////
    //generating src1,src2 physical register address for RF
    always@(*)begin
        Src1_PhyRegAddr[5]='b0;
        Src1_PhyRegAddr[4:0]=Dst_PhyRegAddr;
        Src2_PhyRegAddr[5]='b0;
        Src2_PhyRegAddr[4:0]=Dst_PhyRegAddr;
        //default assignment
        //if the mapping table is still empty, then the first instruction of corresponding warp arrived at RAU must be xor $A $A $A
        //in this case, we assign the Dst_PhyRegAddr to each source phy register address signals
        if(|IU_Grant)begin
            if(IB_Src1_Out_RAU[5]&&IB_Src1_Out_RAU[4:0]!=8&&IB_Src1_Out_RAU[4:0]!=16)begin
                //if the source regsiter address is 8 or 16, then the RAU will directly provide the value in these regsiters, so we don't need to send request to RF
                Src1_PhyRegAddr[5]=1'b1;
                for(i=0;i<8;i=i+1)begin
                    if(IU_Grant[i])begin
                        //one the mapping table of a warp is not empty anymore, we will search the table to get the physical regsiter tag for instructions
                        //the assembly code has to obey this rule: before using a register as source, initialize it at first
                        if(PhyReg_Mapping_Table[i][0][5]||PhyReg_Mapping_Table[i][1][5]||PhyReg_Mapping_Table[i][2][5]||PhyReg_Mapping_Table[i][3][5]||PhyReg_Mapping_Table[i][4][5]||PhyReg_Mapping_Table[i][5][5]||PhyReg_Mapping_Table[i][6][5]||PhyReg_Mapping_Table[i][7][5])begin
                            Src1_PhyRegAddr[4:0]=PhyReg_Mapping_Table[i][IB_Src1_Out_RAU[4:0]][4:0];
                        end
                    end
                end
            end
            if(IB_Src2_Out_RAU[5]&&IB_Src2_Out_RAU[4:0]!=8&&IB_Src2_Out_RAU[4:0]!=16)begin
                Src2_PhyRegAddr[5]=1'b1;
                for(i=0;i<8;i=i+1)begin
                    if(IU_Grant[i])begin
                        if(PhyReg_Mapping_Table[i][0][5]||PhyReg_Mapping_Table[i][1][5]||PhyReg_Mapping_Table[i][2][5]||PhyReg_Mapping_Table[i][3][5]||PhyReg_Mapping_Table[i][4][5]||PhyReg_Mapping_Table[i][5][5]||PhyReg_Mapping_Table[i][6][5]||PhyReg_Mapping_Table[i][7][5])begin
                            Src2_PhyRegAddr[4:0]=PhyReg_Mapping_Table[i][IB_Src2_Out_RAU[4:0]][4:0];
                        end
                    end
                end
            end
        end
    end
    //////////////////////////
    //always block for generating the number of released physical tag during current clock
    reg [4:0] Released_Num_PhyReg_Even, Released_Num_PhyReg_Odd;//at most three warp can be released at the same time, so the maximum released phyreg number is 24
    always@(*)begin
        Release_Even_Warp=4'b0;
        Release_Odd_Warp=4'b0;
        //release which even warp
        casez({ID_Warp_Release_RAU[6]||Warp_Release_Reg[6],ID_Warp_Release_RAU[4]||Warp_Release_Reg[4],ID_Warp_Release_RAU[2]||Warp_Release_Reg[2],ID_Warp_Release_RAU[0]||Warp_Release_Reg[0]})
            4'bzzz1:Release_Even_Warp=4'b0001;
            4'bzz10:Release_Even_Warp=4'b0010;
            4'bz100:Release_Even_Warp=4'b0100;
            4'b1000:Release_Even_Warp=4'b1000;
        endcase
        //release which odd warp
        casez({ID_Warp_Release_RAU[7]||Warp_Release_Reg[7],ID_Warp_Release_RAU[5]||Warp_Release_Reg[5],ID_Warp_Release_RAU[3]||Warp_Release_Reg[3],ID_Warp_Release_RAU[1]||Warp_Release_Reg[1]})
            4'bzzz1:Release_Odd_Warp=4'b0001;
            4'bzz10:Release_Odd_Warp=4'b0010;
            4'bz100:Release_Odd_Warp=4'b0100;
            4'b1000:Release_Odd_Warp=4'b1000;
        endcase
        Released_Num_PhyReg_Even='b0;
        Released_Num_PhyReg_Odd='b0;
        //calculate the number of the released regsiters of a even warp
        case(Release_Even_Warp)
            4'b0001:begin
                for(i=0;i<8;i=i+1)begin
                    Released_Num_PhyReg_Even=PhyReg_Mapping_Table[0][i][5]+Released_Num_PhyReg_Even;
                end
            end
            4'b0010:begin
                for(i=0;i<8;i=i+1)begin
                    Released_Num_PhyReg_Even=PhyReg_Mapping_Table[2][i][5]+Released_Num_PhyReg_Even;
                end
            end
            4'b0100:begin
                for(i=0;i<8;i=i+1)begin
                    Released_Num_PhyReg_Even=PhyReg_Mapping_Table[4][i][5]+Released_Num_PhyReg_Even;
                end
            end
            4'b1000:begin
                for(i=0;i<8;i=i+1)begin
                    Released_Num_PhyReg_Even=PhyReg_Mapping_Table[6][i][5]+Released_Num_PhyReg_Even;
                end
            end
        endcase
        ////calculate the number of the released regsiters of a even warp
        case(Release_Odd_Warp)
            4'b0001:begin
                for(i=0;i<8;i=i+1)begin
                    Released_Num_PhyReg_Odd=PhyReg_Mapping_Table[1][i][5]+Released_Num_PhyReg_Odd;
                end
            end
            4'b0010:begin
                for(i=0;i<8;i=i+1)begin
                    Released_Num_PhyReg_Odd=PhyReg_Mapping_Table[3][i][5]+Released_Num_PhyReg_Odd;
                end
            end
            4'b0100:begin
                for(i=0;i<8;i=i+1)begin
                    Released_Num_PhyReg_Odd=PhyReg_Mapping_Table[5][i][5]+Released_Num_PhyReg_Odd;
                end
            end
            4'b1000:begin
                for(i=0;i<8;i=i+1)begin
                    Released_Num_PhyReg_Odd=PhyReg_Mapping_Table[7][i][5]+Released_Num_PhyReg_Odd;
                end
            end
        endcase
    end
    //always block for generating the number of left available registers in RAU
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            Num_Of_AviReg<=6'd32;
        end else begin
            //since Released_Num_PhyReg signal is combinational, so we just neeed to care about if the ws currently is scheduling new sw warp
            //NOTE: remember to add the newly released physical register number to the total  number of available physical registers
            if(|New_Scheduled_HW_WarpID)begin
                Num_Of_AviReg<=Num_Of_AviReg-WS_New_AllocReg_Num+Released_Num_PhyReg_Even+Released_Num_PhyReg_Odd;
            end else begin
                Num_Of_AviReg<=Num_Of_AviReg+Released_Num_PhyReg_Even+Released_Num_PhyReg_Odd;
            end
               
        end
    end
endmodule
