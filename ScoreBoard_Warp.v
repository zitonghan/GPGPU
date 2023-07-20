`timescale 1ns/100ps
module ScoreBoard_Warp(
    input clk,
    input rst_n,
    //////////////////
    //interface with I_Buffer
    input [3:0] IB_Inst_Valid_SB,//indicate the validity of the instruction in each entry of IB
    input [5:0] IB_Src1_Entry0_SB,
    input [5:0] IB_Src1_Entry1_SB,
    input [5:0] IB_Src1_Entry2_SB,
    input [5:0] IB_Src1_Entry3_SB,
    input [5:0] IB_Src2_Entry0_SB,
    input [5:0] IB_Src2_Entry1_SB,
    input [5:0] IB_Src2_Entry2_SB,
    input [5:0] IB_Src2_Entry3_SB,//RAW 
    input [5:0] IB_Dst_Entry0_SB,//WAR, WAW
    input [5:0] IB_Dst_Entry1_SB,
    input [5:0] IB_Dst_Entry2_SB,
    input [5:0] IB_Dst_Entry3_SB,
    input [3:0] IB_Issued_SB,//notify which instruction will be issued at the next clock edge
    output reg [3:0] SB_Ready_Issue_IB,//to cut off the combinational path, when the instruction in IB are ready to issue, we first set the ready bit in IB to 1, then send request to issue unit
    //So the send request is sent from IB, not ScoreBoard
    //In this case multiple entry can be set to ready at the same time
    output SB_Full,
    ///////////////////////////
    //interface with OC
    output reg [1:0] SB_EntNum_OC,//when an instruction is issued to operand collector, it will be recorded into SB, and the entry number of this newly occupied entry will also be sent to the OC, 
    //when the isntruction comes out from the ALU, it can release the entry of SB according to this number
    /////////////////////////
    //interface with WB
    input WB_Release_SB,
    input [1:0] WB_Release_EntNum_SB
); 
    integer i,j;
    //since we hope to use the entry number to release the entry when the recorded instruction comes out from the ALU, so the contents in the SB cannot shift as the same as IB
    ////////////////////////////
    wire [5:0] IB_Src1_SB [3:0];
    wire [5:0] IB_Src2_SB [3:0];
    wire [5:0] IB_Dst_SB [3:0];
    assign IB_Src1_SB[0]=IB_Src1_Entry0_SB;
    assign IB_Src1_SB[1]=IB_Src1_Entry1_SB;
    assign IB_Src1_SB[2]=IB_Src1_Entry2_SB;
    assign IB_Src1_SB[3]=IB_Src1_Entry3_SB;
    assign IB_Src2_SB[0]=IB_Src2_Entry0_SB;
    assign IB_Src2_SB[1]=IB_Src2_Entry1_SB;
    assign IB_Src2_SB[2]=IB_Src2_Entry2_SB;
    assign IB_Src2_SB[3]=IB_Src2_Entry3_SB;
    assign IB_Dst_SB[0]=IB_Dst_Entry0_SB;
    assign IB_Dst_SB[1]=IB_Dst_Entry1_SB;
    assign IB_Dst_SB[2]=IB_Dst_Entry2_SB;
    assign IB_Dst_SB[3]=IB_Dst_Entry3_SB;
    ////////////////////////////
    reg [3:0] SB_Valid;
    reg [5:0] SB_Src1_reg [3:0];
    reg [5:0] SB_Src2_reg [3:0];
    reg [5:0] SB_Dst_reg [3:0];
    ///////////////////////////////
    assign SB_Full=&SB_Valid;//even if currently a release signal is sent from WB stage, the FULL signal will keep 1 during this clock, and goes to 0 after the next clock edge
    ///////////////////////////////
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            SB_Valid<='b0;
            for(i=0;i<4;i=i+1)begin
                SB_Src1_reg [i]<='bx;
                SB_Src2_reg [i]<='bx;
                SB_Dst_reg [i]<='bx;
            end
        end else begin
            //release a occupied entry
            if(WB_Release_SB)begin
                SB_Valid[WB_Release_EntNum_SB]<=!SB_Valid[WB_Release_EntNum_SB];
            end
            ////////////////////
            //record new instruction in SB
            case(IB_Issued_SB)
                4'b0001:begin
                    SB_Valid[SB_EntNum_OC]<=!SB_Valid[SB_EntNum_OC];
                    SB_Src1_reg [SB_EntNum_OC]<=IB_Src1_SB[0];
                    SB_Src2_reg [SB_EntNum_OC]<=IB_Src2_SB[0];
                    SB_Dst_reg [SB_EntNum_OC]<=IB_Dst_SB[0];
                end
                4'b0010:begin
                    SB_Valid[SB_EntNum_OC]<=!SB_Valid[SB_EntNum_OC];
                    SB_Src1_reg [SB_EntNum_OC]<=IB_Src1_SB[1];
                    SB_Src2_reg [SB_EntNum_OC]<=IB_Src2_SB[1];
                    SB_Dst_reg [SB_EntNum_OC]<=IB_Dst_SB[1];
                end
                4'b0100:begin
                    SB_Valid[SB_EntNum_OC]<=!SB_Valid[SB_EntNum_OC];
                    SB_Src1_reg [SB_EntNum_OC]<=IB_Src1_SB[2];
                    SB_Src2_reg [SB_EntNum_OC]<=IB_Src2_SB[2];
                    SB_Dst_reg [SB_EntNum_OC]<=IB_Dst_SB[2];
                end
                4'b1000:begin
                    SB_Valid[SB_EntNum_OC]<=!SB_Valid[SB_EntNum_OC];
                    SB_Src1_reg [SB_EntNum_OC]<=IB_Src1_SB[3];
                    SB_Src2_reg [SB_EntNum_OC]<=IB_Src2_SB[3];
                    SB_Dst_reg [SB_EntNum_OC]<=IB_Dst_SB[3];
                end
            endcase
        end
    end
    /////////////////////////////////////
    //always block generating SB_EntNum_OC
    always@(*)begin
        casez(SB_Valid)
            4'bzz01:SB_EntNum_OC=2'b01;
            4'bz011:SB_EntNum_OC=2'b10;
            4'b0111:SB_EntNum_OC=2'b11;
            default:SB_EntNum_OC=2'b00;//default assignment 
            //once the IB issued an instruction to OC, the OC accepts the entry number sent from SB
        endcase
    end
    /////////////////////////////////////
    //combinational logic to check potential RAW, WAW, WAR hazards and generate send
    always@(*)begin
        SB_Ready_Issue_IB=4'b1111;
        //for evaluate IB entry 0-3
        //the hazard check between the isntructions in SB and IB
        for(j=0;j<4;j=j+1)begin
            if(IB_Inst_Valid_SB[j])begin//IB entry0-3
                for(i=0;i<4;i=i+1)begin//SB entry 0-3
                    if(SB_Valid[i])begin
                        if(SB_Dst_reg[i][5])begin
                            //RAW
                            if(IB_Src1_SB[j][5]&&IB_Src1_SB[j][4:0]==SB_Dst_reg[i][4:0]||IB_Src2_SB[j][5]&&IB_Src2_SB[j][4:0]==SB_Dst_reg[i][4:0])begin
                                SB_Ready_Issue_IB[j]=1'b0;
                            end
                            //WAW
                            if(IB_Dst_SB[j][5]&&IB_Dst_SB[j][4:0]==SB_Dst_reg[i][4:0])begin
                                SB_Ready_Issue_IB[j]=1'b0;
                            end
                        end
                        //WAR
                        if(IB_Dst_SB[j][5])begin
                            if(IB_Dst_SB[j][4:0]==SB_Src1_reg[i][4:0]&&SB_Src1_reg[i][5]||IB_Dst_SB[j][4:0]==SB_Src2_reg[i][4:0]&&SB_Src2_reg[i][5])begin
                                SB_Ready_Issue_IB[j]=1'b0;
                            end
                        end
                    end 
                end
            end
        end
        //NOTE: one thing need to note is that besides the potential hazard between the instructions in IB and the instructions being processing,
        //we also have to the check the data dependency between the instructions in IB
        //entry0 don't need this check, since it is the most senior instruction in IB
        //entry1 checks entry0
        //entry2->entry0 1
        //entry3->entry0 1 2
        for(j=1;j<4;j=j+1)begin
            for(i=0;i<j;i=i+1)begin
                if(IB_Inst_Valid_SB[j]&&IB_Inst_Valid_SB[i])begin
                    if(IB_Dst_SB[i][5])begin
                        //RAW
                        if(IB_Src1_SB[j][5]&&IB_Src1_SB[j][4:0]==IB_Dst_SB[i][4:0]||IB_Src2_SB[j][5]&&IB_Src2_SB[j][4:0]==IB_Dst_SB[i][4:0])begin
                            SB_Ready_Issue_IB[j]=1'b0;
                        end
                        //WAW
                        if(IB_Dst_SB[j][5]&&IB_Dst_SB[j][4:0]==IB_Dst_SB[i][4:0])begin
                            SB_Ready_Issue_IB[j]=1'b0;
                        end
                    end
                    //WAR
                    if(IB_Dst_SB[j][5])begin
                        if(IB_Dst_SB[j][4:0]==IB_Src1_SB[i][4:0]&&IB_Src1_SB[i][5]||IB_Dst_SB[j][4:0]==IB_Src2_SB[i][4:0]&&IB_Src2_SB[i][5])begin
                            SB_Ready_Issue_IB[j]=1'b0;
                        end
                    end
                end
            end
        end
    end
endmodule 