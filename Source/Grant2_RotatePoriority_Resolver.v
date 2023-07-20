`timescale 1ns/100ps
module Rotate_Priority_2Grant #(
    parameter NumOfWarp=8
)(
    input clk,
    input rst_n,
    input [NumOfWarp-1:0] Icache_Fetch_Request,
    output reg [NumOfWarp-1:0] Grant1,
    output reg [NumOfWarp-1:0] Grant2
);
    //this module is used to accept two inctruction fetch  requests from all current processing warps, and select two of them
    //so every time two warps will be granted to access the instruction cache
    reg [NumOfWarp-1:0] Request_after_rotate;
    reg [NumOfWarp-1:0] RotateRequest_for_2ndGrant;
    reg [NumOfWarp-1:0] Grant1_after_Rotate, Grant2_after_Rotate;
    reg [NumOfWarp-1:0] Most_Recent_Grant;
    always@(*)begin
        case(Most_Recent_Grant)
            8'b0000_0001:Request_after_rotate={Icache_Fetch_Request[0],Icache_Fetch_Request[7:1]};
            8'b0000_0010:Request_after_rotate={Icache_Fetch_Request[1:0],Icache_Fetch_Request[7:2]};
            8'b0000_0100:Request_after_rotate={Icache_Fetch_Request[2:0],Icache_Fetch_Request[7:3]};
            8'b0000_1000:Request_after_rotate={Icache_Fetch_Request[3:0],Icache_Fetch_Request[7:4]};
            8'b0001_0000:Request_after_rotate={Icache_Fetch_Request[4:0],Icache_Fetch_Request[7:5]};
            8'b0010_0000:Request_after_rotate={Icache_Fetch_Request[5:0],Icache_Fetch_Request[7:6]};
            8'b0100_0000:Request_after_rotate={Icache_Fetch_Request[6:0],Icache_Fetch_Request[7]};
            default:Request_after_rotate=Icache_Fetch_Request;//the requset[0] has the highest priority
        endcase
        ///////////////////////////////
        //generate Grant1
        casez(Request_after_rotate)
            8'bzzzz_zzz1:Grant1_after_Rotate=8'b0000_0001;
            8'bzzzz_zz10:Grant1_after_Rotate=8'b0000_0010;
            8'bzzzz_z100:Grant1_after_Rotate=8'b0000_0100;
            8'bzzzz_1000:Grant1_after_Rotate=8'b0000_1000;
            8'bzzz1_0000:Grant1_after_Rotate=8'b0001_0000;
            8'bzz10_0000:Grant1_after_Rotate=8'b0010_0000;
            8'bz100_0000:Grant1_after_Rotate=8'b0100_0000;
            8'b1000_0000:Grant1_after_Rotate=8'b1000_0000;
            default:Grant1_after_Rotate=8'b0000_0000;
        endcase
        RotateRequest_for_2ndGrant=Request_after_rotate&(~Grant1_after_Rotate);//if the request has been granted in the first stage, then its request will be reset to 0
        //generate the second grant
        casez(RotateRequest_for_2ndGrant)
            8'bzzzz_zzz1:Grant2_after_Rotate=8'b0000_0001;
            8'bzzzz_zz10:Grant2_after_Rotate=8'b0000_0010;
            8'bzzzz_z100:Grant2_after_Rotate=8'b0000_0100;
            8'bzzzz_1000:Grant2_after_Rotate=8'b0000_1000;
            8'bzzz1_0000:Grant2_after_Rotate=8'b0001_0000;
            8'bzz10_0000:Grant2_after_Rotate=8'b0010_0000;
            8'bz100_0000:Grant2_after_Rotate=8'b0100_0000;
            8'b1000_0000:Grant2_after_Rotate=8'b1000_0000;
            default:Grant2_after_Rotate=8'b0000_0000;
        endcase
        /////////////////////////////////////////
        //recover the order of the generated grant to that before rotating
        case(Most_Recent_Grant)
            8'b0000_0001:begin
                Grant1={Grant1_after_Rotate[6:0],Grant1_after_Rotate[7]};
                Grant2={Grant2_after_Rotate[6:0],Grant2_after_Rotate[7]};
            end
            8'b0000_0010:begin
                Grant1={Grant1_after_Rotate[5:0],Grant1_after_Rotate[7:6]};
                Grant2={Grant2_after_Rotate[5:0],Grant2_after_Rotate[7:6]};
            end
            8'b0000_0100:begin
                Grant1={Grant1_after_Rotate[4:0],Grant1_after_Rotate[7:5]};
                Grant2={Grant2_after_Rotate[4:0],Grant2_after_Rotate[7:5]};
            end
            8'b0000_1000:begin
                Grant1={Grant1_after_Rotate[3:0],Grant1_after_Rotate[7:4]};
                Grant2={Grant2_after_Rotate[3:0],Grant2_after_Rotate[7:4]};
            end
            8'b0001_0000:begin
                Grant1={Grant1_after_Rotate[2:0],Grant1_after_Rotate[7:3]};
                Grant2={Grant2_after_Rotate[2:0],Grant2_after_Rotate[7:3]};
            end
            8'b0010_0000:begin
                Grant1={Grant1_after_Rotate[1:0],Grant1_after_Rotate[7:2]};
                Grant2={Grant2_after_Rotate[1:0],Grant2_after_Rotate[7:2]};
            end
            8'b0100_0000:begin
                Grant1={Grant1_after_Rotate[0],Grant1_after_Rotate[7:1]};
                Grant2={Grant2_after_Rotate[0],Grant2_after_Rotate[7:1]};
            end
            default:begin 
                Grant1=Grant1_after_Rotate;
                Grant2=Grant2_after_Rotate;
            end
        endcase
    end
    //////////////////////////////////////
    //update the most recent grant register
    //synchronous reset
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)begin
            Most_Recent_Grant<=8'b1000_0000;
        end else begin
            if(|Grant1&&|Grant2)begin
                Most_Recent_Grant<=Grant2;
            end else if(|Grant1) begin
                Most_Recent_Grant<=Grant1;
            end//otherwise the most recent grant keep the same
        end
    end

endmodule
