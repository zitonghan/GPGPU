`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/03/2014 01:41:13 AM
// Module Name: receive_file
// Description: This module is for receiving file from the UART port. It has a FIFO integrated inside and the outside 
//                  read information from the FIFO. This module also provides the register location and content to the outside.
//                  Furthermore, ACK signal during the receiving process is also handled in this module. 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module receive_file(
    output reg [3:0]     state,     // for debug
    // clk and reset
    input             clk,         // Clock input
    input             reset,     // Active HIGH reset - synchronous to clk_rx
    
    // communication with rx module
    input      [7:0]  rx_data,        // Character to be parsed
    input             rx_data_rdy,    // Ready signal for rx_data
    output            rx_read_en,       // pop entry in rx fifo
    
    // communication with tx module
    input               tx_fifo_full,     // the tx fifo is full
    output [7:0]        tx_din,         // data to be sent
    output              tx_write_en,          // write enable to tx         
    
    // communication with user
    output [7:0]        receive_fifo_dout,      // data output of the fifo
    output              receive_data_rdy,         // there is data ready at the output fifo
    input               receive_fifo_re,            // pop entry in the receive fifo
    
    // register information
    output reg [7:0]       reg_addr,       // register address of the specifier
    output reg [7:0]       reg_pointer,    // content of the specifier
    output reg             reg_ready      // indication when the reg data is available. It's available only 
                                        // after both the address and the content is ready.
    );
    
wire output_fifo_we;        // to write into the output fifo
wire output_fifo_empty;
wire output_fifo_full;                         // the output fifo is full

// the output fifo that is seen by the user
data_fifo_oneclk input_fifo(
    .din        (rx_data),          // we only write to the output fifo the data received from the rx module
    .clk        (clk),
    .rst        (reset),
    .wr_en      (output_fifo_we),
    .rd_en      (receive_fifo_re),
    .dout       (receive_fifo_dout),
    .empty      (output_fifo_empty),
    .full       (output_fifo_full)
);
    
localparam
    ACK = 8'h06,
    SOH = 8'h01,
    EOT = 8'h03,
    SOT = 8'h02,
    EOM = 8'h19,
    CR = 8'h0d,
    LF = 8'h0a,
    EOF = 8'h04;

localparam
    IDLE = 4'b0000,
    SEND_ACK_SOH = 4'b0001,
    RECEIVE_REG = 4'b0010,
    WAIT_EOT_ACK = 4'b0011,
    SEND_ACK_EOT = 4'b0100,
    WAIT_SOT_ACK = 4'b0101,
    SEND_ACK_SOT = 4'b0110,
    RECEIVE_CONT = 4'b0111,
    SEND_ACK_EOF = 4'b1000,
    DONE = 4'b1001;
        
// This function takes the lower 7 bits of a character and converts them
// to a hex digit. It returns 5 bits - the upper bit is set if the character
// is not a valid hex digit (i.e. is not 0-9,a-f, A-F), and the remaining
// 4 bits are the digit
function [4:0] to_val;
    input [6:0] char;
    begin
        if ((char >= 7'h30) && (char <= 7'h39)) // 0-9
        begin
            to_val[4]   = 1'b0;
            to_val[3:0] = char[3:0];
        end
        else if (((char >= 7'h41) && (char <= 7'h46)) || // A-F
            ((char >= 7'h61) && (char <= 7'h66)) )  // a-f
        begin
            to_val[4]   = 1'b0;
            to_val[3:0] = char[3:0] + 4'h9; // gives 10 - 15
        end
        else 
        begin
            to_val      = 5'b1_0000;
        end
    end
endfunction
        
wire [4:0]  char_to_digit = to_val(rx_data);
// reg [3:0] state;
reg [1:0] cnt;

// combinational output
assign receive_data_rdy = ~output_fifo_empty;     // the output fifo is empty
assign rx_read_en = ((state == IDLE || state == RECEIVE_REG || state == WAIT_EOT_ACK || state == WAIT_SOT_ACK ) && 
                    rx_data_rdy) || (output_fifo_we) ;      // pop out entry from rx fifo under 2 cases: 
                                                            // when we are waiting for certain signals or we are writing to the output fifo
                                                            
assign tx_din = ACK;        // the only thing to send is ACK signal
assign tx_write_en = (state == SEND_ACK_SOH || state == SEND_ACK_EOT || state == SEND_ACK_SOT || state == SEND_ACK_EOF) && 
                        (~tx_fifo_full);
                        
assign output_fifo_we = (state == WAIT_SOT_ACK || state == RECEIVE_CONT) && (~output_fifo_full) && rx_data_rdy;    // the received data from the user include SOT and EOF signal

always @ (posedge clk)
begin
    if (reg_ready) reg_ready <= 1'b0;       // make it 1-clock wide
    
    if (reset)
    begin
        state <= IDLE;
        cnt <= 0;
        reg_ready <= 1'b0;
    end
    else
    case (state)
    IDLE: 
        if (rx_data_rdy && rx_data == SOH) 
            state <= SEND_ACK_SOH;
    SEND_ACK_SOH:
        if (~tx_fifo_full)
        begin
            state <= RECEIVE_REG;
        end
    RECEIVE_REG:
    begin
        if (rx_data_rdy)
        begin
            case (cnt)
                2'b00: reg_addr[7:4] <= char_to_digit[3:0];
                2'b01: reg_addr[3:0] <= char_to_digit[3:0];
                2'b10: reg_pointer[7:4] <= char_to_digit[3:0];
                2'b11: 
                begin
                    reg_pointer[3:0] <= char_to_digit[3:0];
                    state <= WAIT_EOT_ACK;
                    reg_ready <= 1'b1;
                end
            endcase
            cnt <= cnt+1;
        end
    end
    WAIT_EOT_ACK:
        if (rx_data_rdy && rx_data == EOT) 
            state <= SEND_ACK_EOT;
    SEND_ACK_EOT:
        if (~tx_fifo_full)
        begin
            state <= WAIT_SOT_ACK;
        end
    WAIT_SOT_ACK:
        if (rx_data_rdy && rx_data == SOT) 
            state <= SEND_ACK_SOT;     
    SEND_ACK_SOT:
        if (~tx_fifo_full)
        begin
            state <= RECEIVE_CONT;
        end
    RECEIVE_CONT:
        if (rx_data_rdy && rx_data == EOF)
            state <= SEND_ACK_EOF;
    SEND_ACK_EOF:
        if (~tx_fifo_full)
        begin
            state <= DONE;
        end    
    DONE:   
        state <= IDLE;
    endcase
end
endmodule
