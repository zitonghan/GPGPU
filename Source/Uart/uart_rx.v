//-----------------------------------------------------------------------------
//  
//  Copyright (c) 2009 Xilinx Inc.
//
//  Project  : Programmable Wave Generator
//  Module   : uart_rx.v
//  Parent   : wave_gen.v and uart_led.v
//  Children : uart_rx_ctl.v uart_baud_gen.v meta_harden.v
//
//  Description: 
//     Top level of the UART receiver.
//     Brings together the metastability hardener for synchronizing the 
//     rxd pin, the baudrate generator for generating the proper x16 bit
//     enable, and the controller for the UART itself.
//     
//
//  Parameters:
//     BAUD_RATE : Baud rate - set to 57,600bps by default
//     CLOCK_RATE: Clock rate - set to 50MHz by default
//
//  Local Parameters:
//
//  Notes       : 
//
//  Multicycle and False Paths
//     The uart_baud_gen module generates a 1-in-N pulse (where N is
//     determined by the baud rate and the system clock frequency), which
//     enables all flip-flops in the uart_rx_ctl module. Therefore, all paths
//     within uart_rx_ctl are multicycle paths, as long as N > 2 (which it
//     will be for all reasonable combinations of Baud rate and system
//     frequency).
//

`timescale 1ns/1ps


module uart_rx (
  // Write side inputs
  input            clk_rx,       // Clock input
  input            rst_clk_rx,   // Active HIGH reset - synchronous to clk_rx

  input            rxd_i,        // RS232 RXD pin - Directly from pad
  input            read_en,     // read enable of the internal fifo; pop out one entry from fifo
  
  output           rxd_clk_rx,   // RXD pin after synchronization to clk_rx

  output     [7:0] rx_data,      // 8 bit data output from the fifo
  output           rx_data_rdy,  // Ready signal for rx_data
  output           rx_data_rdy_reg,
  output           frm_err,       // The STOP bit was not detected
  output reg           lost_data,      // the FIFO is full but new data keep coming in
  output           rx_store_qual,// storage qualification
  output   [1:0] rx_frame_indicator, //frame indicator
  output           rx_bit_indicator, //bit indicator
  output reg [7:0] rx_data_reg //registered received data for chipscope
);


//***************************************************************************
// Parameter definitions
//***************************************************************************

  parameter BAUD_RATE    = 115_200;             // Baud rate
  parameter CLOCK_RATE   = 50_000_000;

//***************************************************************************
// Reg declarations
//***************************************************************************

//***************************************************************************
// Wire declarations
//***************************************************************************

  wire             baud_x16_en;  // 1-in-N enable for uart_rx_ctl FFs
  
  // control signal of the internal fifo
  wire          internal_fifo_we;
  wire          internal_fifo_full;
  wire          internal_fifo_empty;
  
  // internal output from the rx controller
  wire [7:0]    rx_data_internal;
  wire          rx_data_rdy_internal;
  
  // new data signal
  reg               old_rx_data_rdy; // rx_data_rdy on previous clock
  
  // Accept a new character when one is available, and we can push it into
  // the response FIFO. A new character is available on the FIRST clock that
  // rx_data_rdy is asserted - it remains asserted for 1/16th of a bit period.
  wire new_char = rx_data_rdy_internal && !old_rx_data_rdy;  

  // registered received data for chipscope
  //(* mark_debug = "true"*) reg [7:0]		rx_data_reg;  
    
//***************************************************************************
// Code
//***************************************************************************
  // capture the rx_data_rdy for edge detection
  always @(posedge clk_rx)
  begin
      if (rst_clk_rx)
      begin
          old_rx_data_rdy <= 1'b0;
      end
      else
      begin
          old_rx_data_rdy <= rx_data_rdy_internal;
      end
  end

  assign rx_data_rdy = ~internal_fifo_empty;        // available data
  
  /* Processing of the newly arrived data from the rx controller */
  assign internal_fifo_we = new_char & (~internal_fifo_full);
  
  // generate lost_data signal
  always @ (posedge clk_rx)
  begin
    if (rst_clk_rx) 
        lost_data <= 1'b0;
    else
    begin
        lost_data <= lost_data ? 1'b1 : (new_char & internal_fifo_full);
    end
  end
  
  // register the received data whenever there is new data
  always @(posedge clk_rx)
  begin
  // we don't really care about reset... this signal is only for observation
		if (rx_data_rdy)
			rx_data_reg <= rx_data;
		else
			rx_data_reg <= rx_data_reg;
  end
  
  /*The rx fifo as the input to this module*/
  data_fifo_oneclk data_fifo_i0 (
	.din        (rx_data_internal),
	.clk        (clk_rx),
	.rst        (rst_clk_rx),
	.wr_en      (internal_fifo_we),
	.rd_en      (read_en),
	.dout       (rx_data),
	.empty      (internal_fifo_empty),
	.full       (internal_fifo_full)
	);
	
  /* Synchronize the RXD pin to the clk_rx clock domain. Since RXD changes
  * very slowly wrt. the sampling clock, a simple metastability hardener is
  * sufficient */
  meta_harden meta_harden_rxd_i0 (
    .clk_dst      (clk_rx),
    .rst_dst      (rst_clk_rx), 
    .signal_src   (rxd_i),
    .signal_dst   (rxd_clk_rx)
  );

  uart_baud_gen #
  ( .BAUD_RATE  (BAUD_RATE),
    .CLOCK_RATE (CLOCK_RATE)
  ) uart_baud_gen_rx_i0 (
    .clk         (clk_rx),
    .rst         (rst_clk_rx),
    .baud_x16_en (baud_x16_en)
  );

  uart_rx_ctl uart_rx_ctl_i0 (
    .clk_rx      (clk_rx),
    .rst_clk_rx  (rst_clk_rx),
    .baud_x16_en (baud_x16_en),

    .rxd_clk_rx  (rxd_clk_rx),
    
    .rx_data_rdy (rx_data_rdy_internal),
    .rx_data     (rx_data_internal),
    .frm_err     (frm_err),
	.rx_store_qual (rx_store_qual),
    .rx_frame_indicator (rx_frame_indicator), 
    .rx_bit_indicator (rx_bit_indicator)
  );

localparam rx_data_rdy_sample_number = 6'd63;
 //(* mark_debug = "true" *) wire rx_data_rdy_reg;
 reg [5:0] data_rdy_reg_cnt;

 assign rx_data_rdy_reg = (data_rdy_reg_cnt != 6'd0);

 always @ (posedge clk_rx)
 begin
    if (rst_clk_rx)
    begin
        data_rdy_reg_cnt <= {6{1'b0}};
        //rx_data_rdy_reg <= 1'b0;
    end
    else            // if clk
    begin
        if (rx_data_rdy)
        begin
            // when rx_data_rdy comes, set the counter to be the max number and starting
            // decrementing. As long as the counter is not 0, the rdy_reg should be 1. 
            // Hence, the rdy_reg will be high for 63 (or 64?, not sure, doesn't matter) clock cycles.
            data_rdy_reg_cnt <= rx_data_rdy_sample_number;
        end
        else if (data_rdy_reg_cnt != 6'd0)
        begin
            data_rdy_reg_cnt <= data_rdy_reg_cnt - 1'b1;
        end
    end
 end
 
endmodule
