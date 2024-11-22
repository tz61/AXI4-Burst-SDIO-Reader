
`timescale 1 ns / 1 ps

module axi4_sdio_burst_reader_v1_0_AXI #(
    // Users to add parameters here
    parameter integer WRITE_BEATS_COUNT = 2,
    // User parameters ends 
    // Do not modify the parameters beyond this line

    // Base address of targeted slave
    parameter C_M_TARGET_SLAVE_BASE_ADDR = 32'h81000000,
    // Burst Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
    parameter integer C_M_AXI_BURST_LEN = 64,
    // Thread ID Width
    parameter integer C_M_AXI_ID_WIDTH = 1,
    // Width of Address Bus
    parameter integer C_M_AXI_ADDR_WIDTH = 32,
    // Width of Data Bus
    parameter integer C_M_AXI_DATA_WIDTH = 64
) (
    // Users to add ports here
    output wire [5:0] bram_addr,
    // User ports ends
    // Do not modify the ports beyond this line

    // Init whole burst write
    input wire start_whole_burst,
    // Initiate single sector burst write
    input wire single_sector_burst,
    // Asserts when transaction is complete
    output wire TXN_DONE,
    // Asserts when ERROR is detected
    output reg ERROR,
    // Global Clock Signal.
    input wire M_AXI_ACLK,
    // Global Reset Singal. This Signal is Active Low
    input wire M_AXI_ARESETN,
    // Master Interface Write Address ID
    output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
    // Master Interface Write Address
    output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
    // Burst length. The burst length gives the exact number of transfers in a burst
    output wire [7 : 0] M_AXI_AWLEN,
    // Burst size. This signal indicates the size of each transfer in the burst
    output wire [2 : 0] M_AXI_AWSIZE,
    // Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
    output wire [1 : 0] M_AXI_AWBURST,
    // Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
    output wire M_AXI_AWLOCK,
    // Memory type. This signal indicates how transactions
    // are required to progress through a system.
    output wire [3 : 0] M_AXI_AWCACHE,
    // Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
    output wire [2 : 0] M_AXI_AWPROT,
    // Quality of Service, QoS identifier sent for each write transaction.
    output wire [3 : 0] M_AXI_AWQOS,
    // Write address valid. This signal indicates that
    // the channel is signaling valid write address and control information.
    output wire M_AXI_AWVALID,
    // Write address ready. This signal indicates that
    // the slave is ready to accept an address and associated control signals
    input wire M_AXI_AWREADY,
    // Write strobes. This signal indicates which byte
    // lanes hold valid data. There is one write strobe
    // bit for each eight bits of the write data bus.
    output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
    // Write last. This signal indicates the last transfer in a write burst.
    output wire M_AXI_WLAST,
    // Write valid. This signal indicates that valid write
    // data and strobes are available
    output wire M_AXI_WVALID,
    // Write ready. This signal indicates that the slave
    // can accept the write data.
    input wire M_AXI_WREADY,
    // Master Interface Write Response.
    input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
    // Write response. This signal indicates the status of the write transaction.
    input wire [1 : 0] M_AXI_BRESP,
    // Write response valid. This signal indicates that the
    // channel is signaling a valid write response.
    input wire M_AXI_BVALID,
    // Response ready. This signal indicates that the master
    // can accept a write response.
    output wire M_AXI_BREADY
);



  // function called clogb2 that returns an integer which has the
  //value of the ceiling of the log base 2

  // function called clogb2 that returns an integer which has the 
  // value of the ceiling of the log base 2.      
  function integer clogb2(input integer bit_depth);
    begin
      for (clogb2 = 0; bit_depth > 0; clogb2 = clogb2 + 1) bit_depth = bit_depth >> 1;
    end
  endfunction

  // C_TRANSACTIONS_NUM is the width of the index counter for 
  // number of write or read transaction.
  localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN - 1);

  // Burst length for transactions, in C_M_AXI_DATA_WIDTHs.
  // Non-2^n lengths will eventually cause bursts across 4K address boundaries.
  localparam integer C_MASTER_LENGTH = 12;
  // total number of burst transfers is master length divided by burst length and burst size
  localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH - clogb2(
      (C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH / 8) - 1
  );
  // Example State machine to initialize counter, initialize write transactions, 
  // initialize read transactions and comparison of read data with the 
  // written data words.

  parameter IDLE = 1'b0, INIT_WRITE = 1'b1;

  reg mst_exec_state;

  // AXI4LITE signals
  //AXI4 internal temp signals
  reg [C_M_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
  reg axi_awvalid;
  reg axi_wlast;
  reg axi_wvalid;
  reg axi_bready;
  //write beat count in a burst
  reg [C_TRANSACTIONS_NUM : 0] write_index;
  //size of C_M_AXI_BURST_LEN length burst in bytes
  wire [C_TRANSACTIONS_NUM+2 : 0] burst_size_bytes;
  //The burst counters are used to track the number of burst transfers of C_M_AXI_BURST_LEN burst length needed to transfer 2^C_MASTER_LENGTH bytes of data.
  reg [20 : 0] write_burst_counter;
  reg [29:0] sector_stride_addr_counter;  // 2**20(512M)*512(2**9), and another bit for last count
  reg start_single_burst_write;
  reg tx_done;
  reg error_reg;
  reg burst_write_active;
  //Interface response error flags
  wire write_resp_error;
  wire wnext;
  reg init_txn_ff;
  reg init_txn_ff2;
  reg init_txn_edge;
  wire init_txn_pulse;



  // I/O Connections assignments

  //I/O Connections. Write Address (AW)
  assign M_AXI_AWID = 'b0;
  //The AXI address is a concatenation of the target base address + active offset range
  assign M_AXI_AWADDR = C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
  //Burst LENgth is number of transaction beats, minus 1
  assign M_AXI_AWLEN = C_M_AXI_BURST_LEN - 1;
  //Size should be C_M_AXI_DATA_WIDTH, in 2^SIZE bytes, otherwise narrow bursts are used
  assign M_AXI_AWSIZE = clogb2((C_M_AXI_DATA_WIDTH / 8) - 1);
  //INCR burst type is usually used, except for keyhole bursts
  assign M_AXI_AWBURST = 2'b01;
  assign M_AXI_AWLOCK = 1'b0;
  //Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache. 
  assign M_AXI_AWCACHE = 4'b0011;
  assign M_AXI_AWPROT = 3'h0;
  assign M_AXI_AWQOS = 4'h0;
  assign M_AXI_AWVALID = axi_awvalid;
  //All bursts are complete and aligned in this example
  assign M_AXI_WSTRB = {(C_M_AXI_DATA_WIDTH / 8) {1'b1}};
  assign M_AXI_WLAST = axi_wlast;
  assign M_AXI_WVALID = axi_wvalid;
  //Write Response (B)
  assign M_AXI_BREADY = axi_bready;

  //Burst size in bytes
  assign burst_size_bytes = C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH / 8;
  assign init_txn_pulse = (!init_txn_ff2) && init_txn_ff;

  // bram address is just write_index
  assign bram_addr = write_index;
  assign TXN_DONE = tx_done;
  //Generate a pulse to initiate AXI transaction.
  always @(posedge M_AXI_ACLK) begin
    // Initiates AXI transaction delay    
    if (M_AXI_ARESETN == 0) begin
      init_txn_ff  <= 1'b0;
      init_txn_ff2 <= 1'b0;
    end else begin
      init_txn_ff  <= start_whole_burst;
      init_txn_ff2 <= init_txn_ff;
    end
  end
  always @(posedge M_AXI_ACLK) begin
    if (M_AXI_ARESETN == 0 || start_whole_burst) begin
      sector_stride_addr_counter <= 30'h0;
    end else begin
      if (wnext && axi_wlast && (write_burst_counter == (WRITE_BEATS_COUNT - 1)))
        sector_stride_addr_counter <= sector_stride_addr_counter + 12'h200;  //512Byte
    end
  end

  //--------------------
  //Write Address Channel
  //--------------------

  // The purpose of the write address channel is to request the address and 
  // command information for the entire transaction.  It is a single beat
  // of information.

  // The AXI4 Write address channel in this example will continue to initiate
  // write commands as fast as it is allowed by the slave/interconnect.
  // The address will be incremented on each accepted address transaction,
  // by burst_size_byte to point to the next address. 

  always @(posedge M_AXI_ACLK) begin

    if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1) begin
      axi_awvalid <= 1'b0;
    end  // If previously not valid , start next transaction
    else if (~axi_awvalid && start_single_burst_write) begin
      axi_awvalid <= 1'b1;
    end    
	    /* Once asserted, VALIDs cannot be deasserted, so axi_awvalid      
	    must wait until transaction is accepted */
    else if (M_AXI_AWREADY && axi_awvalid) begin
      axi_awvalid <= 1'b0;
    end else axi_awvalid <= axi_awvalid;
  end


  // Next address after AWREADY indicates previous address acceptance    
  always @(posedge M_AXI_ACLK) begin
    if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1) begin
      axi_awaddr <= sector_stride_addr_counter;
    end else if (M_AXI_AWREADY && axi_awvalid) begin
      axi_awaddr <= axi_awaddr + burst_size_bytes;
    end else axi_awaddr <= axi_awaddr;
  end


  //--------------------
  //Write Data Channel
  //--------------------

  //The write data will continually try to push write data across the interface.

  //The amount of data accepted will depend on the AXI slave and the AXI
  //Interconnect settings, such as if there are FIFOs enabled in interconnect.

  //Note that there is no explicit timing relationship to the write address channel.
  //The write channel has its own throttling flag, separate from the AW channel.

  //Synchronization between the channels must be determined by the user.

  //The simpliest but lowest performance would be to only issue one address write
  //and write data burst at a time.

  //In this example they are kept in sync by using the same address increment
  //and burst sizes. Then the AW and W channels have their transactions measured
  //with threshold counters as part of the user logic, to make sure neither 
  //channel gets too far ahead of each other.

  //Forward movement occurs when the write channel is valid and ready

  assign wnext = M_AXI_WREADY & axi_wvalid;

  // WVALID logic, similar to the axi_awvalid always block above      
  always @(posedge M_AXI_ACLK) begin
    if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1) begin
      axi_wvalid <= 1'b0;
    end  // If previously not valid, start next transaction              
    else if (~axi_wvalid && start_single_burst_write) begin
      axi_wvalid <= 1'b1;
    end 
	    /* If WREADY and too many writes, throttle WVALID               
	    Once asserted, VALIDs cannot be deasserted, so WVALID           
	    must wait until burst is complete with WLAST */
    else if (wnext && axi_wlast) axi_wvalid <= 1'b0;
    else axi_wvalid <= axi_wvalid;
  end
  always @(posedge M_AXI_ACLK) begin
    if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1) begin
      axi_wlast <= 1'b0;
      // axi_wlast is asserted when the write index   
      // count reaches the penultimate count to synchronize           
      // with the last write data when write_index is b1111           
      // else if (&(write_index[C_TRANSACTIONS_NUM-1:1])&& ~write_index[0] && wnext)  
    end else if (((write_index == C_M_AXI_BURST_LEN-2 && C_M_AXI_BURST_LEN >= 2) && wnext) || (C_M_AXI_BURST_LEN == 1 )) begin
      axi_wlast <= 1'b1;
    end  // Deassrt axi_wlast when the last write data has been          
         // accepted by the slave with a valid response  
    else if (wnext) axi_wlast <= 1'b0;
    else if (axi_wlast && C_M_AXI_BURST_LEN == 1) axi_wlast <= 1'b0;
    else axi_wlast <= axi_wlast;
  end

  /* Burst length counter. Uses extra counter register bit to indicate terminal       
	 count to reduce decode logic */
  always @(posedge M_AXI_ACLK) begin
    if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1 || start_single_burst_write == 1'b1) begin
      write_index <= 0;
    end else if (wnext && (write_index != C_M_AXI_BURST_LEN - 1)) begin
      write_index <= write_index + 1;
    end else write_index <= write_index;
  end





  //----------------------------
  //Write Response (B) Channel
  //----------------------------

  //The write response channel provides feedback that the write has committed
  //to memory. BREADY will occur when all of the data and the write address
  //has arrived and been accepted by the slave.

  //The write issuance (number of outstanding write addresses) is started by 
  //the Address Write transfer, and is completed by a BREADY/BRESP.

  //While negating BREADY will eventually throttle the AWREADY signal, 
  //it is best not to throttle the whole data channel this way.

  //The BRESP bit [1] is used indicate any errors from the interconnect or
  //slave for the entire write burst. This example will capture the error 
  //into the ERROR output. 
  always @(posedge M_AXI_ACLK) begin
    if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1) begin
      axi_bready <= 1'b0;
      // accept/acknowledge bresp with axi_bready by the master
      // when M_AXI_BVALID is asserted by slave
    end else if (M_AXI_BVALID && ~axi_bready) begin
      axi_bready <= 1'b1;
      // deassert after one clock cycle
    end else if (axi_bready) begin
      axi_bready <= 1'b0;
      // retain the previous value
    end else axi_bready <= axi_bready;
  end

  //Flag any write response errors        
  assign write_resp_error = axi_bready & M_AXI_BVALID & M_AXI_BRESP[1];
  always @(posedge M_AXI_ACLK) begin
    if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1) begin
      error_reg <= 1'b0;
    end else if (write_resp_error) begin
      error_reg <= 1'b1;
    end else error_reg <= error_reg;
  end

  always @(posedge M_AXI_ACLK) begin
    if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1) begin
      write_burst_counter <= 'b0;
    end else if (wnext && axi_wlast) begin
      // or (M_AXI_BVALID && axi_bready) condition for burst write inactive
      if (write_burst_counter != WRITE_BEATS_COUNT) begin
        write_burst_counter <= write_burst_counter + 1'b1;
      end
    end else write_burst_counter <= write_burst_counter;
  end


  //implement master command interface state machine        

  always @(posedge M_AXI_ACLK) begin
    if (M_AXI_ARESETN == 1'b0) begin
      // reset condition        
      // All the signals are assigned default values under reset condition
      mst_exec_state           <= IDLE;
      start_single_burst_write <= 1'b0;
      ERROR                    <= 1'b0;
      tx_done                  <= 1'b0;
    end else begin

      // state transition       
      case (mst_exec_state)
        IDLE:
        if (init_txn_pulse == 1'b1) begin
          mst_exec_state <= INIT_WRITE;
          ERROR <= 1'b0;
          tx_done <= 1'b0;
        end else begin
          mst_exec_state <= IDLE;
        end

        INIT_WRITE:
        if ((write_burst_counter == WRITE_BEATS_COUNT)) begin
          mst_exec_state <= IDLE;
          tx_done <= 1'b1;
        end else begin
          mst_exec_state <= INIT_WRITE;
          // note that we add addtional single_sector_burst condition to start the burst write
          // it is a ready signal for single sector read done by sdio_burst_reader
          if (~axi_awvalid && ~start_single_burst_write && ~burst_write_active && single_sector_burst) begin
            start_single_burst_write <= 1'b1;
          end else begin
            start_single_burst_write <= 1'b0;  //Negate to generate a pulse          
          end
        end
      endcase
    end
  end  //MASTER_EXECUTION_PROC     


  // burst_write_active signal is asserted when there is a burst write transaction          
  // is initiated by the assertion of start_single_burst_write. burst_write_active          
  // signal remains asserted until the burst write is accepted by the slave 
  always @(posedge M_AXI_ACLK) begin
    if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1) burst_write_active <= 1'b0;

    //The burst_write_active is asserted when a write burst transaction is initiated        
    else if (start_single_burst_write) burst_write_active <= 1'b1;
    else if (M_AXI_BVALID && axi_bready) burst_write_active <= 0;
  end
endmodule
