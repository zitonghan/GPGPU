`timescale 1ns/100ps
module tb;
    reg clk;
    reg rst_n;
    wire LED0;

    GPGPU_TOP dut(
        .ClkIn(clk),
        .rst_pin(rst_n)
    );

    initial clk=0;
    always begin
        #5 clk=!clk;
    end
    initial begin
        rst_n=1'b1;
        @(posedge dut.clk);
        #2 rst_n=1'b0;
    end
    integer  i;
    initial begin
        #150000;//150us
        for(i=0;i<512;i=i+1)begin
            $write("%h",dut.alu_n_ld_st_n_wb.DC_Inst[7].Data_Cache.mem[i]);
            $write("%h",dut.alu_n_ld_st_n_wb.DC_Inst[6].Data_Cache.mem[i]);
            $write("%h",dut.alu_n_ld_st_n_wb.DC_Inst[5].Data_Cache.mem[i]);
            $write("%h",dut.alu_n_ld_st_n_wb.DC_Inst[4].Data_Cache.mem[i]);
            $write("%h",dut.alu_n_ld_st_n_wb.DC_Inst[3].Data_Cache.mem[i]);
            $write("%h",dut.alu_n_ld_st_n_wb.DC_Inst[2].Data_Cache.mem[i]);
            $write("%h",dut.alu_n_ld_st_n_wb.DC_Inst[1].Data_Cache.mem[i]);
            $write("%h",dut.alu_n_ld_st_n_wb.DC_Inst[0].Data_Cache.mem[i]);
            $write("\n");
        end
        $stop;
    end
    reg [5:0] count_warp=0;
    always@(posedge dut.clk)begin
        count_warp<=count_warp+(|dut.decode.IF_ID0_WarpID&&dut.decode.EXIT_ID0_WS)+(|dut.decode.IF_ID1_WarpID&&dut.decode.EXIT_ID1_WS);
    end
    initial $monitor("%d",count_warp);

endmodule
