module Uart_Bram #(
    parameter DATA_WIDTH=32,
              MEM_DEPTH=64
)(
    input clk,
    input we,
    input [DATA_WIDTH-1:0] din,//write data in
    input [$clog2(MEM_DEPTH)-1:0] addra,//port for write
    input [$clog2(MEM_DEPTH)-1:0] addrb,//port for read
    output reg [DATA_WIDTH-1:0] dout//read out port output regitered
);
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] MEM [MEM_DEPTH-1:0];
    always @(posedge clk) begin
        if(we)begin
           MEM[addra]<=din; 
        end    
        dout<=MEM[addrb];
    end

endmodule