
`timescale 1 ns / 1 ps

module axi4_sdio_burst_reader_v1_0 #(
    // Users to add parameters here

    // User parameters ends
    // Do not modify the parameters beyond this line

    // Parameters of Axi Master Bus Interface AXI
    parameter integer C_AXI_BURST_LEN = 64,
    parameter integer C_AXI_ID_WIDTH = 1,
    parameter integer C_AXI_ADDR_WIDTH = 32,
    parameter integer C_AXI_DATA_WIDTH = 64
) (
    // SDIO ports
    inout logic sdcmd,
    input logic [3:0] sdq,
    output logic sdclk,
    // burst input
    input logic start_whole_burst,  // not necessarily be a pulse
    // location
    input logic [31:0] input_sector_pos,
    input logic [31:0] sector_count,
    input logic [31:0] target_slave_base_addr,
    // status of the whole IP
    output logic read_all_sector_done_pulse, // pulse when sdio_reader reads all sectors(debug use)
    output logic axi_txn_done,// long lasting signal until next round of burst(cleared after beginning of next burst) 
    output logic axi_error,
    output logic [5:0] sdio_host_state,
    output logic [3:0] card_current_state,
    // Physical interface 
    input logic axi_aclk,
    input logic axi_aresetn,
    output logic [C_AXI_ID_WIDTH-1 : 0] axi_awid,
    output logic [C_AXI_ADDR_WIDTH-1 : 0] axi_awaddr,
    output logic [7 : 0] axi_awlen,
    output logic [2 : 0] axi_awsize,
    output logic [1 : 0] axi_awburst,
    output logic axi_awlock,
    output logic [3 : 0] axi_awcache,
    output logic [2 : 0] axi_awprot,
    output logic [3 : 0] axi_awqos,
    output logic axi_awvalid,
    input logic axi_awready,
    output logic [C_AXI_DATA_WIDTH-1 : 0] axi_wdata,
    output logic [C_AXI_DATA_WIDTH/8-1 : 0] axi_wstrb,
    output logic axi_wlast,
    output logic axi_wvalid,
    input logic axi_wready,
    input logic [1 : 0] axi_bresp,
    input logic axi_bvalid,
    output logic axi_bready
);
  logic read_single_sector_done_pulse;
  logic [5:0] bram_addr;
  logic [63:0] bram_data;
  axi4_sdio_burst_reader_v1_0_AXI #(
      .C_M_AXI_BURST_LEN(C_AXI_BURST_LEN),
      .C_M_AXI_ID_WIDTH(C_AXI_ID_WIDTH),
      .C_M_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH),
      .C_M_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH)
  ) axi4_sdio_burst_reader_v1_0_AXI_inst (
      .write_sector_count(sector_count),
      .target_slave_base_addr(target_slave_base_addr),
      .start_whole_burst(start_whole_burst),  // not necessarily be a pulse
      .single_sector_burst(read_single_sector_done_pulse),
      .TXN_DONE(axi_txn_done),
      .ERROR(axi_error),
      // Bram access to the SDIO reader
      .bram_addr(bram_addr),
      .bram_data(bram_data),
      // Physical interface
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
      .M_AXI_AWVALID(axi_awvalid),
      .M_AXI_AWREADY(axi_awready),
      .M_AXI_WDATA(axi_wdata),
      .M_AXI_WSTRB(axi_wstrb),
      .M_AXI_WLAST(axi_wlast),
      .M_AXI_WVALID(axi_wvalid),
      .M_AXI_WREADY(axi_wready),
      .M_AXI_BRESP(axi_bresp),
      .M_AXI_BVALID(axi_bvalid),
      .M_AXI_BREADY(axi_bready)
  );
  logic start_pulse_sdio;  // generate a pulse from start_whole_burst
  logic start_whole_burst_ff1, start_whole_burst_ff2;
  always @(posedge axi_aclk) begin
    if (~axi_aresetn) begin
      start_whole_burst_ff1 <= 1'b0;
      start_whole_burst_ff2 <= 1'b0;
    end else begin
      start_whole_burst_ff1 <= start_whole_burst;
      start_whole_burst_ff2 <= start_whole_burst_ff1;
    end
  end
  assign start_pulse_sdio = start_whole_burst_ff1 & ~start_whole_burst_ff2;
  // Add user logic here
  sdio_burst_reader reader (
      .sdcmd(sdcmd),
      .sdclk(sdclk),
      .sdq(sdq),
      .clk_100mhz(axi_aclk),
      .reset_ah(~axi_aresetn),
      .start_pulse(start_pulse_sdio),
      .host_state(sdio_host_state),
      //   .found_resp(LED[14]),
      //   .ccs(LED[15]),
      //   .manufacture_id(manufacture_id),
      .card_current_state(card_current_state), // cf. Section 4.10.1(Card Status), not host status
      .bram_addr(bram_addr),
      .bram_data(bram_data),
      .input_sector_pos(input_sector_pos),
      .sector_count(sector_count),
      .read_single_sector_done_pulse(read_single_sector_done_pulse),
      .read_all_sector_done_pulse(read_all_sector_done_pulse) // debug use
  );
  // User logic ends

endmodule
