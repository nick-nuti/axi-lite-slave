
module axilite_slave #(
    parameter ADDR_W=32,
    parameter DATA_W=64,
    parameter MEM_ADDR_START='h10000000,
    parameter MEM_ADDR_RANGE=5
)
(
  /**************** Write Address Channel Signals ****************/
  input wire [ADDR_W-1:0]              s_axi_awaddr,
  input wire                           s_axi_awvalid,
  output reg                           s_axi_awready,
  /**************** Write Data Channel Signals ****************/
  input wire [DATA_W-1:0]              s_axi_wdata,
  input wire [DATA_W/8-1:0]            s_axi_wstrb,
  input wire                           s_axi_wvalid,
  output reg                           s_axi_wready, 
  /**************** Write Response Channel Signals ****************/
  output reg [2-1:0]                   s_axi_bresp,
  output reg                           s_axi_bvalid,
  input wire                           s_axi_bready,
  /**************** Read Address Channel Signals ****************/
  input wire [ADDR_W-1:0]              s_axi_araddr,
  input wire                           s_axi_arvalid,
  output reg                           s_axi_arready,
  /**************** Read Data Channel Signals ****************/
  input wire                           s_axi_rready,
  output reg [DATA_W-1:0]              s_axi_rdata,
  output reg                           s_axi_rvalid,
  /**************** Read Response Channel Signals ****************/
  output reg [2-1:0]                   s_axi_rresp,
  /**************** System Signals ****************/
  input wire                           aclk,
  input wire                           aresetn,
  /**************** Slave IP Signals ****************/
  output reg mem_w_req,
  input wire mem_w_ack,
  output reg mem_r_req,
  input wire mem_r_ack,
  output reg [ADDR_W-1:0] mem_addr,
  output reg [DATA_W-1:0] mem_w_data,
  output reg [DATA_W/8-1:0] mem_w_strb,
  input wire [DATA_W-1:0] mem_r_data
);

// AXI FSM ---------------------------------------------------
    localparam IDLE             = 5'b00001;
    localparam ADDRESS          = 5'b00010;
    localparam WRITE            = 5'b00100;
    localparam WRITE_RESPONSE   = 5'b01000;
    localparam READ_RESPONSE    = 5'b10000;
    
    wire system_w_ready;
    wire system_r_ready;

    assign system_w_ready = (s_axi_bready && mem_w_ack);
    assign system_r_ready = (s_axi_rready && mem_r_ack);
       
    reg [4:0] axi_cs, axi_ns;
    
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
            axi_ns = ADDRESS;
        end

        ADDRESS:
        begin
            if(s_axi_awvalid)
            begin
                if(s_axi_wvalid)
                begin
                    axi_ns = WRITE_RESPONSE;
                end

                else axi_ns = WRITE;
            end

            else if(s_axi_arvalid)
            begin
                axi_ns = READ_RESPONSE;
            end

            else axi_ns = ADDRESS;
        end
        
        WRITE:
        begin
            if(s_axi_wvalid) axi_ns = WRITE_RESPONSE;
            else axi_ns = WRITE;
        end
        
        WRITE_RESPONSE:
        begin
            if(system_w_ready)
            begin
                axi_ns = ADDRESS;
            end

            else axi_ns = WRITE_RESPONSE;
        end

        READ_RESPONSE:
        begin
            if(system_r_ready)
            begin
                axi_ns = ADDRESS;
            end

            else axi_ns = READ_RESPONSE;
        end
        
        default: axi_ns = IDLE;
        endcase
    end

// ADDRESS
    always@(posedge aclk)
    begin
        if(~aresetn)
        begin
            mem_addr <= 'h0;
        end

        else
        begin
            if((axi_cs == ADDRESS) && s_axi_awvalid) mem_addr <= s_axi_awaddr;
            else if((axi_cs == ADDRESS) && s_axi_arvalid) mem_addr <= s_axi_araddr;
            else mem_addr <= mem_addr;
        end
    end

// WRITE
    always@(posedge aclk)
    begin
        if(~aresetn)
        begin
            mem_w_data <= 'h0;
            mem_w_strb <= 'h0;
            mem_w_req <= 'h0;
        end

        else
        begin
            if(s_axi_wvalid && (axi_cs == ADDRESS || axi_cs == WRITE))
            begin
                mem_w_data <= s_axi_wdata;
                mem_w_strb <= s_axi_wstrb;
                mem_w_req <= 'h1;
            end

            else
            begin
                if(system_w_ready) mem_w_req <= 1'b0;
                else mem_w_req <= mem_w_req;

                mem_w_data <= mem_w_data;
                mem_w_strb <= mem_w_strb;
            end
        end
    end

    always@(*)
    begin
        s_axi_awready <= (axi_cs == ADDRESS || system_w_ready) ? 'h1 : 'h0;
        s_axi_wready <= (axi_cs == ADDRESS || axi_cs == WRITE || system_w_ready) ? 'h1 : 'h0;
        s_axi_bvalid <= (axi_cs == WRITE_RESPONSE && mem_w_ack) ? 'h1 : 'h0;
        s_axi_bresp <= 'h0; // forcing to zero for now
    end


// READ
    reg [DATA_W-1:0] mem_r_data_ff;

    always@(posedge aclk)
    begin
        if(~aresetn)
        begin
            //mem_r_data_ff <= 'h0;
            mem_r_req <= 'h0;
        end

        else
        begin
            if(s_axi_arvalid && axi_cs == ADDRESS)
            begin
                //mem_r_data_ff <= mem_r_data_ff;
                mem_r_req <= 'h1;
            end

            else
            begin
                if(mem_r_ack)
                begin
                    //mem_r_data_ff <= mem_r_data;

                    if(s_axi_rready)
                    begin
                        mem_r_req <= 1'b0;
                    end

                    else mem_r_req <= 1'b1;

                end

                else
                begin
                    //mem_r_data_ff <= mem_r_data_ff;
                    mem_r_req <= mem_r_req;
                end
            end
        end
    end

    always@(*)
    begin
        s_axi_arready <= (axi_cs == ADDRESS || system_r_ready) ? 'h1 : 'h0;
        s_axi_rdata <= (axi_cs == READ_RESPONSE && mem_r_ack) ? mem_r_data : 'h0;//mem_r_data_ff : 'h0;
        s_axi_rvalid <= (axi_cs == READ_RESPONSE && mem_r_ack) ? 'h1 : 'h0;
        s_axi_rresp <= 'h0; // forcing to zero for now
    end


endmodule
