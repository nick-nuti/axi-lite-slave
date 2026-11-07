
module axilite_s #(
    parameter ADDR_W=32,
    parameter DATA_W=64
)
(
    aclk,
    aresetn,

// axilite write
    s_axi_awaddr,
    s_axi_awprot,
    s_axi_awvalid,
    s_axi_awready,
    s_axi_wdata,
    s_axi_wstrb,
    s_axi_wvalid,
    s_axi_wready,
    s_axi_bresp,
    s_axi_bvalid,
    s_axi_bready,
// axilite read
    s_axi_araddr,
    s_axi_arprot,
    s_axi_arvalid,
    s_axi_arready,
    s_axi_rready,
    s_axi_rdata,
    s_axi_rvalid,
    s_axi_rresp,
// user write
    w_ready_to_axi,
    w_valid_from_axi,
    
    w_addr_from_axi,
    w_data_from_axi,
    w_strb_from_axi,

    b_ready_from_axi,
    b_valid_to_axi,

    b_resp_to_axi,
// user read
    ar_ready_to_axi,
    ar_valid_from_axi,

    ar_addr_from_axi,
    r_ready_from_axi,
    r_valid_to_axi,

    r_data_to_axi,
    r_resp_to_axi
);

    localparam STRB_W = DATA_W/8;
    localparam RESP_W = 2;

    input logic aclk;
    input logic aresetn;

// axilite write
    input  logic [ADDR_W-1:0]   s_axi_awaddr;
    input  logic [2:0]          s_axi_awprot;
    input  logic                s_axi_awvalid;
    output logic                s_axi_awready;

    input  logic [DATA_W-1:0]   s_axi_wdata;
    input  logic [STRB_W-1:0]   s_axi_wstrb;
    input  logic                s_axi_wvalid;
    output logic                s_axi_wready;

    output logic [RESP_W-1:0]   s_axi_bresp;
    output logic                s_axi_bvalid;
    input  logic                s_axi_bready;
// axilite read
    input  logic [ADDR_W-1:0]   s_axi_araddr;
    input  logic [2:0]          s_axi_arprot;
    input  logic                s_axi_arvalid;
    output logic                s_axi_arready;

    input  logic                s_axi_rready;
    output logic [DATA_W-1:0]   s_axi_rdata;
    output logic                s_axi_rvalid;
    output logic [RESP_W-1:0]   s_axi_rresp;
// user write
    input  logic                w_ready_to_axi;
    output logic                w_valid_from_axi;
    
    output logic [ADDR_W-1:0]   w_addr_from_axi;
    output logic [DATA_W-1:0]   w_data_from_axi;
    output logic [STRB_W-1:0]   w_strb_from_axi;

    output logic                b_ready_from_axi;
    input  logic                b_valid_to_axi;

    input  logic [RESP_W-1:0]   b_resp_to_axi;
// user read
    input  logic                ar_ready_to_axi;
    output logic                ar_valid_from_axi;

    output logic [ADDR_W-1:0]   ar_addr_from_axi;
    
    output logic                r_ready_from_axi;
    input  logic                r_valid_to_axi;

    input  logic [DATA_W-1:0]   r_data_to_axi;
    input  logic [RESP_W-1:0]   r_resp_to_axi;


// write handling
    logic awaddr_received, wdata_received, bresp_received;
    logic [ADDR_W-1:0] awaddr_hold;
    logic [DATA_W-1:0] wdata_hold;
    logic [STRB_W-1:0] wstrb_hold;

    logic [RESP_W-1:0] bresp_hold;

    logic wlock;

    always_ff @ (posedge aclk)
    begin
        if(~aresetn)
        begin
            awaddr_received <= 1'b0;
            awaddr_hold     <= 'h0;

            wdata_received  <= 1'b0;
            wdata_hold      <= 'h0;
            wstrb_hold      <= 'h0;

            bresp_received  <= 1'b0;
            bresp_hold      <= 'h0;

            wlock <= 1'b0;
        end

        else
        begin
        
        // command
            if(s_axi_awvalid && s_axi_awready)
            begin
                awaddr_received <= 1'b1;
                awaddr_hold     <= s_axi_awaddr;
            end
            
            else if(w_valid_from_axi && w_ready_to_axi)
            begin
                awaddr_received <= 1'b0;
            end

            if(s_axi_wvalid && s_axi_wready)
            begin
                wdata_received  <= 1'b1;
                wdata_hold      <= s_axi_wdata;
                wstrb_hold      <= s_axi_wstrb;
            end
            
            else if(w_valid_from_axi && w_ready_to_axi)
            begin
                wdata_received  <= 1'b0;
            end

        // wlock
            if(w_valid_from_axi && w_ready_to_axi)
            begin
                wlock <= 1'b1;
            end

            else if(b_valid_to_axi && b_ready_from_axi)
            begin
                wlock <= 1'b0;
            end

        // resp
            if(b_valid_to_axi && b_ready_from_axi)
            begin
                bresp_received  <= 1'b1;
                bresp_hold      <= b_resp_to_axi;
            end
            
            else if(s_axi_bvalid && s_axi_bready)
            begin
                bresp_received  <= 1'b0;
            end
        end
    end

    always_comb
    begin
        s_axi_awready   = ~awaddr_received;
        s_axi_wready    = ~wdata_received;

        w_valid_from_axi = ~wlock && awaddr_received && wdata_received;
        w_addr_from_axi = awaddr_hold;
        w_data_from_axi = wdata_hold;
        w_strb_from_axi = wstrb_hold;

        b_ready_from_axi = wlock;
        s_axi_bvalid = bresp_received;
        s_axi_bresp = bresp_hold;
    end

// read handling
    logic araddr_received, rresp_received;

    logic [ADDR_W-1:0] araddr_hold;

    logic [DATA_W-1:0] rdata_hold;
    logic [RESP_W-1:0] rresp_hold;

    logic rlock;

    always_ff @ (posedge aclk)
    begin
        if(~aresetn)
        begin
            araddr_received <= 1'b0;
            araddr_hold     <= 'h0;

            rresp_received  <= 1'b0;
            rdata_hold      <= 'h0;
            rresp_hold      <= 'h0;

            rlock <= 1'b0;
        end

        else
        begin
        
        // command
            if(s_axi_arvalid && s_axi_arready)
            begin
                araddr_received <= 1'b1;
                araddr_hold     <= s_axi_araddr;
            end

            else if(ar_valid_from_axi && ar_ready_to_axi)
            begin
                araddr_received <= 1'b0;
            end

        // rlock
            if(ar_valid_from_axi && ar_ready_to_axi)
            begin
                rlock <= 1'b1;
            end

            else if(r_valid_to_axi && r_ready_from_axi)
            begin
                rlock <= 1'b0;
            end

        // resp
            if(r_valid_to_axi && r_ready_from_axi)
            begin
                rresp_received  <= 1'b1;
                rdata_hold      <= r_data_to_axi;
                rresp_hold      <= r_resp_to_axi;
            end

            else if(s_axi_rvalid && s_axi_rready)
            begin
                rresp_received  <= 1'b0;
            end
        end
    end

    always_comb
    begin
        s_axi_arready = ~araddr_received;

        ar_valid_from_axi = ~rlock && araddr_received;
        ar_addr_from_axi = araddr_hold;

        r_ready_from_axi = rlock;
        s_axi_rvalid = rresp_received;
        s_axi_rdata = rdata_hold;
        s_axi_rresp = rresp_hold;
    end

endmodule