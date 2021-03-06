`timescale 1ns / 1ps
module main_module
	(input logic 	USRCLK_N, USRCLK_P,
 	 input logic 	reset,
 	//  input logic 	rx_din,									// 1 byte input from PC
	 // output logic 	tx_dout,
	 input logic en,
	 output logic [TS_WID+$clog2(NEURON_NO)-1:0] result_out,
	 output logic sp_out);

localparam NEURON_NO = 256;
localparam TS_WID = 12;
// localparam FIFO_MEM_NO = 8;
// localparam UART_DATA_LEN = 8;
// localparam UART_CYC=3;
// localparam OUT_W = 8;
localparam DT = 10000;						// 1 ms/ 10 ns
localparam W = 10485;						// FXnum(0.01, FXfamily(20,1))
localparam CMEM = 1398101;					// FXnum(0.04/(0.04-0.01), FXfamily(20,4))
localparam W_CMEM = 13981;					// FXnum(0.01*0.04/0.03, FXfamily(20,1))
localparam W_C = 279620;					// FXnum(0.01*0.04/(0.04-0.01)/0.05, FXfamily(20,1))

logic clk1, clk2;
clk_wiz_0 clock_module(
	.clk_in1_p(USRCLK_P),
	.clk_in1_n(USRCLK_N),
	.clk_out1(clk1),
	.clk_out2(clk2));

logic sys_en;
assign sys_en = en;

// struct {logic [UART_DATA_LEN-1:0] data;
// 		logic dv;
// 		} rx;

// struct {logic dv; 
// 		logic active;
// 		logic done;
// 		} tx;

struct {logic [1:0] req;								// External request signal
		// logic [$clog2(NEURON_NO)-1:0] rd_addr, wr_addr;	// External read and write address of neuron memory
		// logic [NEURON_LEN-1:0] din, dout;				// Externaly input data into neuron memory
		} ext;

struct {logic signal;										// Write signal for FIFO module	
		logic [TS_WID+$clog2(NEURON_NO)-1:0] addr;	// Input data for FIFO module
		} spike;

assign sp_out = spike.signal;
assign result_out = spike.addr;
// struct {logic [TS_WID+$clog2(NEURON_NO)-1:0] dout;		
// 		logic full, empty, ext_rd;
// 		} fifo;

// logic ser_rdy;
// logic [OUT_W-1:0] serialized_data;
logic 	[$clog2(NEURON_NO)-1:0] t_fix_addr, testing_addr;
logic 	t_fix_wr_en;
logic	[TS_WID-1:0] dt_ts;
logic 	[$clog2(DT)-1:0] dt_count;
logic 	dt_tick;
logic 	[TS_WID-1:0] weight;

// uart_rx #(.CLKS_PER_BIT(87)) uart_rx(	// Note: If there is a weak blinking issue, check clk/bits 
// 	.i_Clock(clk),
// 	.i_Rx_Serial(rx_din),				// serial input from PC
// 	.o_Rx_Byte(rx.data),				// 1 byte data recieved
// 	.o_Rx_DV(rx.dv));					// tells when the entire 1 byte is recieved

// system_ctrl #(.TS_WID(TS_WID), .NEURON_NO(NEURON_NO), 
// 			  .UART_DATA_LEN(UART_DATA_LEN), .UART_CYC(UART_CYC), 
// 			  .NEURON_LEN(NEURON_LEN)) system_ctrl(							
// 	.clk(clk),									
// 	.reset(reset),
// 	.rx_dv(rx.dv),
// 	.rx_data(rx.data),
// 	.sys_en(sys_en),
// 	.fifo_rd(fifo.ext_rd),
// 	.ext_req(ext.req),
// 	.ext_rd_addr(ext.rd_addr),
// 	.ext_wr_addr(ext.wr_addr),
// 	.ext_dout(ext.dout),
// 	.ext_din(ext.din),
// 	.spike(spike.signal),
// 	.fifo_dout(fifo.dout));

dt_counter #(.DT(DT), .TS_WID(TS_WID))
	dt_counter_module (
	.clk(clk1),
	.reset(reset),
	.sys_en(sys_en),
	.dt_tick(dt_tick),
	.dt_count(dt_count),
	.dt_ts(dt_ts));

int_signal #(.NEURON_NO(NEURON_NO))
	int_singal_module (
	.clk(clk1),
	.reset(reset),
	.sys_en(sys_en),
	.ext_req(ext.req),
	.dt_tick(dt_tick),
	.testing_en(testing_en),
	.testing_addr(testing_addr),
	.sel(sel));

logic [NEURON_NO-1:0] spike_in_ram;												// spike_in 
logic sp_in;

assign sp_in = (testing_en &sel) & spike_in_ram[testing_addr]; 					// Spike input 

initial begin
	for (int i=0; i<NEURON_NO; i++) begin
		if (i==0) spike_in_ram[i] = 1;
		else if (i==255) spike_in_ram[i] = 1;
		else spike_in_ram[i] = 0;
	end
	ext.req = 0;
	weight = 279620;
end

neuron_module #(.NEURON_NO(NEURON_NO), .TS_WID(TS_WID)) neuron_module (
	.clk1(clk1),
	.clk2(clk2),
	.reset(reset),
	.sys_en(sys_en),
	.ext_req(ext.req),
	// .ext_rd_addr(ext.rd_addr),
	// .ext_wr_addr(ext.wr_addr),
	// .ext_din(ext.din),
	// .ext_dout(ext.dout),
	.en(testing_en),
	.weight(weight),
	.sp_in(sp_in),
	.dt_ts(dt_ts),
	.addr_in(testing_addr),
	.sel(sel),
	.ts_sp_addr(spike.addr),
	.sp_out(spike.signal));

// fifo #(.FIFO_MEM_LEN(TS_WID+$clog2(NEURON_NO)), .FIFO_MEM_NO(FIFO_MEM_NO)) fifo_module (
// 	.clk(clk),
// 	.reset(reset),
// 	.fifo_rd_en(ser_rdy), //fifo.ext_rd), 		// Reading happens when it is required
// 	.spike(spike.signal),						// Writing happens when system is enabled
// 	.full(fifo.full),
// 	.empty(fifo.empty),
// 	.fifo_din(spike.addr),
// 	.fifo_dout(fifo.dout));


// serializer #(.IN_W(TS_WID+$clog2(NEURON_NO)), .OUT_W(8)) output_ser (
// 	.clk(clk),
// 	.reset(reset),
// 	.fifo_empty(fifo.empty),
// 	.tx_done(tx.done),
// 	.tx_dv(tx.dv),
// 	.data_in(fifo.dout),
// 	.ser_rdy(ser_rdy),
// 	.data_out(serialized_data));

// uart_tx #(.CLKS_PER_BIT(87)) uart_tx(
// 	.i_Clock(clk),						
// 	.i_Tx_DV(tx.dv),					// Start signal sending data to PC
// 	.i_Tx_Byte(serialized_data),		// 8 bit data to send
// 	.o_Tx_Active(tx.active),				
// 	.o_Tx_Serial(tx_dout),				// PC recieves 1 byte data
// 	.o_Tx_Done(tx.done));				// reduce tx.done signal into half clks

endmodule
