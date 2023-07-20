`timescale 1ns/100ps
module Issue_Unit(
    input clk,
    input rst_n,
    input [7:0] IB_Ready_Issue_IU,
    input OC_Full,//operand collector full signal
    output [7:0] IU_Grant
);
    ////////////////////////
    reg [7:0] IU_Most_Recent_Grant, Last_IU_Most_Recent_Grant;
    reg [7:0] Request_After_Rotate;
    reg [7:0] Grant_After_Rotate;
    reg [7:0] IU_Grant_Raw;//combinatinal grant in front of the output regsiter
    wire [7:0] Request_after_Masked=IB_Ready_Issue_IU&(~IU_Grant);
    reg [7:0] Grant_before_Masked;
    wire [7:0] Most_Recent_Grant_Muxed=OC_Full?Last_IU_Most_Recent_Grant:IU_Most_Recent_Grant;
    ///////////////////////////////////////
    assign IU_Grant=Grant_before_Masked&{8{!OC_Full}};
    always@(*)begin
        IU_Grant_Raw='b0;
            case(IU_Most_Recent_Grant)
                8'b0000_0001:Request_After_Rotate={Request_after_Masked[0],Request_after_Masked[7:1]};
                8'b0000_0010:Request_After_Rotate={Request_after_Masked[1:0],Request_after_Masked[7:2]};
                8'b0000_0100:Request_After_Rotate={Request_after_Masked[2:0],Request_after_Masked[7:3]};
                8'b0000_1000:Request_After_Rotate={Request_after_Masked[3:0],Request_after_Masked[7:4]};
                8'b0001_0000:Request_After_Rotate={Request_after_Masked[4:0],Request_after_Masked[7:5]};
                8'b0010_0000:Request_After_Rotate={Request_after_Masked[5:0],Request_after_Masked[7:6]};
                8'b0100_0000:Request_After_Rotate={Request_after_Masked[6:0],Request_after_Masked[7]};
                default:Request_After_Rotate=Request_after_Masked;
            endcase
            ///////////////////
            casez(Request_After_Rotate)
                8'bzzzz_zzz1:Grant_After_Rotate=8'b0000_0001;
                8'bzzzz_zz10:Grant_After_Rotate=8'b0000_0010;
                8'bzzzz_z100:Grant_After_Rotate=8'b0000_0100;
                8'bzzzz_1000:Grant_After_Rotate=8'b0000_1000;
                8'bzzz1_0000:Grant_After_Rotate=8'b0001_0000;
                8'bzz10_0000:Grant_After_Rotate=8'b0010_0000;
                8'bz100_0000:Grant_After_Rotate=8'b0100_0000;
                8'b1000_0000:Grant_After_Rotate=8'b1000_0000;
                default:Grant_After_Rotate=8'b0000_0000;
            endcase
            ////////////////////
            case(IU_Most_Recent_Grant)
                8'b0000_0001:IU_Grant_Raw={Grant_After_Rotate[6:0],Grant_After_Rotate[7]};
                8'b0000_0010:IU_Grant_Raw={Grant_After_Rotate[5:0],Grant_After_Rotate[7:6]};
                8'b0000_0100:IU_Grant_Raw={Grant_After_Rotate[4:0],Grant_After_Rotate[7:5]};
                8'b0000_1000:IU_Grant_Raw={Grant_After_Rotate[3:0],Grant_After_Rotate[7:4]};
                8'b0001_0000:IU_Grant_Raw={Grant_After_Rotate[2:0],Grant_After_Rotate[7:3]};
                8'b0010_0000:IU_Grant_Raw={Grant_After_Rotate[1:0],Grant_After_Rotate[7:2]};
                8'b0100_0000:IU_Grant_Raw={Grant_After_Rotate[0],Grant_After_Rotate[7:1]};
                default:IU_Grant_Raw=Grant_After_Rotate;
            endcase 
    end 
    ///////////////////////////////////////
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            IU_Most_Recent_Grant<=8'b1000_0000;
            Last_IU_Most_Recent_Grant<='bx;
            Grant_before_Masked<='b0;
        end else begin
            Grant_before_Masked<=IU_Grant_Raw;
            //NOTE:
            //not like the MSHR_Done, the OC_Full might be active for more than one clock,
            //if oc_full is one , we should not update the las iu grant value, so the next cycle, we still use the same most recent grant value to determine the priority
            if(!OC_Full)begin
                Last_IU_Most_Recent_Grant<=IU_Most_Recent_Grant;
            end
            //if OC is full, and a new raw grant is generated in front of the output register, then we can update the most recent grant
            //even if the next cycle the oc_full is still high, since we keep the last grant as the same, it doesn't matter
            //if the next cycle oc_full is low, then we can use the updated most recent grant to determine the grant for the next request
            if(|IU_Grant_Raw&&OC_Full)begin
                IU_Most_Recent_Grant<=IU_Grant_Raw;
            end else if(!(|IU_Grant_Raw)&&OC_Full)begin
                IU_Most_Recent_Grant<=Last_IU_Most_Recent_Grant;
            end
        end
    end
endmodule