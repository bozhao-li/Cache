`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/30 20:17:17
// Design Name: 
// Module Name: ICache_pipeline_sim
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


module ICache_pipeline_sim();
    parameter DLY = 0.1;
    reg clk = 1'b0;
    reg rst = 1'b1;
    
    wire iuncache_i = 1'b0;
    wire stall;
    wire flush = 1'b0;
    
    reg valid;
    reg [31:0] vaddr_i1;
    reg [31:0] vaddr_i2;
    reg [31:0] paddr_i;
    
    wire data_ok1;
    wire data_ok2;
    wire [31:0] rdata1;
    wire [31:0] rdata2;
    wire [31:0] raddr1;
    wire [31:0] raddr2;
    
    wire rd_req;
    wire [31:0] rd_addr;
    
    reg ret_valid;
    reg [127:0] ret_data;
    
    
    reg valid_i = 1'b0;
    reg [31:0] vaddr_i1_i = 32'b0;
    reg [31:0] vaddr_i2_i = 32'b0;
    reg [31:0] paddr_i_i = 32'b0;
    reg ret_valid_i = 1'b0;
    reg [127:0] ret_data_i;
    
    always @(posedge clk) begin
        if (rst) begin
            valid <= #DLY 0;
            vaddr_i1 <= #DLY 8'bx;
            vaddr_i2 <= #DLY 0;
            paddr_i <= #DLY 0;
            ret_valid <= #DLY 0;
            ret_data <= #DLY 0;
        end else begin
            valid <= #DLY valid_i;
            vaddr_i1 <= #DLY vaddr_i1_i;
            vaddr_i2 <= #DLY vaddr_i2_i;
            paddr_i <= #DLY paddr_i_i;
            ret_valid <= #DLY ret_valid_i;
            ret_data <= #DLY ret_data_i;
        end
    end  
    
    ICache_pipeline ICache_pipeline_u(.clk(clk), .rst(rst), 
                                        .iuncache_i(iuncache_i), .stall(stall), .flush(flush), 
                                        
                                        .valid(valid), .vaddr_i1(vaddr_i1), .vaddr_i2(vaddr_i2), .paddr_i(paddr_i), 
                                        .data_ok1(data_ok1), .data_ok2(data_ok2), 
                                        .rdata1(rdata1), .rdata2(rdata2), 
                                        .raddr1(raddr1), .raddr2(raddr2), 
                                        
                                        .rd_len(), 
                                        .rd_req(rd_req), .rd_addr(rd_addr), 
                                        .ret_valid(ret_valid), .ret_data(ret_data));
                    
    always begin
        #10 clk = ~clk;
    end
    
    initial begin
        #500 rst = 1'b0;
        
        //test 1
        //not hit, 00:34567891_02345678_82023456_78910234, tag = DEBAD
        #100 valid_i = 1'b1; paddr_i_i = 32'hDEBA_D000; vaddr_i1_i = 32'hABCD_A000; vaddr_i2_i = 32'hABCD_A004;
        #20 valid_i = 1'b0; paddr_i_i = 32'h0; vaddr_i1_i = 32'h0; vaddr_i2_i = 32'h0;
        
        wait(rd_req)begin
            #140 ret_valid_i = 1'b1;
            ret_data_i = 128'h34567891_02345678_82023456_78910234;
            #20 ret_valid_i = 1'b0;ret_data_i = 128'h0;
        end
        
        //test 2
        //not hit, 57:12345678_91023456_78910234_56789102, tag = 24687
        #500 valid_i = 1'b1; paddr_i_i = 32'h24687_570; vaddr_i1_i = 32'h1234_5570; vaddr_i2_i = 32'h1234_5574;
        #20 valid_i = 1'b0; paddr_i_i = 32'h0; vaddr_i1_i = 32'h0; vaddr_i2_i = 32'h0;
        
        wait(rd_req)begin
             #140 ret_valid_i = 1'b1;
             ret_data_i = 128'h12345678_91023456_78910234_56789102;
             #20 ret_valid_i = 1'b0;ret_data_i = 128'h0;
        end
        
        //test 3
        //hit test: constant read, read data:78910234, 91023456, 82023456, 91023456, 12345678
        #100 valid_i = 1'b1; paddr_i_i = 32'h24687_574; vaddr_i1_i = 32'h4312_5574; vaddr_i2_i = 32'h4312_5578;
        #20 valid_i = 1'b1;  paddr_i_i = 32'h24687_578; vaddr_i1_i = 32'h3214_5574; vaddr_i2_i = 32'h3214_5578;
        #20 valid_i = 1'b1;  paddr_i_i = 32'hDEBA_D004; //vaddr_i1 = 32'h3214_5574; vaddr_i2 = 32'h3214_5578;
        #20 valid_i = 1'b1;  paddr_i_i = 32'h24687_578; 
        #20 valid_i = 1'b1;  paddr_i_i = 32'h24687_57C; 
        #20 valid_i = 1'b0;  paddr_i_i = 32'h0;
        
        //test 4
        //read after write collision
        //not hit, 58:56789102_12345678_91023456_78910234, tag = 24687
        //hit,read data : 78910234, 91023456
        #500 valid_i = 1'b1; paddr_i_i = 32'h24687_580; vaddr_i1_i = 32'h1234_5570; vaddr_i2_i = 32'h1234_5574;
        #20  valid_i = 1'b0; paddr_i_i = 32'h0;         vaddr_i1_i = 32'h0;         vaddr_i2_i = 32'h0;
        
        wait(rd_req)begin
             #140 ret_valid_i = 1'b1;
             ret_data_i = 128'h56789102_12345678_91023456_78910234;
             #20 ret_valid_i = 1'b0;ret_data_i = 128'h0;
             valid_i = 1'b1;  paddr_i_i = 32'h24687_584; vaddr_i1_i = 32'h3214_5574; vaddr_i2_i = 32'h3214_5578;
        end
        #20 valid_i = 1'b0; paddr_i_i = 32'h0; vaddr_i1_i = 32'h0; vaddr_i2_i = 32'h0;
        
        //test 5
        //not hit + uncache + hit 
        
        
        
        //test 6
        //hit + uncache + not hit
        
        
        
        #500 $finish; 
    end


endmodule
