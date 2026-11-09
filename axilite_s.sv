/*
axilite_s #(
    .ADDR_W(32), 
    .DATA_W(64),
    .AUTO_ALIGN(1),
    .MEM_BOUNDARY_BYTES(4096)
) as0 
(
    .aclk(),
    .aresetn(),

// axilite write
    .s_axi_awaddr(),
    .s_axi_awprot(),
    .s_axi_awvalid(),
    .s_axi_awready(),
    .s_axi_wdata(),
    .s_axi_wstrb(),
    .s_axi_wvalid(),
    .s_axi_wready(),
    .s_axi_bresp(),
    .s_axi_bvalid(),
    .s_axi_bready(),
// axilite read
    .s_axi_araddr(),
    .s_axi_arprot(),
    .s_axi_arvalid(),
    .s_axi_arready(),
    .s_axi_rready(),
    .s_axi_rdata(),
    .s_axi_rvalid(),
    .s_axi_rresp(),
// user write
    .w_ready_to_axi(),
    .w_valid_from_axi(),
    
    .w_addr_from_axi(),
    .w_data_from_axi(),
    .w_strb_from_axi(),

    .b_ready_from_axi(),
    .b_valid_to_axi(),

    .b_resp_to_axi(),
// user read
    .ar_ready_to_axi(),
    .ar_valid_from_axi(),

    .ar_addr_from_axi(),
    .r_ready_from_axi(),
    .r_valid_to_axi(),

    .r_data_to_axi(),
    .r_resp_to_axi()
);
*/

module axilite_s #(
    parameter ADDR_W=32,
    parameter DATA_W=64,
    parameter AUTO_ALIGN=1,
    parameter MEM_BOUNDARY_BYTES=4096
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

    localparam ALIGN_TRANSACTION = (AUTO_ALIGN > 0) ? 1 : 0;
    
    localparam MEM_BOUNDARY_BYTES_CLOG2 = $clog2(MEM_BOUNDARY_BYTES);

    localparam DATA_W_BYTES = DATA_W / 8;
    localparam DATA_W_BYTES_CLOG2 = $clog2(DATA_W_BYTES);

// write handling
    logic awaddr_received, wdata_received, bresp_received;
    logic [ADDR_W-1:0] awaddr_hold;
    logic [DATA_W-1:0] wdata_hold;
    logic [STRB_W-1:0] wstrb_hold;
    logic [RESP_W-1:0] bresp_hold;

    // auto align components
    logic wdata_raw_received;
    logic [DATA_W-1:0] wdata_raw_hold;
    logic [STRB_W-1:0] wstrb_raw_hold;
    logic [DATA_W_BYTES_CLOG2-1:0] awaddr_raw_align;

    logic wlock;

    logic [MEM_BOUNDARY_BYTES_CLOG2:0] w_boundary_check;
    logic w_boundary_violation;

    logic w_error_detected;

    always_ff @ (posedge aclk)
    begin
        if(~aresetn)
        begin
            awaddr_received <= 1'b0;
            awaddr_hold     <= 'h0;

            wdata_received  <= 1'b0;
            wdata_hold      <= 'h0;
            wstrb_hold      <= 'h0;

            // auto align components
            wdata_raw_received  <= 1'b0;
            wdata_raw_hold      <= 'h0;
            wstrb_raw_hold      <= 'h0;

            bresp_received  <= 1'b0;
            bresp_hold      <= 'h0;

            wlock <= 1'b0;
        end

        else
        begin
        // waddr
            if(s_axi_awvalid && s_axi_awready)
            begin
                awaddr_received <= 1'b1;
                awaddr_hold     <= s_axi_awaddr;
            end
            
            else if((w_valid_from_axi && w_ready_to_axi) || w_error_detected)
            begin
                awaddr_received <= 1'b0;
            end

        // wdata auto align
            if(ALIGN_TRANSACTION)
            begin
                if(s_axi_wvalid && s_axi_wready)
                begin
                    if(awaddr_received)
                    begin
                        wdata_received  <= 1'b1;
                        wdata_hold      <= s_axi_wdata >> (awaddr_raw_align*8);
                        wstrb_hold      <= s_axi_wstrb >> awaddr_raw_align;
                    end

                    else
                    begin
                        wdata_raw_received  <= 1'b1;
                        wdata_raw_hold      <= s_axi_wdata;
                        wstrb_raw_hold      <= s_axi_wstrb;
                    end
                end

                else if(wdata_raw_received)
                begin
                    if(s_axi_awvalid && s_axi_awready)
                    begin
                        wdata_raw_received  <= 1'b0;

                        wdata_received  <= 1'b1;
                        wdata_hold      <= wdata_raw_hold >> ((s_axi_awaddr[DATA_W_BYTES_CLOG2-1:0])*8); // awaddr_hold flop isn't ready at this point, so use the input combi val
                        wstrb_hold      <= wstrb_raw_hold >> (s_axi_awaddr[DATA_W_BYTES_CLOG2-1:0]); // awaddr_hold flop isn't ready at this point, so use the input combi val
                    end
                end
                
                else if((w_valid_from_axi && w_ready_to_axi) || w_error_detected)
                begin
                    wdata_received  <= 1'b0;
                end
            end

        // wdata raw
            else
            begin
                if(s_axi_wvalid && s_axi_wready)
                begin
                    wdata_received  <= 1'b1;
                    wdata_hold      <= s_axi_wdata;
                    wstrb_hold      <= s_axi_wstrb;
                end
                
                else if((w_valid_from_axi && w_ready_to_axi) || w_error_detected)
                begin
                    wdata_received  <= 1'b0;
                end
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

            else if(w_error_detected)
            begin
                bresp_received  <= 1'b1;
                bresp_hold      <= 2'b10;
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

        awaddr_raw_align = (~ALIGN_TRANSACTION) ? 1'b0 : awaddr_hold[DATA_W_BYTES_CLOG2-1:0];

        w_addr_from_axi = (~ALIGN_TRANSACTION) ? awaddr_hold : {awaddr_hold[ADDR_W-1:DATA_W_BYTES_CLOG2],{DATA_W_BYTES_CLOG2{1'b0}}};
        w_data_from_axi = wdata_hold;
        w_strb_from_axi = wstrb_hold;

        w_valid_from_axi = ~wlock && awaddr_received && wdata_received && ~w_boundary_violation;

        b_ready_from_axi = wlock && ~bresp_received;
        s_axi_bvalid = bresp_received;
        s_axi_bresp = bresp_hold;

        if(ALIGN_TRANSACTION)
        begin
            w_boundary_check = {1'b0, ({awaddr_hold[MEM_BOUNDARY_BYTES_CLOG2-1:DATA_W_BYTES_CLOG2], {(DATA_W_BYTES_CLOG2-1){1'b0}}})} + (DATA_W_BYTES-1);
        end

        else
        begin
            w_boundary_check = {1'b0, awaddr_hold[MEM_BOUNDARY_BYTES_CLOG2-1:0]} + (DATA_W_BYTES-1);
        end
    
        w_boundary_violation = w_boundary_check[MEM_BOUNDARY_BYTES_CLOG2];

        w_error_detected = (w_boundary_violation & ~wlock) && awaddr_received && wdata_received && ~bresp_received;
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
