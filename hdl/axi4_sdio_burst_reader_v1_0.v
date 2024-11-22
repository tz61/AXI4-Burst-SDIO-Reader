
`timescale 1 ns / 1 ps

	module axi4_sdio_burst_reader_v1_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Master Bus Interface AXI
		parameter  C_AXI_TARGET_SLAVE_BASE_ADDR	= 32'h40000000,
		parameter integer C_AXI_BURST_LEN	= 16,
		parameter integer C_AXI_ID_WIDTH	= 1,
		parameter integer C_AXI_ADDR_WIDTH	= 32,
		parameter integer C_AXI_DATA_WIDTH	= 32,
		parameter integer C_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_AXI_WUSER_WIDTH	= 0,
		parameter integer C_AXI_RUSER_WIDTH	= 0,
		parameter integer C_AXI_BUSER_WIDTH	= 0
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Master Bus Interface AXI
		input wire  axi_init_axi_txn,
		output wire  axi_txn_done,
		output wire  axi_error,
		input wire  axi_aclk,
		input wire  axi_aresetn,
		output wire [C_AXI_ID_WIDTH-1 : 0] axi_awid,
		output wire [C_AXI_ADDR_WIDTH-1 : 0] axi_awaddr,
		output wire [7 : 0] axi_awlen,
		output wire [2 : 0] axi_awsize,
		output wire [1 : 0] axi_awburst,
		output wire  axi_awlock,
		output wire [3 : 0] axi_awcache,
		output wire [2 : 0] axi_awprot,
		output wire [3 : 0] axi_awqos,
		output wire [C_AXI_AWUSER_WIDTH-1 : 0] axi_awuser,
		output wire  axi_awvalid,
		input wire  axi_awready,
		output wire [C_AXI_DATA_WIDTH-1 : 0] axi_wdata,
		output wire [C_AXI_DATA_WIDTH/8-1 : 0] axi_wstrb,
		output wire  axi_wlast,
		output wire [C_AXI_WUSER_WIDTH-1 : 0] axi_wuser,
		output wire  axi_wvalid,
		input wire  axi_wready,
		input wire [C_AXI_ID_WIDTH-1 : 0] axi_bid,
		input wire [1 : 0] axi_bresp,
		input wire [C_AXI_BUSER_WIDTH-1 : 0] axi_buser,
		input wire  axi_bvalid,
		output wire  axi_bready,
		output wire [C_AXI_ID_WIDTH-1 : 0] axi_arid,
		output wire [C_AXI_ADDR_WIDTH-1 : 0] axi_araddr,
		output wire [7 : 0] axi_arlen,
		output wire [2 : 0] axi_arsize,
		output wire [1 : 0] axi_arburst,
		output wire  axi_arlock,
		output wire [3 : 0] axi_arcache,
		output wire [2 : 0] axi_arprot,
		output wire [3 : 0] axi_arqos,
		output wire [C_AXI_ARUSER_WIDTH-1 : 0] axi_aruser,
		output wire  axi_arvalid,
		input wire  axi_arready,
		input wire [C_AXI_ID_WIDTH-1 : 0] axi_rid,
		input wire [C_AXI_DATA_WIDTH-1 : 0] axi_rdata,
		input wire [1 : 0] axi_rresp,
		input wire  axi_rlast,
		input wire [C_AXI_RUSER_WIDTH-1 : 0] axi_ruser,
		input wire  axi_rvalid,
		output wire  axi_rready
	);
// Instantiation of Axi Bus Interface AXI
	axi4_sdio_burst_reader_v1_0_AXI # ( 
		.C_M_TARGET_SLAVE_BASE_ADDR(C_AXI_TARGET_SLAVE_BASE_ADDR),
		.C_M_AXI_BURST_LEN(C_AXI_BURST_LEN),
		.C_M_AXI_ID_WIDTH(C_AXI_ID_WIDTH),
		.C_M_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH),
		.C_M_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
		.C_M_AXI_AWUSER_WIDTH(C_AXI_AWUSER_WIDTH),
		.C_M_AXI_ARUSER_WIDTH(C_AXI_ARUSER_WIDTH),
		.C_M_AXI_WUSER_WIDTH(C_AXI_WUSER_WIDTH),
		.C_M_AXI_RUSER_WIDTH(C_AXI_RUSER_WIDTH),
		.C_M_AXI_BUSER_WIDTH(C_AXI_BUSER_WIDTH)
	) axi4_sdio_burst_reader_v1_0_AXI_inst (
		.INIT_AXI_TXN(axi_init_axi_txn),
		.TXN_DONE(axi_txn_done),
		.ERROR(axi_error),
		.M_AXI_ACLK(axi_aclk),
		.M_AXI_ARESETN(axi_aresetn),
		.M_AXI_AWID(axi_awid),
		.M_AXI_AWADDR(axi_awaddr),
		.M_AXI_AWLEN(axi_awlen),
		.M_AXI_AWSIZE(axi_awsize),
		.M_AXI_AWBURST(axi_awburst),
		.M_AXI_AWLOCK(axi_awlock),
		.M_AXI_AWCACHE(axi_awcache),
		.M_AXI_AWPROT(axi_awprot),
		.M_AXI_AWQOS(axi_awqos),
		.M_AXI_AWUSER(axi_awuser),
		.M_AXI_AWVALID(axi_awvalid),
		.M_AXI_AWREADY(axi_awready),
		.M_AXI_WDATA(axi_wdata),
		.M_AXI_WSTRB(axi_wstrb),
		.M_AXI_WLAST(axi_wlast),
		.M_AXI_WUSER(axi_wuser),
		.M_AXI_WVALID(axi_wvalid),
		.M_AXI_WREADY(axi_wready),
		.M_AXI_BID(axi_bid),
		.M_AXI_BRESP(axi_bresp),
		.M_AXI_BUSER(axi_buser),
		.M_AXI_BVALID(axi_bvalid),
		.M_AXI_BREADY(axi_bready),
		.M_AXI_ARID(axi_arid),
		.M_AXI_ARADDR(axi_araddr),
		.M_AXI_ARLEN(axi_arlen),
		.M_AXI_ARSIZE(axi_arsize),
		.M_AXI_ARBURST(axi_arburst),
		.M_AXI_ARLOCK(axi_arlock),
		.M_AXI_ARCACHE(axi_arcache),
		.M_AXI_ARPROT(axi_arprot),
		.M_AXI_ARQOS(axi_arqos),
		.M_AXI_ARUSER(axi_aruser),
		.M_AXI_ARVALID(axi_arvalid),
		.M_AXI_ARREADY(axi_arready),
		.M_AXI_RID(axi_rid),
		.M_AXI_RDATA(axi_rdata),
		.M_AXI_RRESP(axi_rresp),
		.M_AXI_RLAST(axi_rlast),
		.M_AXI_RUSER(axi_ruser),
		.M_AXI_RVALID(axi_rvalid),
		.M_AXI_RREADY(axi_rready)
	);

	// Add user logic here

	// User logic ends

	endmodule
