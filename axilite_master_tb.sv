`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/02/2024 11:48:24 PM
// Design Name: 
// Module Name: axi_traffic_gen_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//
//
//
//

module axilite_master_tb();

//
reg aclk;
reg aresetn;
wire aresetn_out;
//


`define BYTE_SIZE 8
`define ADDR_W 32
`define DATA_W 32
`define STRB_SIZE (`DATA_W/`BYTE_SIZE)
`define NUM_TRANSACTIONS 3

reg  [`ADDR_W-1:0] u_addr [0:`NUM_TRANSACTIONS-1] = 
{
    'h10000000,
    'h10000004, //0
    'h10000008 //0
};

bit  [`DATA_W-1:0] u_data_in [0:`NUM_TRANSACTIONS-1] =
{
'h23124,
'hF0F0F0F0,
'hAAAAAAAA
};

bit  [`DATA_W-1:0] u_data_out [0:`NUM_TRANSACTIONS-1];

bit  [`DATA_W-1:0] cmp_data_diff;
bit  [`DATA_W-1:0] strb_val;
bit  [`DATA_W-1:0] strb_data_in, strb_data_out;


reg   [`STRB_SIZE-1:0] w_strb [0:`NUM_TRANSACTIONS-1] =
{
'b1111,
'b1110,
'b0101
};

reg         user_start;

wire        user_free;
wire [1:0]  user_status;
//

reg  [`ADDR_W-1:0] user_addr_in;
bit  [`DATA_W-1:0] user_data_in;
bit  [`DATA_W-1:0] user_data_out;
reg         user_data_out_en;
reg  [7:0]  user_w_strb;
int         running_index;
//
reg axi_ready;
//
reg user_w_r;
//
reg compare_w_r_arrays;
int cmp_it;
longint current_addr;

integer file, i;

initial
begin
    aclk = 0;
    aresetn = 0;
    user_addr_in = 'h0;
    user_data_in = 'h0;
    user_w_strb = 'h0;
    user_start = 'h0;
    user_w_r = 'h0;
    compare_w_r_arrays = 0;
end

always
begin
    #8ns aclk = ~aclk;
end

initial
begin
    wait(aclk);
    aresetn = 1;
    #5us;
    
    #10us;

//AXI WRITES    
    user_start      = 1'd0;
    
    //#5ms;
    @(posedge aclk);
    
    for(int i = 0; i < `NUM_TRANSACTIONS; i++)
    begin
        wait(user_free);
        //@(posedge aclk);
        
        user_addr_in        = u_addr[i];
        user_w_strb         = w_strb[i];
        user_data_in        = u_data_in[i];
        user_start          = 1'd1;
        
        @(posedge aclk);
        
        user_start          = 1'd0;
        
        @(posedge aclk);
    end
    
    #5us; 
    
//AXI READS
    @(posedge aclk);
    user_start      = 1'd0;
    user_w_r = 'h1;
    @(posedge aclk);

    fork
        begin
            for(int i = 0; i < `NUM_TRANSACTIONS; i++)
            begin
                wait(user_free);
            
                user_addr_in        = u_addr[i];
                user_start          = 1'd1;
        
                @(posedge aclk);
                user_start          = 1'd0;
                @(posedge aclk);
            end
        end
        
        begin
            for(int i = 0; i < `NUM_TRANSACTIONS; i++)
            begin
                @(posedge user_data_out_en);
                u_data_out[i] = user_data_out;
            end            
        end
    join

//////////////////////////////////////////////////////////////////////////////////    
    
    #10us;
    
    current_addr = 0;

    for(cmp_it = 0; cmp_it < `NUM_TRANSACTIONS; cmp_it++)
    begin
    
        current_addr = u_addr[cmp_it];
        strb_val = 'd0;
        
        for(int y = `STRB_SIZE; y >= 0; y--)
        begin
            strb_val = (strb_val << 8) | ((w_strb[cmp_it][y]) ? 8'hFF : 8'h0);
        end
        
        strb_data_in = u_data_in[cmp_it] & strb_val;
        strb_data_out = u_data_out[cmp_it] & strb_val;
        cmp_data_diff = (strb_data_in) ^ (strb_data_out);
            
        if(|cmp_data_diff)
        begin
            $display("ADDRESS:0x%X, DATA WRITTEN:0x%X -> DATA WRITTEN w/ STROBE(0b%b): 0x%X, DATA READ: 0x%X, NOT EQUAL", current_addr, u_data_in[cmp_it], w_strb[cmp_it], strb_data_in, strb_data_out);
        end
        
        else
        begin
            $display("ADDRESS:0x%X, DATA WRITTEN:0x%X -> DATA WRITTEN w/ STROBE(0b%b): 0x%X, DATA READ: 0x%X, EQUAL", current_addr, u_data_in[cmp_it], w_strb[cmp_it], strb_data_in, strb_data_out);
        end
    end
    
    $finish;
end
    
design_1_wrapper d1w0(
    .aclk_0(aclk),
    .aresetn_0(aresetn),
    .user_start_0(user_start),
    .user_w_r_0(user_w_r),
    .user_data_strb_0(user_w_strb),
    .user_data_in_0(user_data_in),
    .user_addr_in_0(user_addr_in),
    .user_free_0(user_free),
    .user_status_0(user_status),
    .user_data_out_0(user_data_out),
    .user_data_out_valid_0(user_data_out_en)
    );

endmodule
