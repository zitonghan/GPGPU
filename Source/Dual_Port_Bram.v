module Dual_Port_Bram #(
    parameter WIDTH=32,
              DEPTH=10,
              Test="16x16_Matrix_Multiply"
              
)(
    input clka,
    input wena,
    input [DEPTH-1:0] addra,
    input [WIDTH-1:0] dina,
    output reg [WIDTH-1:0] douta,
    //
    input clkb,
    input [DEPTH-1:0]addrb,
    input [WIDTH-1:0]dinb,
    output reg [WIDTH-1:0]doutb
);
    (* ram_style="block" *) reg [WIDTH-1:0] mem [2**DEPTH-1:0];
    // initial begin
    //     if(Test=="16x16_Matrix_Multiply")begin
    //         $readmemh("ICache_init_matrix_multiply_16x16.mem",mem);
    //     end else if(Test=="16x16_Draw_Circle")begin
    //         $readmemh("ICache_init_circle_drawing_16x16.mem",mem);
    //     end
        
    // end
    reg [DEPTH-1:0] Addr_a_in, Addr_b_in;
    //
    always@(posedge clka)begin
        douta<=mem[Addr_a_in];
        Addr_a_in<=addra;
        if(wena)begin
            mem[addra]<=dina;
            Addr_a_in<=addra;
        end
    end
    //////////////
    //port b
    always@(posedge clkb)begin
        Addr_b_in<=addrb;
        doutb<=mem[Addr_b_in];
    end
endmodule
