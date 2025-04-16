
module top #(
    parameter ADDR_W=32,
    parameter DATA_W=32
)
(
  /**************** Write Address Channel Signals ****************/
  input wire [ADDR_W-1:0]              s_axi_awaddr,
  input wire                           s_axi_awvalid,
  output wire                          s_axi_awready,
  /**************** Write Data Channel Signals ****************/
  input wire [DATA_W-1:0]              s_axi_wdata,
  input wire [(DATA_W/8)-1:0]        s_axi_wstrb,
  input wire                           s_axi_wvalid,
  output wire                          s_axi_wready, 
  /**************** Write Response Channel Signals ****************/
  output wire [2-1:0]                  s_axi_bresp,
  output wire                          s_axi_bvalid,
  input wire                           s_axi_bready,
  /**************** Read Address Channel Signals ****************/
  input wire [ADDR_W-1:0]              s_axi_araddr,
  input wire                           s_axi_arvalid,
  output wire                          s_axi_arready,
  /**************** Read Data Channel Signals ****************/
  input wire                           s_axi_rready,
  output wire [DATA_W-1:0]             s_axi_rdata,
  output wire                          s_axi_rvalid,
  /**************** Read Response Channel Signals ****************/
  output wire [2-1:0]                  s_axi_rresp,
  /**************** System Signals ****************/
  input wire                           aclk,
  input wire                           aresetn
);
    //parameter ADDR_W=32;
    //parameter DATA_W=32;
    parameter BYTE=8;
    parameter DATA_W_BYTES = DATA_W/BYTE;
    parameter MEM_ADDR_START = 'h10000000;
    parameter MEM_ADDR_RANGE = 3;
    parameter MEM_ADDR_END = MEM_ADDR_START + (MEM_ADDR_RANGE*DATA_W_BYTES)-1;
     
wire mem_w_req;
reg  mem_w_ack;
wire mem_r_req;
reg  mem_r_ack;
wire [ADDR_W-1:0] mem_addr;
wire [DATA_W-1:0] mem_w_data;
wire [DATA_W/8-1:0] mem_w_strb;
reg  [DATA_W-1:0] mem_r_data;

axilite_slave #(
    .ADDR_W(ADDR_W),
    .DATA_W(DATA_W)
)
as0
(
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready), 
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rready(s_axi_rready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rresp(s_axi_rresp),
    .aclk(aclk),
    .aresetn(aresetn),
    .mem_w_req(mem_w_req),
    .mem_w_ack(mem_w_ack),
    .mem_r_req(mem_r_req),
    .mem_r_ack(mem_r_ack),
    .mem_addr(mem_addr),
    .mem_w_data(mem_w_data),
    .mem_w_strb(mem_w_strb),
    .mem_r_data(mem_r_data)
);

    // config memory
    reg [ADDR_W-1:0] config_mem [MEM_ADDR_RANGE-1:0];

    //
    
    /*
    typedef struct packed
    {
        logic                 CONFIG_REG_CACHE_ENABLE; // disable/enable entire cache
        logic [9:0]           CONFIG_REG_CACHE_SIZE; // total number of cache lines
        logic [9:0]           CONFIG_REG_CACHE_LINE_SIZE_BYTES; // total number of cache lines
        logic                 CONFIG_REG_CACHE_INVALIDATE; // invalidate whole cache; value will toggle 1 then result back to 0
    } CONFIG_REG0_TYPE;
    
    typedef struct packed
    {
        logic [ADDR_W-1:0]    CONFIG_REG_CACHE_SMART_INVALIDATE; // smart invalidate address (32 bits)
    } CONFIG_REG1_TYPE;
    
    CONFIG_REG0_TYPE config_reg0;
    localparam CONFIG_REG0_ADDR = MEM_ADDR_START + 0 * DATA_W_BYTES;
    
    CONFIG_REG1_TYPE config_reg1;
    localparam CONFIG_REG1_ADDR = MEM_ADDR_START + 1 * DATA_W_BYTES;
    
    assign config_reg0 = config_mem[0];
    assign config_reg1 = config_mem[1];
    */
    //
    
    parameter CONFIG_REG0_ADDR = MEM_ADDR_START + 0 * DATA_W_BYTES;
    wire                 CONFIG_REG_CACHE_ENABLE; // disable/enable entire cache
    wire [9:0]           CONFIG_REG_CACHE_SIZE; // total number of cache lines
    wire [9:0]           CONFIG_REG_CACHE_LINE_SIZE_BYTES; // total number of cache lines
    wire                 CONFIG_REG_CACHE_INVALIDATE; // invalidate whole cache; value will toggle 1 then result back to 0
    assign {CONFIG_REG_CACHE_INVALIDATE,CONFIG_REG_CACHE_LINE_SIZE_BYTES,CONFIG_REG_CACHE_SIZE,CONFIG_REG_CACHE_ENABLE} = config_mem[0];
        
    parameter CONFIG_REG1_ADDR = MEM_ADDR_START + 1 * DATA_W_BYTES;
    wire [ADDR_W-1:0]    CONFIG_REG_CACHE_SMART_INVALIDATE; // smart invalidate address (32 bits)
    assign {CONFIG_REG_CACHE_SMART_INVALIDATE} = config_mem[1];
    
    parameter STATUS_REG1_ADDR = MEM_ADDR_START + 2 * DATA_W_BYTES;
    wire [ADDR_W-1:0]    STATUS_REG_CACHE;
    assign {STATUS_REG_CACHE} = config_mem[2];
    
    // use this when there's a lot more registers
  /*  
    always@(posedge aclk)
    begin
        mem_w_ack <= 1'b0;
    
        if(~aresetn)
        begin
            config_mem[0] <= 32'h0;
            config_mem[1] <= 32'h0;
            config_mem[2] <= 32'h0;
        end
    
        else
        begin
            if(mem_w_req)
            begin
                mem_w_ack <= 1'b1;
                
                if
                if(mem_w_strb[0]) config_mem[(mem_addr - MEM_ADDR_START)>>2][7:0]   <= mem_w_data[7:0];
                if(mem_w_strb[1]) config_mem[(mem_addr - MEM_ADDR_START)>>2][15:8]  <= mem_w_data[15:8];
                if(mem_w_strb[2]) config_mem[(mem_addr - MEM_ADDR_START)>>2][23:16] <= mem_w_data[23:16];
                if(mem_w_strb[3]) config_mem[(mem_addr - MEM_ADDR_START)>>2][31:24] <= mem_w_data[31:24];

            end
        end
    end
*/

    always@(posedge aclk)
    begin
        if(~aresetn)
        begin
            config_mem[0] <= 32'h0;
            config_mem[1] <= 32'h0;
            config_mem[2] <= 32'h0;
            
        end
    
        else
        begin
            if(mem_w_req)
            begin
                mem_w_ack <= 1'b1;

                case(mem_addr)
                CONFIG_REG0_ADDR: 
                begin
                    if(mem_w_strb[0]) config_mem[0][7:0]   <= mem_w_data[7:0];
                    if(mem_w_strb[1]) config_mem[0][15:8]  <= mem_w_data[15:8];
                    if(mem_w_strb[2]) config_mem[0][23:16] <= mem_w_data[23:16];
                    if(mem_w_strb[3]) config_mem[0][31:24] <= mem_w_data[31:24];
                end

                CONFIG_REG1_ADDR:
                begin
                    if(mem_w_strb[0]) config_mem[1][7:0]   <= mem_w_data[7:0];
                    if(mem_w_strb[1]) config_mem[1][15:8]  <= mem_w_data[15:8];
                    if(mem_w_strb[2]) config_mem[1][23:16] <= mem_w_data[23:16];
                    if(mem_w_strb[3]) config_mem[1][31:24] <= mem_w_data[31:24];
                end
                
                STATUS_REG1_ADDR:
                begin
                    if(mem_w_strb[0]) config_mem[2][7:0]   <= mem_w_data[7:0];
                    if(mem_w_strb[1]) config_mem[2][15:8]  <= mem_w_data[15:8];
                    if(mem_w_strb[2]) config_mem[2][23:16] <= mem_w_data[23:16];
                    if(mem_w_strb[3]) config_mem[2][31:24] <= mem_w_data[31:24];
                end
                endcase
            end

            else
            begin
                mem_w_ack <= 1'b0;
            end
        end
    end

// READ
    always@(posedge aclk)
    begin
        if(mem_r_req)
        begin
            mem_r_ack <= 1'b1;

            case(mem_addr)
            CONFIG_REG0_ADDR: mem_r_data <= config_mem[0];
            CONFIG_REG1_ADDR: mem_r_data <= config_mem[1];
            STATUS_REG1_ADDR: mem_r_data <= config_mem[2];
            default: mem_r_data <= 'hBAD;
            endcase
        end

        else
        begin
            mem_r_ack <= 1'b0;
        end
    end

endmodule
