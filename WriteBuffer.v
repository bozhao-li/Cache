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


module WriteBuffer(
    input wire clk,
    input wire rst,
    input wire [1:0] judge,
//    input wire duncache_i,  
    
    
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
    
    reg [127:0] FIFO_data [7:0];
    reg [31:0]  FIFO_addr [7:0];
    reg [2:0] tail;
    reg [2:0] head;
    reg [7:0] FIFO_valid;
    
    wire [7:0] write_hit;
    wire write_hit_head;
    wire [7:0] read_hit;
    
    //queue
    //1.head and tail
    always@(posedge clk) begin
        if(~rst) begin
            head <= 3'b0;
            tail <= 3'b0;
            FIFO_valid <= 8'b0;
        end else if(wreq_i && !write_hit) begin          //write into queue
            FIFO_valid[tail] <= 1'b1;
            tail <= tail + 1'b1;
        end else if(AXI_valid_i && judge[1] && !write_hit_head && FIFO_valid[head])begin
            FIFO_valid[head] <= 1'b0;
            head <= head + 1'b1;
        end else begin
            ;
        end
    end
    
    //2.FIFO_data     FIFO_addr
    always@(posedge clk) begin  //write into queue
        if(wreq_i) begin
            case(write_hit) 
                8'b00000001:begin FIFO_data[0] <= {(FIFO_data[0] & ~wsel_expand) | (wdata_i & wsel_expand)}; end
                8'b00000010:begin FIFO_data[1] <= {(FIFO_data[1] & ~wsel_expand) | (wdata_i & wsel_expand)}; end
                8'b00000100:begin FIFO_data[2] <= {(FIFO_data[2] & ~wsel_expand) | (wdata_i & wsel_expand)}; end
                8'b00001000:begin FIFO_data[3] <= {(FIFO_data[3] & ~wsel_expand) | (wdata_i & wsel_expand)}; end
                8'b00010000:begin FIFO_data[4] <= {(FIFO_data[4] & ~wsel_expand) | (wdata_i & wsel_expand)}; end
                8'b00100000:begin FIFO_data[5] <= {(FIFO_data[5] & ~wsel_expand) | (wdata_i & wsel_expand)}; end
                8'b01000000:begin FIFO_data[6] <= {(FIFO_data[6] & ~wsel_expand) | (wdata_i & wsel_expand)}; end
                8'b10000000:begin FIFO_data[7] <= {(FIFO_data[7] & ~wsel_expand) | (wdata_i & wsel_expand)}; end
                default:begin
                    FIFO_data[tail] <= wdata_i;
                    FIFO_addr[tail] <= waddr_align;
                end
            endcase
        end else begin
            ;
        end
    end
    
    //write  hit
    for(genvar i = 0; i < 8; i = i + 1)begin
        assign write_hit[i] = (waddr_align == FIFO_addr[i] && FIFO_valid[i]) ? 1'b1 : 1'b0;
    end
    assign write_hit_head = write_hit[head] && wreq_i;
    assign whit_o = |write_hit;
    
    
    
    
    //state
    wire state_full = ~rst ? 1'b0 : 
                       (head == tail && FIFO_valid[tail] == 1'b1) ? 1'b1 : 1'b0;
    wire state_working = ~rst ? 1'b0 : 
                          FIFO_valid[head] == 1'b1 ? 1'b1 : 
                          1'b0;
    assign state_o = {state_full, state_working};
    
    
    
    
    //read  hit
    for(genvar i = 0; i < 8; i = i + 1)begin
        assign read_hit[i] = (raddr_align == FIFO_addr[i] && FIFO_valid[i]) ? 1'b1 : 1'b0;
    end
    assign rhit_o = |read_hit;
    
    //read data pushing forward
    always@(*) begin  //write into queue
        if(rreq_i) begin
            case(read_hit)
                8'b00000001:begin rdata_o = FIFO_data[0]; end
                8'b00000010:begin rdata_o = FIFO_data[1]; end
                8'b00000100:begin rdata_o = FIFO_data[2]; end
                8'b00001000:begin rdata_o = FIFO_data[3]; end
                8'b00010000:begin rdata_o = FIFO_data[4]; end
                8'b00100000:begin rdata_o = FIFO_data[5]; end
                8'b01000000:begin rdata_o = FIFO_data[6]; end
                8'b10000000:begin rdata_o = FIFO_data[7]; end
                default:begin
                    rdata_o = 32'b0;
                end
            endcase
        end else begin
            rdata_o = 32'b0;
        end
    end
    
    //write into AXI
    assign AXI_wen_o = (state_o == 2'b00) ? 1'b0 : 
                       (AXI_valid_i & judge[1]) ? 1'b0 : 
                       1'b1;
    assign AXI_wdata_o = FIFO_valid[head] ? FIFO_data[head] : 128'b0;
    assign AXI_waddr_o = FIFO_valid[head] ? FIFO_addr[head] : 32'b0;
    
endmodule















