`timescale 1ns/100ps
module EX_Issue_Unit(
    input clk,
    input rst_n,
    //interface with OC
    input [3:0] OC_IssReq_EX_IU,
    output [3:0] EX_IU_Grant,//registered grant
    //interface with LD/ST
    input MSHR_Done//if this signal is one, then don't give grant for any entries of OC
);
    ////////////////////////
    reg [3:0] IU_Most_Recent_Grant, Last_IU_Most_Recent_Grant;//register
    //NOTE: if currently a grant_int is generated, the most recent grant register will be updated, however, if next cycle mshr_done is 1, it means this output grant is
    //not used, which means last cycle, the most recent grant should not be updated, the prioriy is not used yet
    //so we set another register called last most recent. if current mshr_done is 1, we use last most recent grant to determine the priority of current request
    //however, if current mshr_done is 1 and no grant_int is generated, then the last most_recent grant should be send back to most recent grant register, since the priority is still not 
    //used yet and mshr_done can be activated only for one clock, so next cycle, mshr_done is zero, the priotity is selected from the most_recent grant
    wire [3:0] IU_Most_Recent_Grant_Muxed=MSHR_Done?Last_IU_Most_Recent_Grant:IU_Most_Recent_Grant;//use a mux,which is controlled by mshr_done, to select one from IU_Most_Recent_Grant and last IU_Most_Recent_Grant
    reg [3:0] Request_After_Rotate;
    reg [3:0] Grant_After_Rotate;
    reg [3:0] EX_IU_Grant_int;//combinatinal grant
    reg [3:0] EX_IU_Grant_raw;//registered ragnt before combining with MSHR_Done
    wire [3:0] Grant_Masked_Request=~(EX_IU_Grant)&OC_IssReq_EX_IU;
    //since the grant is delayed by one clock, if current a grant is given to a OC entry, then this entry should not send another request to the issue unit
    ///////////////////////////////////////
    always@(*)begin
        EX_IU_Grant_int='b0;
            case(IU_Most_Recent_Grant_Muxed)
                4'b0001:Request_After_Rotate={Grant_Masked_Request[0],Grant_Masked_Request[3:1]};
                4'b0010:Request_After_Rotate={Grant_Masked_Request[1:0],Grant_Masked_Request[3:2]};
                4'b0100:Request_After_Rotate={Grant_Masked_Request[2:0],Grant_Masked_Request[3]};
                default:Request_After_Rotate=Grant_Masked_Request;
            endcase
            ///////////////////
            casez(Request_After_Rotate)
                4'bzzz1:Grant_After_Rotate=4'b0001;
                4'bzz10:Grant_After_Rotate=4'b0010;
                4'bz100:Grant_After_Rotate=4'b0100;
                4'b1000:Grant_After_Rotate=4'b1000;
                default:Grant_After_Rotate=4'b0000;
            endcase
            ////////////////////
            case(IU_Most_Recent_Grant_Muxed)
                4'b0001:EX_IU_Grant_int={Grant_After_Rotate[2:0],Grant_After_Rotate[3]};
                4'b0010:EX_IU_Grant_int={Grant_After_Rotate[1:0],Grant_After_Rotate[3:2]};
                4'b0100:EX_IU_Grant_int={Grant_After_Rotate[0],Grant_After_Rotate[3:1]};
                default:EX_IU_Grant_int=Grant_After_Rotate;
            endcase 
    end
    ///////////////////////////////////////
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            IU_Most_Recent_Grant<=4'b1000;
            Last_IU_Most_Recent_Grant<='bx;
            EX_IU_Grant_raw<='b0;
        end else begin
            EX_IU_Grant_raw<=EX_IU_Grant_int;
            Last_IU_Most_Recent_Grant<=IU_Most_Recent_Grant;
            if(|EX_IU_Grant_int)begin
                IU_Most_Recent_Grant<=EX_IU_Grant_int;
            end else if(!(|EX_IU_Grant_int)&&MSHR_Done) begin
                IU_Most_Recent_Grant<= Last_IU_Most_Recent_Grant;
            end
        end
    end
    assign EX_IU_Grant=EX_IU_Grant_raw&{4{!MSHR_Done}};
endmodule
