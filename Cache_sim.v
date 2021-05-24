`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/05/17 15:39:06
// Design Name: 
// Module Name: Cache_sim
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


module Cache_sim();
    reg clk = 1'b0;
    reg rst = 1'b1;
    
    reg valid = 1'b0;
    reg [31:0] addr_i = 32'b0;
    
    wire data_ok;
    wire [31:0] rdata1;
    wire [31:0] rdata2;
    
    wire rd_req;
    wire [31:0] rd_addr;
    
    reg ret_valid = 1'b0;
    reg [127:0] ret_data;
    
    Cache Cache_u(.clk(clk), .rst(rst), 
                  .valid(valid), .addr_i(addr_i), 
                  .data_ok(data_ok), .rdata1(rdata1), .rdata2(rdata2), 
                  .rd_req(rd_req), .rd_addr(rd_addr), 
                  .ret_valid(ret_valid), .ret_data(ret_data));
                    
    always begin
        #10 clk = ~clk;
    end
    
    initial begin
        #500 rst = 1'b0;
        #100 valid = 1'b1;
        addr_i = 32'hDEBA_D000;
        
        #20 valid = 1'b0;
        wait(rd_req)begin
            #140 ret_valid = 1'b1;
            ret_data = 128'h34567891_02345678_91023456_78910234;
            #20 ret_valid = 1'b0;
        end
        wait(data_ok == 1'b1)begin
            if(rdata1 == 32'h78910234 && rdata2 == 32'h91023456)begin
                $display("success:not hit, addr==0 but not valid");
                $stop;
            end else begin
                $display("FAIL!!!");
                $stop;
            end
        end
    end

endmodule
