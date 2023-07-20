`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/04/2014 11:27:23 PM
// Design Name: 
// Module Name: send_file
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module send_file(
    // for debug
    output reg [3:0]    state,
    // clock and reset
    input           clk,
    input           reset,
    // communication with user
    input           start_send,     // start signal
    input [7:0]     send_fifo_din,    // data input to the input fifo
    input           send_fifo_we,           //write enable to the input fifo
    output          send_fifo_full,         // input fifo is full
    output          finish_send ,           // send finishes
    
    // communication with tx fifo
    input           tx_fifo_full,           // tx fifo is full
    output [7:0]    tx_fifo_din,            // send data to the tx fifo
    output          tx_fifo_we,             // write enable to tx fifo
    
    // communication with rx module
    input [7:0]     rx_data,        // Character to be parsed
    input           rx_data_rdy,    // Ready signal for rx_data
    output          rx_read_en      // Pop entry from rx fifo
    );
    
    // data declearation
    wire        input_fifo_re;      // pop entry from input fifo
    //wire [7:0]  input_fifo_dout;    // data output from input fifo
    wire        input_fifo_empty;
    // reg [3:0]   state;
    
    
    // the input fifo for storing output data
    data_fifo_oneclk input_fifo(
        .din        (send_fifo_din),
        .clk        (clk),
        .rst        (reset),
        .wr_en      (send_fifo_we),
        .rd_en      (input_fifo_re),
        .dout       (tx_fifo_din),
        .empty      (input_fifo_empty),
        .full       (send_fifo_full)
    );
    // state definition

    localparam 
        IDLE = 4'b0000,
        SEND_SOH = 4'b0001,
        WAIT_ACK_SOH = 4'b0010,
        SEND_EOT = 4'b0011,
        WAIT_ACK_EOT = 4'b0100,
        SEND_SOT = 4'b0101,
        WAIT_ACK_SOT = 4'b0110,
        SEND_CONTENT = 4'b0111,
        WAIT_ACK_EOM = 4'b1000,
        SEND_EOF = 4'b1001,
        WAIT_ACK_EOF = 4'b1010,
        DONE = 4'b1011;
        
    localparam
        ACK = 8'h06,
        SOH = 8'h01,
        EOT = 8'h03,
        SOT = 8'h02,
        EOM = 8'h19,
        CR = 8'h0d,
        LF = 8'h0a,
        EOF = 8'h04;
        
    // combinational output
    assign finish_send = (state == DONE);
    assign tx_fifo_we = (state == SEND_SOH || state == SEND_EOT || state == SEND_SOT || state == SEND_CONTENT) &&
                        (~input_fifo_empty) && (~tx_fifo_full);
    assign input_fifo_re = tx_fifo_we;
    assign rx_read_en = (state == WAIT_ACK_SOH || state == WAIT_ACK_EOT ||state == WAIT_ACK_SOT ||state == WAIT_ACK_EOM ||state == WAIT_ACK_EOF) &&
                        (rx_data_rdy);
        
    /**************state machine****************/
    always @ (posedge clk)
    begin
        if (reset)
        begin
            state <= IDLE;
        end
        else
        case (state)
            IDLE:
            begin
                if (start_send)
                    state <= SEND_SOH;
            end
            SEND_SOH :
            begin
                if ((tx_fifo_din == SOH) & (tx_fifo_we))  // the SOH has been sent out
                    state <= WAIT_ACK_SOH;
            end
            WAIT_ACK_SOH :
            begin
                if (rx_data_rdy & rx_data == ACK) 
                    state <= SEND_EOT;
            end
            SEND_EOT :
            begin
                if ((tx_fifo_din == EOT) & (tx_fifo_we))  
                    state <= WAIT_ACK_EOT;
            end
            WAIT_ACK_EOT :
            begin
                if (rx_data_rdy & rx_data == ACK) 
                    state <= SEND_SOT;
            end
            SEND_SOT :
            begin
                if ((tx_fifo_din == SOT) & (tx_fifo_we))  
                    state <= WAIT_ACK_SOT;
            end
            WAIT_ACK_SOT :
            begin
                if (rx_data_rdy & rx_data == ACK) 
                    state <= SEND_CONTENT;
            end
            SEND_CONTENT :
            begin
                if ((tx_fifo_din == EOF) & (tx_fifo_we))     // the EOF has been sent out
                    state <= WAIT_ACK_EOF;
            end
            //WAIT_ACK_EOM :
            //SEND_EOF :      // this state becomes useless as the transmission of EOF is done in SEND_CONTENT state
            WAIT_ACK_EOF :
            begin
                if (rx_data_rdy & rx_data == ACK) 
                    state <= DONE;
            end
            DONE : 
            begin
                state <= IDLE;
            end
        endcase
        
    end // always
    
    
endmodule
