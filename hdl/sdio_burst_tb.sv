`timescale 10ns / 1ns
module sdio_burst_tb ();
  logic        clk_100mhz;
  logic        reset_rtl_0;
  logic        btn1;
  logic        btn2;
  logic        btn3;
  logic [15:0] LED;
  logic [ 7:0] D0_SEG;
  logic [ 3:0] D0_AN;
  logic [ 3:0] sd_data;
  wire         sdcmd;
  logic        sdclk;
  logic sdcmd_oe, sdcmd_i, sdcmd_o;
  logic [7:0] clock_counter, clock_div;
  logic [4:0] state;
  logic start_pulse;
  logic [8:0] reqresp_cnt;
  logic [46:0] req;
  sdio_burst_top tr (
      .*
  );
  // assign
  assign sdcmd_oe = tr.reader.sdcmd_oe;
  assign sdcmd_o = tr.reader.sdcmd_o;
  assign sdcmd_i = tr.reader.sdcmd_i;
  assign clock_counter = tr.reader.clock_counter;
  assign clock_div = tr.reader.clock_div;
  assign state = tr.reader.state;
  assign start_pulse = tr.reader.start_pulse;
  assign reqresp_cnt = tr.reader.reqresp_cnt;
  assign req = tr.reader.req;


  initial begin : CLOCK_INITIALIZATION
    clk_100mhz = 0;
  end
  always begin : CLOCK_GENERATION
    #1 clk_100mhz = ~clk_100mhz;  // 2*10ns for 1 clk cycle
  end
  initial begin : TEST_VECTORS
    btn1 <= 0;
    btn2 <= 0;
    btn3 <= 0;
    sd_data <= 4'b0;
    reset_rtl_0 <= 1;
    #20 reset_rtl_0 <= 0;
    #4 btn1 <= 1;
    #2 btn1 <= 0;
    #2
      #5000
        $finish();


  end

endmodule
