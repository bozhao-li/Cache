`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/05 10:58:36
// Design Name: 
// Module Name: WriteBuffer
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


module WriteBuffer_1line4bank(
    input wire clk,
    input wire rst,
    input wire duncache_i,  
    input wire [1:0] judge,   //01:uncache, 10:writebuffer
    
    
    input wire wreq_i,          //CPU write
    input wire [31:0] waddr_i,
    input wire [127:0] wdata_i, 
    input wire [3:0] wsel,
    output wire whit_o, 
    
    input wire rreq_i,          //CPU read
    input wire [31:0] raddr_i,
    output wire rhit_o,
    output reg [127:0] rdata_o,
    output wire [1:0] state_o,// {state_full, state_working}
    
    
    input wire AXI_valid_i,     //write into AXI 
    output wire AXI_wen_o,
    output wire [127:0] AXI_wdata_o,
    output wire [31:0] AXI_waddr_o 
    );
    wire [127:0] wsel_expand;
    assign wsel_expand = {{32{wsel[3]}} , {32{wsel[2]}} , {32{wsel[1]}} , {32{wsel[0]}}};
    //address aligning
    wire [31:0] waddr_align = {waddr_i[31:4], 4'b0};
    wire [31:0] raddr_align = {raddr_i[31:4], 4'b0};
    
    //FIFO
    reg [127:0] FIFO_data;
    reg [31:0]  FIFO_addr;
    reg FIFO_valid;
    
    wire write_hit_head;
    
    //queue
    //1.head and tail
    always@(posedge clk) begin
        if(~rst) begin
            FIFO_valid <= 1'b0;
        end else if(wreq_i && !whit_o) begin          //write into queue
            FIFO_valid <= 1'b1;
        end else if(AXI_valid_i && !duncache_i && !write_hit_head && FIFO_valid)begin
            FIFO_valid <= 1'b0;
        end else begin
            ;
        end
    end
    
    //2.FIFO_data     FIFO_addr
    always@(posedge clk) begin  //write into queue
        if(wreq_i) begin
            if(whit_o) begin
                FIFO_data <= {(FIFO_data & ~wsel_expand) | (wdata_i & wsel_expand)}; 
            end else begin
                FIFO_data <= wdata_i;
                FIFO_addr <= waddr_align;
            end
        end else begin
        end
    end
    
    //write  hit
    assign whit_o = (waddr_align == FIFO_addr && FIFO_valid) ? 1'b1 : 1'b0;
    assign write_hit_head = whit_o && wreq_i;
    
    
    //state
    wire state_full = ~rst ? 1'b0 : 
                      (FIFO_valid == 1'b1) ? 1'b1 : 1'b0;
    assign state_o = {state_full, state_full};
    
    //read  hit
    assign rhit_o = (raddr_align == FIFO_addr && FIFO_valid) ? 1'b1 : 1'b0;
    
    //read data pushing forward
    always@(*) begin  //write into queue
        if(rreq_i && rhit_o) begin
            rdata_o = FIFO_data; 
        end else begin
            rdata_o = 128'b0;
        end
    end
    

    //write into AXI
    assign AXI_wen_o = (state_o == 2'b00) ? 1'b0 : 
                        (AXI_valid_i && judge == 2'b10)? 1'b0 : 
                        1'b1;
    assign AXI_wdata_o = FIFO_data;
    assign AXI_waddr_o = FIFO_addr;
    
endmodule
