`timescale 1ns/100ps
module Single_Port_BRAM #(
    parameter ADDR_WIDTH=3,
              DATA_WIDTH=32,
              NO_WORD=0,
              MEM_TYPE="RF"
)(
    input clk,
    input we,
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout
);
    (* ram_style="block" *) reg [DATA_WIDTH-1:0] mem [2**ADDR_WIDTH-1:0];
    //
    integer i;
    initial begin
       if(MEM_TYPE=="RF")begin
            for(i=0;i<2**ADDR_WIDTH;i=i+1)begin
                mem[i]=i;
            end
        end 
        // else if (MEM_TYPE=="DC") begin
        //     case(NO_WORD)
        //         0:$readmemh("MEM_init_word0.mem", mem);
        //         1:$readmemh("MEM_init_word1.mem", mem);
        //         2:$readmemh("MEM_init_word2.mem", mem);
        //         3:$readmemh("MEM_init_word3.mem", mem);
        //         4:$readmemh("MEM_init_word4.mem", mem);
        //         5:$readmemh("MEM_init_word5.mem", mem);
        //         6:$readmemh("MEM_init_word6.mem", mem);
        //         7:$readmemh("MEM_init_word7.mem", mem);
        //     endcase
        // end 
    end
    ////////
    //output registered bram single port
    always @(posedge clk) begin
        dout<=mem[addr];
        if(we)begin
            mem[addr]<=din;
            dout<=din;
        end
    end
endmodule