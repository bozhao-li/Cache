`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/18 10:24:20
// Design Name: 
// Module Name: DCache_pipeline_init_sim
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


module DCache_pipeline_init_sim();

parameter DLY = 0.1;
reg clk = 1'b0;
reg rst = 1'b0;

reg iuncache_i = 1'b0;
wire stall_o;

reg rvalid_i;
reg [31:0] paddr_i;
reg wvalid_i;
reg [3:0] wsel_i;
reg [31:0] wdata_i;

wire data_ok_o;
wire [31:0] rdata_o;

reg [4:0] dcache_op_i;
reg [31:0] dcache_cdata_i;

wire [7:0] rd_len;
wire rd_req_o;
wire [31:0] rd_addr_o;
reg  ret_valid_i;
reg [127:0] ret_data_i;

wire [7:0] wr_len;
wire wr_req_o;
wire [31:0] wr_addr_o;
wire [127:0] wr_data_o;
reg wr_valid_i;

wire [255:0] de_dirty_way0;
wire [255:0] de_dirty_way1;
wire hit_o;


reg iuncache_i_i = 1'b0;
reg rvalid_i_i = 1'b0;
reg [31:0] vaddr_i_i = 32'b0;
reg [31:0] paddr_i_i = 32'b0;
reg wvalid_i_i = 1'b0;
reg [3:0] wsel_i_i = 4'b0;
reg [31:0] wdata_i_i =  32'b0;
reg ret_valid_i_i = 1'b0;
reg [127:0] ret_data_i_i = 128'b0;
reg wr_valid_i_i = 1'b0;
reg [4:0] dcache_op_i_i = 5'b0;
reg [31:0] dcache_cdata_i_i = 32'b0;

always @(posedge clk) begin
    if (rst) begin
        iuncache_i <= #DLY 0;
        rvalid_i <= #DLY 0;
        paddr_i <= #DLY 0;
        wvalid_i <= #DLY 0;
        wsel_i <= #DLY 0;
        wdata_i <= #DLY 0;
        ret_valid_i <= #DLY 0;
        ret_data_i <= #DLY 0;
        wr_valid_i <= #DLY 0;
        dcache_op_i <= #DLY 0;
        dcache_cdata_i <= #DLY 0;
    end else begin
        iuncache_i <= #DLY iuncache_i_i;
        rvalid_i <= #DLY rvalid_i_i;
        paddr_i <= #DLY paddr_i_i;
        wvalid_i <= #DLY wvalid_i_i;
        wsel_i <= #DLY wsel_i_i;
        wdata_i <= #DLY wdata_i_i;
        ret_valid_i <= #DLY ret_valid_i_i;
        ret_data_i <= #DLY ret_data_i_i;
        wr_valid_i <= #DLY wr_valid_i_i;
        dcache_op_i <= #DLY dcache_op_i_i;
        dcache_cdata_i <= #DLY dcache_cdata_i_i;
    end
end

DCache_pipeline DCache_pipeline_u(.clk(clk), .rst(rst), 
                                  .duncache_i(iuncache_i), .stall_o(stall_o),
                                  
                                  .rvalid_i(rvalid_i), .paddr_i(paddr_i), 
                                  .wvalid_i(wvalid_i), .wsel_i(wsel_i), .wdata_i(wdata_i), 
                                  .data_ok_o(data_ok_o), .rdata_o(rdata_o),
                                  
                                  .dcache_op_i(dcache_op_i), .dcache_cdata_i(dcache_cdata_i), 
                                  
                                  .rd_len(rd_len), .rd_req_o(rd_req_o), .rd_addr_o(rd_addr_o), 
                                  .ret_valid_i(ret_valid_i), .ret_data_i(ret_data_i), 
                                  
                                  .wr_len(wr_len), .wr_req_o(wr_req_o), .wr_addr_o(wr_addr_o), 
                                  .wr_data_o(wr_data_o), .wr_valid_i(wr_valid_i), 
                                  
                                  .de_dirty_way0(de_dirty_way0), .de_dirty_way1(de_dirty_way1), .hit_o(hit_o));
                                  
                                  
always begin
    #10 clk = ~clk;
end

initial begin
    #500 rst = 1'b1;
    dcache_cdata_i = 32'b0;
    iuncache_i = 1'b0;

    #100 wvalid_i=1;
    dcache_op_i = 5'b11111;
    paddr_i = 32'h24687_570;
    wdata_i = 32'h1111_1111;
    wsel_i = 4'b1111;
    #20 wvalid_i=0;
    paddr_i = 32'h0;
    wdata_i = 32'h0;
    wsel_i = 4'b0;
    wait(rd_req_o)begin
        #140   ret_valid_i=1;
        ret_data_i=128'h12345678_91023456_78910234_56789102;
        #20  ret_valid_i = 0;
    end
    
    #100 wvalid_i=1;
    dcache_op_i = 5'b11111;
    paddr_i = 32'h59595_570;
    wdata_i = 32'h1111_1111;
    wsel_i = 4'b1111;
    #20 wvalid_i=0;
    paddr_i = 32'h0;
    wdata_i = 32'h0;
    wsel_i = 4'b0;
    wait(rd_req_o)begin
        #140   ret_valid_i=1;
        ret_data_i=128'h91023456_56789102_00000000_78910234;
        #20  ret_valid_i = 0;
    end
    /*
    00001指令
    #100 wvalid_i=0;
    rvalid_i = 0;
    dcache_op_i = 5'b00001;
    paddr_i = 32'h24647_570;
    #20 dcache_op_i=5'b11111;
    paddr_i = 32'h0;
    */
    /*
    10001指令
    #100 wvalid_i=0;
    rvalid_i = 0;
    dcache_op_i = 5'b10001;
    paddr_i = 32'h24687_570;
    #20 dcache_op_i=5'b11111;
    paddr_i = 32'h0;
    */
    /*
    10101指令
    #100 wvalid_i=0;
    rvalid_i = 0;
    dcache_op_i = 5'b10101;
    paddr_i = 32'h24687_570;
    #20 dcache_op_i=5'b11111;
    paddr_i = 32'h0;
    */
    //01001指令
    #100 wvalid_i=0;
    rvalid_i = 0;
    dcache_op_i = 5'b01001;
    dcache_cdata_i = 32'h55555_555;
    paddr_i = 32'h24687_570;
    #20 dcache_op_i=5'b11111;
    dcache_cdata_i = 32'h0;
    paddr_i = 32'h0;
    #500 $finish;
end
endmodule
