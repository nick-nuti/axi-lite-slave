

module axilite_master #(
    parameter ADDR_W=32,
    parameter DATA_W=64
)
(
  /**************** Write Address Channel Signals ****************/
  output reg [ADDR_W-1:0]              m_axi_awaddr, // address (done)
  output reg [3-1:0]                   m_axi_awprot = 3'b000, // protection - privilege and securit level of transaction
  output reg                           m_axi_awvalid, // (done)
  input  wire                          m_axi_awready, // (done)
  /**************** Write Data Channel Signals ****************/
  output reg [DATA_W-1:0]              m_axi_wdata, // (done)
  output reg [DATA_W/8-1:0]            m_axi_wstrb, // (done)
  output reg                           m_axi_wvalid, // set to 1 when data is ready to be transferred (done)
  input  wire                          m_axi_wready, // (done)
  /**************** Write Response Channel Signals ****************/
  input  wire [2-1:0]                  m_axi_bresp, // (done) write response - status of the write transaction (00 = okay, 01 = exokay, 10 = slverr, 11 = decerr)
  input  wire                          m_axi_bvalid, // (done) write response valid - 0 = response not valid, 1 = response is valid
  output reg                           m_axi_bready, // (done) write response ready - 0 = not ready, 1 = ready
  /**************** Read Address Channel Signals ****************/
  output reg [ADDR_W-1:0]              m_axi_araddr, // address
  output reg [3-1:0]                   m_axi_arprot = 3'b000, // protection - privilege and securit level of transaction
  output reg                           m_axi_arvalid, // 
  input  wire                          m_axi_arready, // 
  /**************** Read Data Channel Signals ****************/
  output reg                           m_axi_rready, // read ready - 0 = not ready, 1 = ready
  input  wire [DATA_W-1:0]             m_axi_rdata, // 
  input  wire                          m_axi_rvalid, // read response valid - 0 = response not valid, 1 = response is valid
  /**************** Read Response Channel Signals ****************/
  input  wire [2-1:0]                  m_axi_rresp, // read response - status of the read transaction (00 = okay, 01 = exokay, 10 = slverr, 11 = decerr)
  /**************** System Signals ****************/
  input wire                           aclk,
  input wire                           aresetn,
  /**************** User Control Signals ****************/
  input  wire                          user_start,
  input  wire                          user_w_r, // 0 = write, 1 = read
  input  wire [DATA_W/8-1:0]           user_data_strb,
  input  wire [DATA_W-1:0]             user_data_in,
  input  wire [ADDR_W-1:0]             user_addr_in,
  output wire                          user_free,
  output wire  [1:0]                   user_status,
  output wire  [DATA_W-1:0]            user_data_out,
  output wire                          user_data_out_valid,
  output wire                          user_w_r_out,
  output wire [ADDR_W-1:0]             user_addr_out
);

// AXI FSM ---------------------------------------------------
    localparam IDLE             = 3'b000;
    localparam ADDRESS          = 3'b001;
    localparam WRITE            = 3'b010;
    localparam WRITE_RESPONSE   = 3'b011;
    localparam READ_RESPONSE    = 3'b100;
    
    wire start_wire;
       
    reg [2:0] axi_cs, axi_ns;
    
            always @ (posedge aclk or negedge aresetn)
            begin
                if(~aresetn)
                begin
                    axi_cs <= IDLE;
                end
               
                else
                begin
                    axi_cs <= axi_ns;
                end
            end
           
            always @ (*)
            begin
                case(axi_cs)
                IDLE:
                begin
                    if(start_wire)
                    begin
                        axi_ns = ADDRESS;
                    end
        
                    else
                    begin
                        axi_ns = IDLE;
                    end
                end
        
                ADDRESS:
                begin
                    if(~user_w_r_ff) // WRITE
                    begin
                        if(m_axi_awready)   axi_ns = WRITE;
                        else                axi_ns = ADDRESS;
                    end
        
                    else // READ
                    begin
                        if(m_axi_arready)  axi_ns = READ_RESPONSE;
                        else               axi_ns = ADDRESS;
                    end
                end
               
                WRITE:
                begin
                    if(m_axi_wready)    axi_ns = WRITE_RESPONSE;
                    else                axi_ns = WRITE;
                end
               
                WRITE_RESPONSE:
                begin
                    if(m_axi_bvalid)
                    begin
                        if(start_wire)      axi_ns = ADDRESS;
                        else                axi_ns = IDLE;
                    end
        
                    else                    axi_ns = WRITE_RESPONSE;
                end
        
                READ_RESPONSE:
                begin
                    if(m_axi_rvalid)
                    begin
                        if(start_wire)   axi_ns = ADDRESS;
                        else                axi_ns = IDLE;
                    end
        
                    else                    axi_ns = READ_RESPONSE;
                end
               
                default: axi_ns = IDLE;
                endcase
            end

// FLOPPED USER COMMUNICATION ---------------------------------------------------
    reg                         user_w_r_ff;
    reg [DATA_W/8-1:0]          user_data_strb_ff;
    reg [DATA_W-1:0]            user_data_in_ff;
    reg [ADDR_W-1:0]            user_addr_in_ff;
    reg                         user_status_ff; //(done)
    reg [DATA_W-1:0]            user_data_out_ff; //(done)
    reg                         user_data_out_valid_ff; //(done)
    reg                         user_w_r_out_ff;
    reg [ADDR_W-1:0]            user_addr_out_ff;
    
// System for locking-in next operation via flops
    reg                         ready_flag;
    reg                         start_ff;
    wire                        user_next_feed_in;

    assign start_wire = start_ff;

    always @ (posedge aclk or negedge aresetn)
    begin
        if(~aresetn)
        begin
            ready_flag          <= 1;
            start_ff            <= 0;
            //
            user_w_r_ff             <= 0;
            user_data_strb_ff       <= 0;
            user_data_in_ff         <= 0;
            user_addr_in_ff         <= 0;
        end
        
        else
        begin
            if(ready_flag & user_start)
            begin
                ready_flag      <= 0;
                start_ff        <= 1;
                //
                user_w_r_ff         <= user_w_r;
                user_data_strb_ff   <= (~user_w_r) ? user_data_strb : 0;
                user_data_in_ff     <= (~user_w_r) ? user_data_in : 0;
                user_addr_in_ff     <= user_addr_in;
            end
            
            else if(user_next_feed_in & start_ff)
            begin
                ready_flag      <= 1;
                start_ff        <= 0;
            end
        end
    end
    
    assign user_next_feed_in   = (((axi_cs == WRITE_RESPONSE) && (m_axi_bvalid)) || ((axi_cs == READ_RESPONSE) && (m_axi_rvalid)) || (axi_cs == IDLE)) ? 1 : 0;
    assign user_free           = (((axi_ns == WRITE_RESPONSE) || (axi_ns == READ_RESPONSE) || (axi_ns == IDLE)) && ~start_ff) ? 1 : 0;
// System for locking-in next operation via flops ^^^

// READ data out, data out enable, status out
    always @ (posedge aclk or negedge aresetn)
    begin
        if(~aresetn)
        begin
            user_status_ff          <= 0;
            user_data_out_ff        <= 0;
            user_data_out_valid_ff  <= 0;
	        user_w_r_out_ff         <= 0;
            user_addr_out_ff        <= 0;
        end
       
        else
        begin
            if(axi_cs == ADDRESS)
            begin
                user_data_out_ff        <= 0;
                user_data_out_valid_ff  <= 0;

                user_status_ff          <= 0;

		        user_w_r_out_ff         <= user_w_r_ff;
                user_addr_out_ff        <= user_addr_in_ff;
            end
            
            else if(axi_cs == WRITE_RESPONSE && m_axi_bvalid)
            begin
                user_data_out_valid_ff  <= 1;
            
                user_status_ff  <= m_axi_bresp;
            end
            
            else if(axi_cs == READ_RESPONSE && m_axi_rvalid)
            begin
                user_data_out_ff        <= m_axi_rdata;
                user_data_out_valid_ff  <= 1;

                user_status_ff          <= m_axi_rresp;
            end
        end
    end

    assign user_status         = user_status_ff;
    assign user_data_out       = user_data_out_ff;
    assign user_data_out_valid = user_data_out_valid_ff;
    assign user_w_r_out        = user_w_r_out_ff;
    assign user_addr_out       = user_addr_out_ff;
// READ data out, data out enable, status out ^^^

// AXI WRITE ---------------------------------------------------
    always @ (*)
    begin
     m_axi_awvalid <= ((axi_cs==ADDRESS) && (~user_w_r_ff)) ? 1 : 0;
     m_axi_awaddr  <= ((axi_cs==ADDRESS) && (~user_w_r_ff)) ? user_addr_in_ff : 0;
     m_axi_wvalid  <= (axi_cs==WRITE) ? 1 : 0;
     m_axi_wdata   <= (axi_cs==WRITE) ? user_data_in_ff : 0;
     m_axi_wstrb   <= (axi_cs==WRITE) ? user_data_strb_ff : 0;
     m_axi_bready  <= ((axi_cs == WRITE_RESPONSE) || (axi_ns == WRITE_RESPONSE)) ? 1 : 0;
    end

// AXI READ ---------------------------------------------------
    always @ (*)
    begin
     m_axi_araddr      <= ((axi_cs==ADDRESS) && (user_w_r_ff)) ? user_addr_in_ff : 0;
     m_axi_arvalid     <= ((axi_cs==ADDRESS) && (user_w_r_ff)) ? 1 : 0;
     m_axi_rready      <= ((axi_cs==READ_RESPONSE) || (axi_ns==READ_RESPONSE)) ? 1 : 0;
    end
endmodule
