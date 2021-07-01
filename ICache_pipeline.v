`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/30 09:38:28
// Design Name: 
// Module Name: ICache_pipeline
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

//when hit, pipeline, two states
//first state : CPU data input, read request to Cache Ram 
//second state : get Cache Ram read data, output to CPU
`include "defines.v"
/*TODO:valid位初始化时要特判*/
module ICache_pipeline(
    input wire clk,
    input wire rst,
    input wire iuncache_i,//
    output wire stall, 
    input wire flush,//
    
    //Cache port with CPU
    input wire valid,           //valid request
    input wire [31:0] vaddr_i1,
    input wire [31:0] vaddr_i2,
    input wire [31:0] paddr_i,
    output wire data_ok1,       //data transfer out is OK
    output wire data_ok2,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2,
    output wire [31:0] raddr1,
    output wire [31:0] raddr2,
    
    //Cache port with AXI
    output wire [7:0] rd_len,
    output wire rd_req,          //read valid request
    output wire [31:0] rd_addr,  //read initial address
    input wire ret_valid,        //return data valid
    input wire [127:0] ret_data
    
    );
    
    wire [19:0] ptag_1;
    wire [7:0] index_1;
    wire [3:0] offset_1;
    wire valid_1;
    wire [31:0] vaddr_i1_1;
    wire [31:0] vaddr_i2_1;
    
    reg [19:0] ptag_2;
    reg [7:0] index_2;
    reg [3:0] offset_2;
    reg valid_2;
    reg [31:0] vaddr_i1_2;
    reg [31:0] vaddr_i2_2;
    
    assign ptag_1 = paddr_i[31:12];
    assign index_1 = paddr_i[11:4];
    assign offset_1 = paddr_i[3:0];
    assign valid_1 = valid;
    assign vaddr_i1_1 = vaddr_i1;
    assign vaddr_i2_1 = vaddr_i2;
    
    //* Cache main part: Tagv + Data *//
    
    //each way: 1 TagV(256*21), [1 D(256*1)], 4 DataBank(256*32)
    wire [7:0] read_addr = stall ? index_2 : index_1;
    wire [3:0] wea_way0;
    wire [20:0] way0_tagv;
    wire [31:0] way0_cacheline[3:0];
    Tagv_dual_ram tagv_way0(.addra(index_2), .clka(clk), .dina({1'b1, ptag_2}), .ena(|wea_way0), .wea(|wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_tagv), .enb(1'b1));
    Data_dual_ram Bank0_way0(.addra(index_2), .clka(clk), .dina(read_from_AXI[32*1-1:32*0]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[0]), .enb(1'b1));
    Data_dual_ram Bank1_way0(.addra(index_2), .clka(clk), .dina(read_from_AXI[32*2-1:32*1]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[1]), .enb(1'b1));
    Data_dual_ram Bank2_way0(.addra(index_2), .clka(clk), .dina(read_from_AXI[32*3-1:32*2]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[2]), .enb(1'b1));
    Data_dual_ram Bank3_way0(.addra(index_2), .clka(clk), .dina(read_from_AXI[32*4-1:32*3]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[3]), .enb(1'b1));
    
    wire [3:0] wea_way1;
    wire [20:0] way1_tagv;
    wire [31:0] way1_cacheline[3:0];
    Tagv_dual_ram tagv_way1(.addra(index_2), .clka(clk), .dina({1'b1, ptag_2}), .ena(|wea_way1), .wea(|wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_tagv), .enb(1'b1));
    Data_dual_ram Bank0_way1(.addra(index_2), .clka(clk), .dina(read_from_AXI[32*1-1:32*0]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[0]), .enb(1'b1));
    Data_dual_ram Bank1_way1(.addra(index_2), .clka(clk), .dina(read_from_AXI[32*2-1:32*1]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[1]), .enb(1'b1));
    Data_dual_ram Bank2_way1(.addra(index_2), .clka(clk), .dina(read_from_AXI[32*3-1:32*2]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[2]), .enb(1'b1));
    Data_dual_ram Bank3_way1(.addra(index_2), .clka(clk), .dina(read_from_AXI[32*4-1:32*3]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[3]), .enb(1'b1));
    
    
    //* Hit Pipeline: 2 states, Idle and LookUp*//
    //* Not Hit: stall pipeline *//
    
    always@(posedge clk)begin
        if(rst)begin
            valid_2 <= 1'b0;
            ptag_2 <= 20'b0;
            index_2 <= 8'b0;
            offset_2 <= 4'b0;
            vaddr_i1_2 <= 32'b0;
            vaddr_i2_2 <= 32'b0;
        end else if(stall)begin
            valid_2 <= valid_2;
            ptag_2 <= ptag_2;
            index_2 <= index_2;
            offset_2 <= offset_2;
            vaddr_i1_2 <= vaddr_i1_2;
            vaddr_i2_2 <= vaddr_i2_2;
        end else begin
            valid_2 <= valid_1;
            ptag_2 <= ptag_1;
            index_2 <= index_1;
            offset_2 <= offset_1;
            vaddr_i1_2 <= vaddr_i1_1;
            vaddr_i2_2 <= vaddr_i2_1;
        end
    end
    
    
    wire hit;                               //hit:1
    wire nhit;
    wire hit_judge_way0;
    wire hit_judge_way1;
    
    //* LRU *//
    reg [255:0] LRU;    //LRU width depends on index
    wire LRU_current = LRU[index_2];
    always@(posedge clk)begin
        if(rst)begin
            LRU <= 256'b0;
        end else if((data_ok1 || data_ok2) && hit)begin
            LRU[index_2] <= hit_judge_way0;
        end else if((data_ok1 || data_ok2) && !hit)begin
            LRU[index_2] <= !hit_judge_way0;
        end else begin
            LRU <= LRU;
        end
    end
    
    wire [127:0]read_from_AXI;
    assign read_from_AXI = ret_data;
    /*
    // collision 
    reg collision_way0;
    reg collision_way1;
    reg [31:0]inst1_from_mem_2;
    reg [31:0]inst2_from_mem_2;
    reg [127:0]read_from_AXI_2;
    reg [20:0]tagv_way0_2;
    reg [20:0]tagv_way1_2;
    always@(posedge clk)begin
        collision_way0 <= (|wea_way0 && ptag_1 == ptag_2) ? 1'b1 :1'b0;
        collision_way1 <= (|wea_way1 && ptag_1 == ptag_2) ? 1'b1 :1'b0;
        read_from_AXI_2 <= read_from_AXI;
        tagv_way0_2 <= {1'b1,ptag_2};
        tagv_way1_2 <= {1'b1,ptag_2};
    end
    */
    
    //*logics*//
    //////////inner logics
    assign wea_way0 = (ret_valid && LRU_current == 1'b0) ? 4'b1111 :4'b0000; 
    assign wea_way1 = (ret_valid && LRU_current == 1'b1) ? 4'b1111 :4'b0000; 
    
    //data select
    wire [31:0]inst1_way0 = way0_cacheline[offset_2[3:2]];     //cache address partition in page 228
    wire [31:0]inst2_way0 = way0_cacheline[offset_2[3:2] + 'b1];
    wire [31:0]inst1_way1 = way1_cacheline[offset_2[3:2]];
    wire [31:0]inst2_way1 = way1_cacheline[offset_2[3:2] + 'b1];
    
    //hit
    assign hit_judge_way0 = (way0_tagv[20] != 1'b1) ? 1'b0 : 
                            (ptag_2 == way0_tagv[19:0]) ? 1'b1 : 1'b0;
    assign hit_judge_way1 = (way1_tagv[20] != 1'b1) ? 1'b0 : 
                            (ptag_2 == way1_tagv[19:0]) ? 1'b1 : 1'b0;
    assign hit = (hit_judge_way0 | hit_judge_way1) && valid_2;
    assign nhit = !(hit_judge_way0 | hit_judge_way1) && valid_2;
    
    
    //////////output logics
    assign data_ok1 = hit ? 1'b1 : 
                      (nhit && ret_valid) ? 1'b1: 
                      1'b0;
    
    assign data_ok2 = (offset_2[3:2] == 2'b11) ? 1'b0 : 
                      data_ok1;
    
    assign rdata1 = (hit && hit_judge_way0) ? inst1_way0 : 
                    (hit && hit_judge_way1) ? inst1_way1 :
                    (nhit && ret_valid && offset_2[3:2] == 2'h0) ? read_from_AXI[32*1-1:32*0]:
                    (nhit && ret_valid && offset_2[3:2] == 2'h1) ? read_from_AXI[32*2-1:32*1]:
                    (nhit && ret_valid && offset_2[3:2] == 2'h2) ? read_from_AXI[32*3-1:32*2]:
                    (nhit && ret_valid && offset_2[3:2] == 2'h3) ? read_from_AXI[32*4-1:32*3]:
                    32'b0;
    
    assign rdata2 = (hit && hit_judge_way0) ? inst2_way0 : 
                    (hit && hit_judge_way1) ? inst2_way1 :
                    (nhit && ret_valid && offset_2[3:2] == 2'h0) ? read_from_AXI[32*2-1:32*1]:
                    (nhit && ret_valid && offset_2[3:2] == 2'h1) ? read_from_AXI[32*3-1:32*2]:
                    (nhit && ret_valid && offset_2[3:2] == 2'h2) ? read_from_AXI[32*4-1:32*3]:
                    (nhit && ret_valid && offset_2[3:2] == 2'h3) ? read_from_AXI[32*1-1:32*0]:
                    32'b0;
    
    assign raddr1 = vaddr_i1_2;
    
    assign raddr2 = vaddr_i2_2;
    
    assign rd_len = (iuncache_i & rd_req) ? 8'h0 : 8'h3;
    
    assign rd_req = (nhit && !ret_valid);
    
    assign rd_addr = {ptag_2, index_2, offset_2};
    
    assign stall = (nhit && data_ok1 == 1'b0) ? 1'b1 :1'b0;
    
    
endmodule
