// Author: Tongning Zhang
// Date: 2024-11-20
// Description: core module of the SDIO burst reader

// This module is implemented for SDHC card, based on SD Specifications Part 1 Physical Layer Simplified Specification Version 9.10(December 1 2023)
// Note that comments begin with Experiment are actual running result of Sandisk Ultra 16 GB SDHC card

module sdio_burst_reader (
    // SDIO interface
    inout logic sdcmd,
    output logic sdclk,
    input logic [3:0] sdq,
    // control signals
    input logic clk_100mhz,
    input logic reset_ah,
    input logic start_pulse,
    output logic [5:0] host_state,
    output logic found_resp,
    output logic ccs,
    output logic [7:0] manufacture_id,
    output logic [3:0] card_current_state,  // current state is part of card status([12:9])
    // BRAM interface
    input logic [5:0] bram_addr,  // depth 0-63
    output logic [63:0] bram_data,
    // FSM reader status
    output logic read_single_sector_done_pulse,  // should be a pulse, used by AXI4 Master FSM
    output logic read_all_sector_done_pulse,  // should be a pulse
    // High level input
    input logic [19:0] input_sector_pos,  // 0-1048575 sectors for first0-511.9995117 MiB
    // Since it is only used via command of CMD18, so never worry about its width
    // since it won't be used as intermediate counter
    input logic [19:0] sector_count  // max 1048575 sectors, 511.9995117 MiB
    // the width of the above and cur_sector_pos DECIDES the max continuous read sector count
);
  // Note that in ILA, the states are changed, so inspect on the input of hex segment
  typedef enum logic [5:0] {
    // Low level states for Timing
    TXCMD = 'h0,
    RXRESP = 'h1,
    RXDATA = 'h2,
    // High level Host control states
    IDLE = 'h3,
    CMD0 = 'h4,
    CMD8 = 'h5,
    CMD8_SENTDONE = 'h6,
    CMD8_PROCESSRX = 'h7,
    CMD55_41 = 'h8,
    CMD55_41_SENTDONE = 'h9,
    CMD55_41_PROCESSRX = 'ha,
    ACMD41 = 'hb,
    ACMD41_SENTDONE = 'hc,
    ACMD41_PROCESSRX = 'hd,
    CMD2 = 'he,
    CMD2_SENTDONE = 'hf,
    CMD2_PROCESSRX = 'h10,
    CMD3 = 'h11,
    CMD3_SENTDONE = 'h12,
    CMD3_PROCESSRX = 'h13,
    CMD7 = 'h14,
    CMD7_SENTDONE = 'h15,
    CMD7_PROCESSRX = 'h16,
    CMD55_6 = 'h17,
    CMD55_6_SENTDONE = 'h18,
    CMD55_6_PROCESSRX = 'h19,
    ACMD6 = 'h1a,
    ACMD6_SENTDONE = 'h1b,
    ACMD6_PROCESSRX = 'h1c,
    CMD6 = 'h1d,
    CMD6_SENTDONE = 'h1e,
    CMD6_PROCESSRX = 'h1f,
    CMD16 = 'h20,
    CMD16_SENTDONE = 'h21,
    CMD16_PROCESSRX = 'h22,
    CMD18 = 'h23,
    CMD18_SENTDONE = 'h24,
    CMD18_PROCESSRX = 'h25,
    CMD18_CHECKDATA = 'h26,
    CMD12 = 'h27,
    CMD12_SENTDONE = 'h28,
    CMD12_PROCESSRX = 'h29
  } sdio_host_state_t;

  typedef struct packed {  //47 bit
    logic transmission;  //1
    logic [5:0] command;  //6
    logic [31:0] arg;  //32
    logic [6:0] crc;  //7
    logic endbit;  //1
  } sdio_request_t;
  function automatic logic [6:0] crc7(input logic [6:0] crc, input logic inbit);
    return {crc[5:0], crc[6] ^ inbit} ^ {3'b0, crc[6] ^ inbit, 3'b0};
    // ^ is XOR not AND, so for input 0 and crc==0, it will return 0(we can ignore the start bit)
  endfunction
  function automatic sdio_request_t compose_command(input logic [5:0] cmd, input logic [31:0] arg);
    return {1'b1, cmd, arg, 7'b0, 1'b1};
  endfunction
  // End of function and struct definitions


  logic sdcmd_oe, sdcmd_i, sdcmd_o;
  logic [7:0] clock_counter, clock_div;  // 8-bit counter for initialization 400kHz clock generation
  localparam CLK50M_CNT = 'd1;  //100MHz/1/2 = 50MHz, second 2 is for 2 flips in one cycle
  localparam CLK25M_CNT = 'd2;  //100MHz/2/2 = 25MHz
  localparam CLK12M5_CNT = 'd4;  //100MHz/4/2 = 12.5MHz
`ifdef SYNTHESIS
  localparam CLK400K_CNT = 'd125;  // 100MHz/125/2 = 400kHz // real for 125
`else
  localparam CLK400K_CNT = CLK25M_CNT; // For simulation
`endif
  localparam RECVCNT_R2 = 135;  // 136 - start bit = 135
  localparam RECVCNT_notR2 = 47;  // 48 - start bit = 47
  localparam TXCNT = 48;
  // It's okay to have resp trimmed by Synthesizer:
  // [Synth 8-3936] Found unconnected internal register 'resp_reg' and it is trimmed from '135' to '134' bits. 
  logic [134:0] resp; // 48-bit[46:0]/136-bit[134:0] response, since first bit is always 0, we use only 47-bit/135-bit
  sdio_request_t req;  // 48-bit request
  logic [8:0] reqresp_cnt;
  // max 524287(19bit) padding_cnt, see CMD18_PROCESSRX for reason, to wait for cmd-data gap(10ms)
  logic [18:0] padding_cnt;
  // 256MiB = 256*1024*1024/512 = 524288 sectors, 19 bits, one bit for last sector
  // starting from 0 to sector_count-1, in total (sector_count) sectors
  logic [19:0] cur_sector_pos;  // support 0-1048575 sectors read
  logic found_response;
  logic [15:0] rca;
  logic [31:0] card_status;  // cf. Section 4.10.1 Card status
  logic [10:0] data_rx_cnt;  // max range 2048 but we only need 1024(512 Byte * 2 Clk)
  logic [5:0] data_rx_tail_cnt;  // max range 2048 but we only need 21(16 cycle for crc16)+1 end bit+4 padding
  logic [9:0] bumping_cnt;  // used for bumping the dataline after sending CMD12 (stop transmission)
  // For one sector 512 Bytes, 512*8bit=4096 bit, AXI4 Width=64, 4096/64 = 64 Beats in single Burst
  // So the depth of BRAM is also 64
  logic [63:0] tmpSectorBuffer[64];
  logic [63:0] tmpDWORDBuffer;  // save whole 60 +4 bit to write into BRAM in one cycle
  logic [5:0] datarx_addr, datarx_addr_offset;
  assign card_current_state = card_status[12:9];
  assign found_resp = found_response;
  IOBUF #(
      .SLEW("FAST")
  ) iobuf_sdcmd (
      .I (sdcmd_o),
      .IO(sdcmd),
      .O (sdcmd_i),
      .T (~sdcmd_oe)  //note that when T is low, IOBUF's I is taking output from sdcmd_o
  );
  // return_state is entered after data received
  sdio_host_state_t state, return_state;
  assign host_state = state;
  always_comb begin
    datarx_addr = data_rx_cnt[9:4];  // 16 cycles for 64 bit
    // cycle number(data_rx_cnt) and byte offset mapping
    // c0      c1      c2         c3       c4         c5     ... c14       c15
    // 4(7:4), 0(3:0), 12(15:12), 8(11:8), 20(23:20), 16(19:16)  60(63:60) 56(59:56)
    if (~data_rx_cnt[0]) begin
      datarx_addr_offset = data_rx_cnt[3:1] << 3 + 4;  // first cycle get upper 4 bit of this Byte
    end else begin
      datarx_addr_offset = data_rx_cnt[3:1] << 3;
    end
  end
  always_ff @(posedge clk_100mhz) begin
    // avoid assign or Lab 7.1 XD
    bram_data <= tmpSectorBuffer[bram_addr];
  end
  always_ff @(posedge clk_100mhz) begin
    if (reset_ah) begin
      state <= IDLE;
      sdclk <= 1'b0;  // default high, if not started
      sdcmd_oe <= 0;  // default oe low
      sdcmd_o <= 0;
      clock_counter <= 'b0;
      clock_div <= CLK400K_CNT;
      reqresp_cnt <= 'b0;
      padding_cnt <= 'b0;
      req <= 'b0;
      found_response <= 0;
      rca <= 'b0;
      ccs <= 0;
      manufacture_id <= 'b0;
      card_status <= 'b0;
      data_rx_cnt <= 'b0;
      data_rx_tail_cnt <= 'b0;
      bumping_cnt <= 'b0;
      cur_sector_pos <= 'b0;
      read_single_sector_done_pulse <= 0;
      read_all_sector_done_pulse <= 0;
      tmpDWORDBuffer <= 'b0;
    end else begin
      // TODO Switch (uncomment the next line and comment above line) the following is for manually test 
      // end else if ((state < CMD16) || start_pulse || (state == CMD12_PROCESSRX)) begin
      if (read_single_sector_done_pulse) begin
        read_single_sector_done_pulse <= 0;
      end
      if (read_all_sector_done_pulse) begin
        read_all_sector_done_pulse <= 0;
      end
      case (state)
        // Low level states for Timing
        // An SDIO device will capture data on the rising edge of clock for all SDR modes.
        // cf. https://e2e.ti.com/support/processors-group/processors/f/processors-forum/1312725/am623-how-to-set-sdio-clock-data-samping
        TXCMD: begin
          if (padding_cnt == 0) begin
            if (reqresp_cnt == 0) begin
              state <= return_state;
            end else begin
              if (clock_counter < clock_div - 1) begin
                clock_counter <= clock_counter + 1;
              end else begin
                sdclk <= ~sdclk;
                clock_counter <= 'b0;
                if (sdclk) begin  // if falling edge
                  if (reqresp_cnt > 1) begin
                    sdcmd_oe <= 1;
                    sdcmd_o  <= req[reqresp_cnt - 2];// e.g. in first turn, 48-2=46, match the MSB index of req
                  end else begin  // last count just for holding one clock cycle(reqresp_cnt == 1)
                    sdcmd_oe <= 0;
                  end
                  // 48 for MSB(transmission bit),47 for MSB of command,41 for MSB of arg, 9 for MSB of crc, 2 for endbit
                  if (reqresp_cnt >= 10) begin
                    req.crc <= crc7(req.crc, req[reqresp_cnt-2]);
                  end
                  reqresp_cnt <= reqresp_cnt - 1;
                end
              end
            end
          end else begin  // Tx padding won’t be SKIPPED if sdcmd_i is low
            if (clock_counter < clock_div - 1) begin
              clock_counter <= clock_counter + 1;
            end else begin
              sdclk <= ~sdclk;
              clock_counter <= 'b0;
              if (sdclk) begin  // if falling edge
                padding_cnt <= padding_cnt - 1;
                if (padding_cnt == 1) begin
                  sdcmd_oe <= 1;
                  sdcmd_o  <= 0;  // start bit 0 
                end
              end
            end
          end
        end
        RXRESP: begin
          if (padding_cnt == 0) begin
            if (reqresp_cnt == 0) begin
              state <= return_state;
            end else begin
              if (clock_counter < clock_div - 1) begin
                clock_counter <= clock_counter + 1;
              end else begin
                sdclk <= ~sdclk;
                clock_counter <= 'b0;
                if (~sdclk) begin  // sample on rising edge
                  resp <= {resp[133:0], sdcmd_i};  // first recv bit is MSB at the end of day
                end else begin  // counter decrement should be on falling edge
                  reqresp_cnt <= reqresp_cnt - 1;
                end
              end
            end
          end else begin
            if (clock_counter < clock_div - 1) begin
              clock_counter <= clock_counter + 1;
            end else begin
              sdclk <= ~sdclk;
              clock_counter <= 'b0;
              // decrement counter on falling edge, make sure after exiting padding state, sdclk is low
              if (sdclk) begin
                padding_cnt <= padding_cnt - 1;
                if (found_response) begin
                  padding_cnt <= 0;
                end
              end else begin
                // read response on rising edge
                if (~sdcmd_i) begin  // if found start bit(low)
                  found_response <= 1;  // wait until next falling edge
                end

              end
            end
          end
        end
        RXDATA: begin // This state only read one sector, for sector count control see CMD18_CHECKDATA
          if (padding_cnt == 0) begin
            if (data_rx_tail_cnt == 0) begin
              if (found_response) begin
                // increment it here first, don't do it in CMD18_CHECKDATA
                cur_sector_pos <= cur_sector_pos + 1;
                // inform external module (e.g. AXI4 Master FSM) that one sector is done
                read_single_sector_done_pulse <= 1;
              end
              state <= return_state;  // Return to CMD18_CHECKDATA
            end else begin
              if (data_rx_cnt < 512 * 2) begin  // do 512*2 this loop for receiving 512 Byte
                if (clock_counter < clock_div - 1) begin
                  clock_counter <= clock_counter + 1;
                end else begin
                  sdclk <= ~sdclk;
                  clock_counter <= 'b0;
                  if (~sdclk) begin  // sample on rising edge
                    if (data_rx_cnt[3:0] == 4'hF) begin
                      // have received 16 cycle * 4 bits, then store to BRAM
                      tmpSectorBuffer[datarx_addr] <= {
                        tmpDWORDBuffer[63:60], sdq, tmpDWORDBuffer[55:0]
                      };
                      // need not to manually clear tmpDWORDBuffer, since it will be overwritten in next loop
                    end else begin 
                      // note when data_rx_cnt[3:0] == 4'b1110, it will store into tmpDWORDBuffer[63:60]
                      tmpDWORDBuffer[datarx_addr_offset+:4] <= sdq;
                    end

                  end else begin  // counter increment should be on falling edge
                    // note here we add 1, since index is 0-based needed for addressing
                    data_rx_cnt <= data_rx_cnt + 1;
                  end
                end
              end else begin  // dump out the crc bits and also the end bit
                if (clock_counter < clock_div - 1) begin
                  clock_counter <= clock_counter + 1;
                end else begin
                  sdclk <= ~sdclk;
                  clock_counter <= 'b0;
                  if (sdclk) begin  // counter decrement should be on falling edge
                    data_rx_tail_cnt <= data_rx_tail_cnt - 1;
                  end
                end
              end
            end
          end else begin
            if (clock_counter < clock_div - 1) begin
              clock_counter <= clock_counter + 1;
            end else begin
              sdclk <= ~sdclk;
              clock_counter <= 'b0;
              // decrement counter on falling edge, make sure after exiting padding state, sdclk is low
              if (sdclk) begin
                padding_cnt <= padding_cnt - 1;
                if (found_response) begin
                  padding_cnt <= 0;
                end
              end else begin
                // scan start bit of data on rising edge, sdq[0] or other bit like sdq[1] also works
                if (~sdq[0]) begin
                  found_response <= 1;
                end
              end
            end
          end
        end
        // High level Host control states
        IDLE: begin
          if (start_pulse) begin
            state <= CMD0;
          end
        end
        CMD0: begin  // GO_IDLE_STATE no response
          // Goto TXCMD state
          state <= TXCMD;

          reqresp_cnt <= TXCNT;  // count 48 cycles
          padding_cnt <= 4;
          req <= compose_command(0, 0);
          return_state = CMD8;
        end
        CMD8: begin  // R7 response , SEND_IF_COND
          // Goto TXCMD state
          state <= TXCMD;

          reqresp_cnt <= TXCNT;
          padding_cnt <= 40;
          req <= compose_command(
              8, 'h1aa
          );  // Voltage 2.7-3.6V, Check pattern 8'haa, cf. Section 4.3.13
          return_state = CMD8_SENTDONE;  // Actual return is
        end
        CMD8_SENTDONE: begin
          state <= RXRESP;
          reqresp_cnt <= RECVCNT_notR2;
          padding_cnt <= 200;  //here padding meanning max waiting cycles
          found_response <= 0;
          return_state = CMD8_PROCESSRX;
        end
        CMD8_PROCESSRX: begin
          if (found_response && resp[15:8] == 8'haa) begin
            state <= CMD55_41;
          end else begin
            state <= CMD8;
          end
        end
        CMD55_41: begin  // R1 response
          // Goto TXCMD state
          state <= TXCMD;

          reqresp_cnt <= TXCNT;
          padding_cnt <= 4;
          req <= compose_command(55, 0);
          return_state = CMD55_41_SENTDONE;
        end
        CMD55_41_SENTDONE: begin
          state <= RXRESP;
          reqresp_cnt <= RECVCNT_notR2;  // 48 - start bit = 47
          padding_cnt <= 200;
          found_response <= 0;
          return_state = CMD55_41_PROCESSRX;
        end
        CMD55_41_PROCESSRX: begin
          if (found_response) begin
            state <= ACMD41;
            card_status <= resp[39:8];  // cf. Section 4.9.1 R1(normal response)
          end else begin
            state <= CMD55_41;  // retry
          end
        end
        ACMD41: begin  // R3 response, SD_SEND_OP_COND
          // Goto TXCMD state
          state <= TXCMD;

          reqresp_cnt <= TXCNT;
          padding_cnt <= 4;
          req <= compose_command(41, 'hc0100000);
          return_state = ACMD41_SENTDONE;
        end
        ACMD41_SENTDONE: begin
          state <= RXRESP;
          reqresp_cnt <= RECVCNT_notR2;
          padding_cnt <= 200;
          found_response <= 0;
          return_state = ACMD41_PROCESSRX;
        end
        ACMD41_PROCESSRX: begin
          // Note that R2 and R3's response 'CMD' is 111111(reserved), cf. Section 4.9.3/4
          // resp[39] is OCR
          // This bit is set to LOW if the card has not finished the power up routine.
          // Experiment: in first send resp[39] will be 0, so it needs resent
          if (found_response && resp[39]) begin
            ccs   <= resp[38];  // Card Capacity Status(CCS), 0=SDSC, 1=SDHC or SDXC
            state <= CMD2;
          end else begin
            state <= CMD55_41;  // retry
          end
        end
        CMD2: begin  // R2 response, ALL_SEND_CID
          // Goto TXCMD state
          state <= TXCMD;

          reqresp_cnt <= TXCNT;
          padding_cnt <= 4;
          req <= compose_command(2, 0);
          return_state = CMD2_SENTDONE;
        end
        CMD2_SENTDONE: begin
          state <= RXRESP;
          reqresp_cnt <= RECVCNT_R2;
          padding_cnt <= 200;
          found_response <= 0;
          return_state = CMD2_PROCESSRX;
        end
        CMD2_PROCESSRX: begin
          if (found_response) begin
            state <= CMD3;
            manufacture_id <= resp[127:120];  // cf. Section 5.2 CID register
          end else begin
            state <= CMD2;  // retry
          end
        end
        CMD3: begin  // R6 response, SEND_RELATIVE_ADDR(get new RCA[31:16])
          // Goto TXCMD state
          state <= TXCMD;

          reqresp_cnt <= TXCNT;
          padding_cnt <= 4;
          req <= compose_command(3, 0);
          return_state = CMD3_SENTDONE;
        end
        CMD3_SENTDONE: begin
          state <= RXRESP;
          reqresp_cnt <= RECVCNT_notR2;
          padding_cnt <= 200;
          found_response <= 0;
          return_state = CMD3_PROCESSRX;
        end
        CMD3_PROCESSRX: begin
          if (found_response) begin
            // Experiment: it get 0x1 as rca, and now card_current_state is 0x2 ident
            rca <= resp[39:24];  // cf. Section 4.9.5, new RCA[31:16] in R6 
            card_status[23] <= resp[23];
            card_status[22] <= resp[22];
            card_status[19] <= resp[21];
            card_status[12:0] <= resp[20:8];
            state <= CMD7;
          end else begin
            state <= CMD3;  // retry
          end
        end
        CMD7: begin  // R1b response(only from selected card), SELECT/DESELECT_CARD
          // Goto TXCMD state
          state <= TXCMD;

          reqresp_cnt <= TXCNT;
          padding_cnt <= 4;
          req <= compose_command(7, {rca, 16'b0});
          return_state = CMD7_SENTDONE;
        end
        CMD7_SENTDONE: begin
          state <= RXRESP;
          reqresp_cnt <= RECVCNT_notR2;
          padding_cnt <= 2048;
          found_response <= 0;
          return_state = CMD7_PROCESSRX;
        end
        CMD7_PROCESSRX: begin
          if (found_response) begin
            state <= CMD55_6;
            // Experiment:  card_current_state is 0x3 stand-by
            card_status <= resp[39:8];  // cf. Section 4.9.2 R1b(normal response)
            // Change clock speed to Medium speed
            clock_div <= CLK12M5_CNT;
          end else begin
            state <= CMD7;  // retry
          end
        end
        CMD55_6: begin  // R1 response
          // Goto TXCMD state
          state <= TXCMD;
          reqresp_cnt <= TXCNT;
`ifdef SYNTHESIS
          padding_cnt <= 2048;
`else
          padding_cnt <= 4;
`endif

          req <= compose_command(55, {rca, 16'b0});
          return_state = CMD55_6_SENTDONE;
        end
        CMD55_6_SENTDONE: begin
          state <= RXRESP;
          reqresp_cnt <= RECVCNT_notR2;
          padding_cnt <= 2048;
          found_response <= 0;
          return_state = CMD55_6_PROCESSRX;
        end
        CMD55_6_PROCESSRX: begin
          if (found_response) begin
            state <= ACMD6;
            // Experiment:  card_current_state is 0x4 transfer
            card_status <= resp[39:8];  // cf. Section 4.9.1 R1(normal response)
          end else begin
            state <= CMD55_6;  // retry
          end
        end
        ACMD6: begin  // R1 response, SET_BUS_WIDTH
          // Goto TXCMD state
          state <= TXCMD;
          reqresp_cnt <= TXCNT;
          padding_cnt <= 2048;
          req <= compose_command(6, 'h2);  // [1:0]bus width,  '10'=4 bits bus
          return_state = ACMD6_SENTDONE;
        end
        ACMD6_SENTDONE: begin
          state <= RXRESP;
          reqresp_cnt <= RECVCNT_notR2;
          padding_cnt <= 2048;
          found_response <= 0;
          return_state = ACMD6_PROCESSRX;
        end
        ACMD6_PROCESSRX: begin
          if (found_response) begin
            state <= CMD6;
            card_status <= resp[39:8];  // cf. Section 4.9.1 R1(normal response)
          end else begin
            state <= CMD55_6;  // retry
          end
        end
        CMD6: begin  // R1 response, SWITCH_FUNC
          // Goto TXCMD state
          state <= TXCMD;
          reqresp_cnt <= TXCNT;
          padding_cnt <= 2048;
          // cf. Table 4-32 [31]Mode=1, Switch function; 
          // Table 4-11 Available Functions of CMD6
          // [23:20] reserved, [19:16] reserved
          // [15:12] function group 4 for Power Limit   4'hF = no influence
          // [11:8] function group 3 for Drive Strength 4'hF = no influence
          // [7:4] function group 2 for Command System  4'hF = no influence
          // [3:0] function group 1 for Access Mode     4'h1 = High Speed SDR25
          req <= compose_command(6, 'h8000FFF1);
          return_state = CMD6_SENTDONE;
        end
        CMD6_SENTDONE: begin
          state <= RXRESP;
          reqresp_cnt <= RECVCNT_notR2;
          padding_cnt <= 2048;
          found_response <= 0;
          return_state = CMD6_PROCESSRX;
        end
        CMD6_PROCESSRX: begin
          if (found_response) begin
            state <= CMD16;
            // Experiment: in response only current state=4(tran), and Ready for data is 1
            card_status <= resp[39:8];  // cf. Section 4.9.1 R1(normal response)
            // Change clock speed to High speed
            clock_div <= CLK50M_CNT;
          end else begin
            state <= CMD6;  // retry
          end
        end
        CMD16: begin  // R1 response, SET_BLOCKLEN
          // Goto TXCMD state
          state <= TXCMD;
          reqresp_cnt <= TXCNT;
          padding_cnt <= 2048;  // a bit longer for SD card to fit in new clock
          // [31:0] block length, 512 bytes block length
          req <= compose_command(16, 'h200);
          return_state = CMD16_SENTDONE;
        end
        CMD16_SENTDONE: begin
          state <= RXRESP;
          reqresp_cnt <= RECVCNT_notR2;
          padding_cnt <= 2048;
          found_response <= 0;
          return_state = CMD16_PROCESSRX;
        end
        CMD16_PROCESSRX: begin
          if (found_response) begin
            state <= CMD18;
            card_status <= resp[39:8];  // cf. Section 4.9.1 R1(normal response)
          end else begin
            state <= CMD16;  // retry
          end
        end
        // This state (CMD18) also is a IDLE state for waiting external start pulse
        // i.e. if one round of reading(including sectors from 0 to END_SECTOR_CNT) is done, then return to
        // this state for waiting another round of reading
        CMD18: begin  // R1 response, READ_MULTIPLE_BLOC
          if (start_pulse && (sector_count != 0)) begin  // prevent entering when sector_count is 0
            // Goto TXCMD state
            state <= TXCMD;
            reqresp_cnt <= TXCNT;
            padding_cnt <= 2048;
            // [31:0] data address, 
            // SDSC Card (CCS=0) uses byte unit address 
            // SDHC and SDXC Cards (CCS=1) use block unit address (512 Bytes unit).
            // i.e. sector number
            found_response <= 0;  // clear it otherwise it looks weird in manual mode
            req <= compose_command(18, cur_sector_pos + input_sector_pos);
            return_state = CMD18_SENTDONE;
          end
        end
        CMD18_SENTDONE: begin
          state <= RXRESP;
          reqresp_cnt <= RECVCNT_notR2;
          padding_cnt <= 2048;
          found_response <= 0;
          return_state = CMD18_PROCESSRX;
        end
        CMD18_PROCESSRX: begin
          if (found_response) begin
            state <= RXDATA;
            data_rx_cnt <= 0;  // note that start growing from 0
            data_rx_tail_cnt <= 16+1+4;  // 16 cycle for crc16, 1 fpr end bit, another 4 for padding
            // wait at most 10ms, cf. Lizhirui's code `sd_reader.sv`
            // (10e-3)/(1/(50e6)) = 500000
            // padding for detecting low start bit of data line
            padding_cnt <= 500000;
            found_response <= 0;

            card_status <= resp[39:8];  // cf. Section 4.9.1 R1(normal response)
            return_state = CMD18_CHECKDATA;
          end else begin
            state <= CMD18;  // retry
          end
        end
        CMD18_CHECKDATA: begin
          if (found_response) begin  // dumb way since already checked `found_response` in RXDATA's end...
            if (cur_sector_pos < sector_count) begin
              state <= RXDATA;  // waiting for next turn of read start pulse
              // reset loop for next sector
              data_rx_cnt <= 0;
              data_rx_tail_cnt <= 16+1+4;  // 16 cycle for crc16, 1 fpr end bit, another 4 for padding
              padding_cnt <= 2048;
              found_response <= 0;
            end else begin
              read_all_sector_done_pulse <= 1;
              state <= CMD12;  // Stop Transmission
            end
          end else begin  // timeout, then resent, don't increase cur_sector_pos
            // retry(resend command 18), but not going to STATE CMD18, it is for waiting external start pulse
            state <= TXCMD;
            reqresp_cnt <= TXCNT;
            padding_cnt <= 2048;
            req <= compose_command(18, cur_sector_pos + input_sector_pos);
            return_state = CMD18_SENTDONE;
          end
        end
        // And Stop Transmission CMD12 STOP_TRANSMISSION R1b
        CMD12: begin
          cur_sector_pos <= 0;  // also clear sector position
          // Goto TXCMD state
          state <= TXCMD;
          reqresp_cnt <= TXCNT;
          // stop it immediately(not 0, otherwise damage the tx) since the card is in data mode, 
          // it will continuously send data when clock is on
          padding_cnt <= 4;
          found_response <= 0;
          req <= compose_command(12, 0);
          return_state = CMD12_SENTDONE;
        end
        CMD12_SENTDONE: begin
          state <= RXRESP;
          reqresp_cnt <= RECVCNT_notR2;
          padding_cnt <= 2048;
          // bumping the dataline to restore logic high on sdq(preprocess for next round reading)
          bumping_cnt <= 1023;  // Actually can be smaller, since CMD12 is sent, it is R1b has data on sdq
          found_response <= 0;
          return_state = CMD12_PROCESSRX;
        end
        CMD12_PROCESSRX: begin
          if (found_response) begin
            if (bumping_cnt == 0) begin
              state <= CMD18;  // go to STATE CMD18, waiting external start pulse
              // Experiment:  card_current_state is 0x5 data mode
              card_status <= resp[39:8];  // cf. Section 4.9.1 R1(normal response)
            end else begin  // wait for bumping cycles to let sdq[3:0] logic high
              if (clock_counter < clock_div - 1) begin
                clock_counter <= clock_counter + 1;
              end else begin
                sdclk <= ~sdclk;
                clock_counter <= 'b0;
                if (sdclk) begin  // decrement counter on falling edge
                  bumping_cnt <= bumping_cnt - 1;
                end
              end
            end
          end else begin
            state <= CMD12;  // retry
          end
        end
        default: begin
          state <= IDLE;
        end


      endcase
    end
  end

endmodule
