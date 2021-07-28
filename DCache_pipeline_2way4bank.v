`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/07 14:15:18
// Design Name: 
// Module Name: DCache_pipeline
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

module DCache_pipeline_2way4bank(
    input clk,
    input rst,
    input wire duncache_i,
    output reg stall_o, 
    
    //Cache port with CPU
    input wire rvalid_i,                //valid request
    input wire [31:0] paddr_i,  
    input wire wvalid_i,                //1:write, 0:read
    input wire [3:0] wsel_i,            //write enable
    input wire [31:0] wdata_i,    
    
    
    output wire data_ok_o,             //data transfer out is OK
(*mark_debug = "true"*)    output reg [31:0] rdata_o,    
    
    //Cache port with AXI
    output wire [7:0] rd_len,
    output wire rd_req_o,              //read valid request
    output wire [31:0] rd_addr_o,     //read initial address
    input wire ret_valid_i,            //return data valid
    input wire [127:0] ret_data_i,
    
    output wire [7:0] wr_len,
    output wire wr_req_o,          //write valid request 
    output wire [31:0] wr_addr_o,
(*mark_debug = "true"*)    output wire [127:0] wr_data_o,
    output wire [3:0] wr_wstrb_o,
    input wire wr_valid_i,
    
(*mark_debug = "true"*)    output reg [1:0] judge,
(*mark_debug = "true"*)   output reg duncache_2
    
//    //debug
//    output wire [255:0] de_dirty_way0,
//    output wire [255:0] de_dirty_way1,
//    output wire hit_o
    
    );
    
    
    //*Cycle 1 and Cycla 2*//
    wire [19:0] ptag_1;
    wire [7:0] index_1;
    wire [3:0] offset_1;
    wire rvalid_1;
    wire wvalid_1;
    wire [3:0] wsel_1;
    wire [31:0] wdata_1;
    wire flush_1;
    
    reg [19:0] ptag_2;
    reg [7:0] index_2;
    reg [3:0] offset_2;
    reg rvalid_2;
    reg wvalid_2;
    reg [3:0] wsel_2;
    reg [31:0] wdata_2;
    
//    reg duncache_2;
    
    assign ptag_1 = paddr_i[31:12];
    assign index_1 = paddr_i[11:4];
    assign offset_1 = paddr_i[3:0];
    assign rvalid_1 = rvalid_i;
    assign wvalid_1 = wvalid_i;
    assign wsel_1 = wsel_i;
    assign wdata_1 = wdata_i;
    
    always@(posedge clk)begin
        if(~rst)begin
            rvalid_2 <= 1'b0;
            wvalid_2 <= 1'b0;
            ptag_2 <= 20'b0;
            index_2 <= 8'b0;
            offset_2 <= 4'b0;
            wsel_2 <= 4'b0;
            wdata_2 <= 32'b0;
            duncache_2 <= 1'b0;
        end else if(stall_o)begin
            rvalid_2 <= rvalid_2;
            wvalid_2 <= wvalid_2;
            ptag_2 <= ptag_2;
            index_2 <= index_2;
            offset_2 <= offset_2;
            wsel_2 <= wsel_2;
            wdata_2 <= wdata_2;
            duncache_2 <= duncache_2;
        end else begin
            rvalid_2 <= rvalid_1;
            wvalid_2 <= wvalid_1;
            ptag_2 <= ptag_1;
            index_2 <= index_1;
            offset_2 <= offset_1;
            wsel_2 <= wsel_1;
            wdata_2 <= wdata_1;
            duncache_2 <= duncache_i;
        end
    end
    
    
    //* Cache main part: Tagv + Data *//
    //each way: 1 TagV(256*21), [1 D(256*1)], 4 DataBank(256*32)
    reg [31:0]write_into_Cache[3:0];
    
    wire [7:0] read_addr = stall_o ? index_2 : index_1;
    wire [3:0] wea_way0;
    wire [20:0] way0_tagv;
    wire [31:0] way0_cacheline[3:0];
    wire rsta_busy1;
    wire rstb_busy1;
    wire read_enb0 = ~(|wea_way0 && index_2 == read_addr);
    Tagv_dual_ram tagv_way0(.addra(index_2), .clka(clk), .dina({1'b1, ptag_2}), .ena(|wea_way0), .wea(|wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_tagv), .enb(read_enb0), .rstb(~rst), .rsta_busy(rsta_busy1), .rstb_busy(rstb_busy1));
    Data_dual_ram_d Bank0_way0(.addra(index_2), .clka(clk), .dina(write_into_Cache[0]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[0]), .enb(read_enb0));
    Data_dual_ram_d Bank1_way0(.addra(index_2), .clka(clk), .dina(write_into_Cache[1]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[1]), .enb(read_enb0));
    Data_dual_ram_d Bank2_way0(.addra(index_2), .clka(clk), .dina(write_into_Cache[2]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[2]), .enb(read_enb0));
    Data_dual_ram_d Bank3_way0(.addra(index_2), .clka(clk), .dina(write_into_Cache[3]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[3]), .enb(read_enb0));
    
    wire [3:0] wea_way1;
    wire [20:0] way1_tagv;
    wire [31:0] way1_cacheline[3:0];
    wire rsta_busy2;
    wire rstb_busy2;
    wire read_enb1 = ~(|wea_way1 && index_2 == read_addr);   
    Tagv_dual_ram tagv_way1(.addra(index_2), .clka(clk), .dina({1'b1, ptag_2}), .ena(|wea_way1), .wea(|wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_tagv), .enb(read_enb1), .rstb(~rst), .rsta_busy(rsta_busy2), .rstb_busy(rstb_busy2));
    Data_dual_ram_d Bank0_way1(.addra(index_2), .clka(clk), .dina(write_into_Cache[0]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[0]), .enb(read_enb1));
    Data_dual_ram_d Bank1_way1(.addra(index_2), .clka(clk), .dina(write_into_Cache[1]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[1]), .enb(read_enb1));
    Data_dual_ram_d Bank2_way1(.addra(index_2), .clka(clk), .dina(write_into_Cache[2]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[2]), .enb(read_enb1));
    Data_dual_ram_d Bank3_way1(.addra(index_2), .clka(clk), .dina(write_into_Cache[3]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[3]), .enb(read_enb1));
        
    
    
    //* LRU *//
    wire hit;                               //hit:1
    wire nhit;
    wire hit_judge_way0;
    wire hit_judge_way1;
        
    reg [255:0] LRU;    //LRU width depends on index
    wire LRU_current = LRU[index_2];
    always@(posedge clk)begin
        if(~rst)begin
            LRU <= 256'b0;
        end else if(hit)begin
            LRU[index_2] <= hit_judge_way0;
        end else if(ret_valid_i & nhit)begin
            LRU[index_2] <= ~LRU_current;
        end else begin
            LRU <= LRU;     
        end
    end
    
    
    
    //Dirty signal
    reg [255:0] dirty_way0;
    reg [255:0] dirty_way1;
    wire write_dirty = (LRU_current == 0) ? dirty_way0[index_2] : dirty_way1[index_2];
    always@(posedge clk)begin
        if(~rst)begin
            dirty_way0 <= 256'b0;
            dirty_way1 <= 256'b0;
        end else if(ret_valid_i == 1'b1 && rvalid_2 == 1'b1)begin      //read not hit
            if(LRU_current)begin
                dirty_way1[index_2] <= 1'b0;
            end else begin
                dirty_way0[index_2] <= 1'b0;
            end
        end else if(ret_valid_i == 1'b1 && wvalid_2 == 1'b1)begin      //write not hit
            if(LRU_current)begin
                dirty_way1[index_2] <= 1'b1;
            end else begin
                dirty_way0[index_2] <= 1'b1;
            end
        end else if(hit && wvalid_2 == 1'b1)begin   //hit write
            if(hit_judge_way1)begin
                dirty_way1[index_2] <= 1'b1;
            end else begin
                dirty_way0[index_2] <= 1'b1;
            end
        end else begin
            dirty_way0 <= dirty_way0;
            dirty_way1 <= dirty_way1;
        end
    end
    
//    assign de_dirty_way0 = dirty_way0;
//    assign de_dirty_way1 = dirty_way1;
    
    
    
    //* WriteBuffer *//
    wire queue_wreq_i;
    wire [31:0] queue_waddr_i;
    reg [127:0] queue_wdata_i;
    wire whit_o;
    wire rhit_o;
    wire [127:0] queue_rdata_o ;
    wire [1:0] state_o;
    
    reg [20:0]tagv_way0_2;
    reg [20:0]tagv_way1_2;
        
    //queue_wreq_i
    assign queue_wreq_i = (rhit_o == 1'b1 && wvalid_2 == 1'b1) ? 1'b1:
                          (ret_valid_i == 1'b1 && state_o != 2'b11 && write_dirty == 1'b1)? 1'b1: 1'b0;
    //queue_waddr_i
    wire [20:0]tagv_final_way0;
    wire [20:0]tagv_final_way1;
    assign queue_waddr_i = (rhit_o == 1'b1 && wvalid_2 == 1'b1) ? {ptag_2, index_2, offset_2} : 
                           (LRU_current == 1'b1)?  {tagv_final_way1[19:0], index_2, offset_2}:
                           {tagv_final_way0[19:0], index_2, offset_2};
    reg [3:0] wsel_into_FIFO;
    always @(*)begin
        if(rhit_o == 1'b1 && wvalid_2 == 1'b1)begin
            case(offset_2[3:2])
                2'b00:wsel_into_FIFO = 4'b0001;
                2'b01:wsel_into_FIFO = 4'b0010;
                2'b10:wsel_into_FIFO = 4'b0100;
                2'b11:wsel_into_FIFO = 4'b1000;
                default:wsel_into_FIFO = 4'b0000;
            endcase
        end else begin
            wsel_into_FIFO = 4'b1111;
        end
    end
    
    //queue_wdata_i
    always@(*)begin
        if(ret_valid_i)begin    //write back
            if(LRU_current)begin
                queue_wdata_i = {way1_cacheline[3], way1_cacheline[2], way1_cacheline[1], way1_cacheline[0]};
            end else begin
                queue_wdata_i = {way0_cacheline[3], way0_cacheline[2], way0_cacheline[1], way0_cacheline[0]};
            end
        end else if(wvalid_2 && rhit_o)begin
            case(offset_2[3:2])
                2'b00:begin queue_wdata_i = {write_into_Cache[3], write_into_Cache[2], write_into_Cache[1], wdata_2}; end
                2'b01:begin queue_wdata_i = {write_into_Cache[3], write_into_Cache[2], wdata_2, write_into_Cache[0]}; end
                2'b10:begin queue_wdata_i = {write_into_Cache[3], wdata_2, write_into_Cache[1], write_into_Cache[0]}; end
                2'b11:begin queue_wdata_i = {wdata_2, write_into_Cache[2], write_into_Cache[1], write_into_Cache[0]}; end
                default:    ;
            endcase
        end else begin
            queue_wdata_i = 128'b0;
        end
    end
    
    
    //UnCache
    wire UnCache_req;
    wire [127:0] UnCache_data;
    wire [31:0] UnCache_addr;
    
    assign UnCache_req = (wr_valid_i && judge[0]) ? 1'b0 :  
                         (duncache_2 & wvalid_2);
    assign UnCache_data = (duncache_2 & wr_req_o) ? {4{wdata_2}}: 128'b0;
    assign UnCache_addr = (duncache_2 & wr_req_o) ? {ptag_2, index_2, offset_2[3:2], 2'b00} : 32'b0;    
    
    wire FIFO_req;
    
    always @(posedge clk) begin
        if (~rst)                           judge <= 2'b00;
        else if (wr_valid_i & UnCache_req)  judge <= 2'b01;
        else if (wr_valid_i & FIFO_req)     judge <= 2'b10;
        else if (wr_valid_i)                judge <= 2'b00;
        else if (|judge)                    judge <= judge;
        else if (UnCache_req)               judge <= 2'b01;
        else if (FIFO_req)                  judge <= 2'b10;
    end
    

    
    wire [127:0] FIFO_data;
    wire [31:0] FIFO_addr;
    WriteBuffer WriteBuffer_u(.clk(clk), .rst(rst), .judge(judge),  .duncache_i(duncache_2),
        
                              .wreq_i(queue_wreq_i), .waddr_i(queue_waddr_i), .wdata_i(queue_wdata_i), 
                              .wsel(wsel_into_FIFO), .whit_o(whit_o), 
                              .rreq_i(rvalid_2 || wvalid_2), .raddr_i({ptag_2, index_2, offset_2}), .rhit_o(rhit_o), .rdata_o(queue_rdata_o), 
                              .state_o(state_o), 
                              
                              .AXI_valid_i(wr_valid_i), .AXI_wen_o(FIFO_req), 
                              .AXI_wdata_o(FIFO_data), .AXI_waddr_o(FIFO_addr));
    
    assign wr_len = (judge[0] & wr_req_o) ? 8'h0 : 8'h3;
    
    assign wr_req_o = judge[0] ? UnCache_req: FIFO_req;
    assign wr_data_o = judge[0] ? UnCache_data : FIFO_data;
    assign wr_addr_o = judge[0] ? UnCache_addr : FIFO_addr;
    assign wr_wstrb_o = judge[0] ? wsel_2 : 4'b1111;
    
    //* collision *//
    reg collision_way0;
    reg collision_way1;
    reg [31:0]write_into_Cache_inst_2;
    
    always@(posedge clk)begin
      collision_way0 <= (|wea_way0 && index_1 == index_2) ? 1'b1 :1'b0;
      collision_way1 <= (|wea_way1 && index_1 == index_2) ? 1'b1 :1'b0;
      write_into_Cache_inst_2 <= write_into_Cache[offset_1[3:2]];
      tagv_way0_2 <= {1'b1,ptag_2};
      tagv_way1_2 <= {1'b1,ptag_2};
    end
    
    reg [31:0] write_into_Cache_ff [3:0];
    always @(posedge clk) begin
        if (~rst) begin
            write_into_Cache_ff[3] <= 32'b0;
            write_into_Cache_ff[2] <= 32'b0;
            write_into_Cache_ff[1] <= 32'b0;
            write_into_Cache_ff[0] <= 32'b0;
        end else begin
            write_into_Cache_ff[3] <= write_into_Cache[3];
            write_into_Cache_ff[2] <= write_into_Cache[2];
            write_into_Cache_ff[1] <= write_into_Cache[1];
            write_into_Cache_ff[0] <= write_into_Cache[0];
        end
    end
    
    //* logics *//
    //////////inner logics
    wire [31:0]read_from_AXI[3:0];
    for(genvar i = 0 ;i < 4; i = i + 1)begin
            assign read_from_AXI[i] = ret_data_i[32*(i+1)-1:32*i];
    end
    //data_select
    wire [31:0]inst_way0 = collision_way0 ? write_into_Cache_inst_2 : 
                             way0_tagv[20] ? way0_cacheline[offset_2[3:2]] : 32'b0;     //cache address partition in page 228
    wire [31:0]inst_way1 = collision_way1 ? write_into_Cache_inst_2 : 
                             way1_tagv[20] ? way1_cacheline[offset_2[3:2]] : 32'b0;
    assign tagv_final_way0 = collision_way0 ? tagv_way0_2 : way0_tagv;
    assign tagv_final_way1 = collision_way1 ? tagv_way1_2 : way1_tagv;
    
    //hit
    assign hit_judge_way0 = (tagv_final_way0[20] != 1'b1) ? 1'b0 : 
                            (ptag_2 == tagv_final_way0[19:0]) ? 1'b1 : 1'b0;
    assign hit_judge_way1 = (tagv_final_way1[20] != 1'b1) ? 1'b0 : 
                            (ptag_2 == tagv_final_way1[19:0]) ? 1'b1 : 1'b0;
    assign hit = (hit_judge_way0 | hit_judge_way1 | rhit_o|whit_o) && (rvalid_2||wvalid_2) && ~duncache_2;
    assign nhit = ~hit && (rvalid_2||wvalid_2);
    
//    assign hit_o = hit;
    
    //write_into_Cache
    wire [31:0]wsel_expand;
    assign wsel_expand={{8{wsel_2[3]}} , {8{wsel_2[2]}} , {8{wsel_2[1]}} , {8{wsel_2[0]}}};
    always @(*)begin
        if(hit)begin        //////hit write
            if(hit_judge_way0)begin
                case(offset_2[3:2])
                    2'b00: begin  write_into_Cache[3] = collision_way0 ? write_into_Cache_ff[3] : way0_cacheline[3];
                                  write_into_Cache[2] = collision_way0 ? write_into_Cache_ff[2] : way0_cacheline[2];
                                  write_into_Cache[1] = collision_way0 ? write_into_Cache_ff[1] : way0_cacheline[1];
                                  write_into_Cache[0] = (wdata_2 & wsel_expand)|((collision_way0 ? write_into_Cache_ff[0] : way0_cacheline[0]) & ~wsel_expand); end
                    2'b01: begin  write_into_Cache[3] = collision_way0 ? write_into_Cache_ff[3] : way0_cacheline[3];
                                  write_into_Cache[2] = collision_way0 ? write_into_Cache_ff[2] : way0_cacheline[2];
                                  write_into_Cache[1] = (wdata_2 & wsel_expand)|((collision_way0 ? write_into_Cache_ff[1] : way0_cacheline[1]) & ~wsel_expand);
                                  write_into_Cache[0] = collision_way0 ? write_into_Cache_ff[0] : way0_cacheline[0]; end
                    2'b10: begin  write_into_Cache[3] = collision_way0 ? write_into_Cache_ff[3] : way0_cacheline[3];
                                  write_into_Cache[2] = (wdata_2 & wsel_expand)|((collision_way0 ? write_into_Cache_ff[2] : way0_cacheline[2]) & ~wsel_expand);
                                  write_into_Cache[1] = collision_way0 ? write_into_Cache_ff[1] : way0_cacheline[1];
                                  write_into_Cache[0] = collision_way0 ? write_into_Cache_ff[0] : way0_cacheline[0]; end
                    2'b11: begin  write_into_Cache[3] = (wdata_2 & wsel_expand)|((collision_way0 ? write_into_Cache_ff[3] : way0_cacheline[3]) & ~wsel_expand);
                                  write_into_Cache[2] = collision_way0 ? write_into_Cache_ff[2] : way0_cacheline[2];
                                  write_into_Cache[1] = collision_way0 ? write_into_Cache_ff[1] : way0_cacheline[1];
                                  write_into_Cache[0] = collision_way0 ? write_into_Cache_ff[0] : way0_cacheline[0]; end
                    default: begin write_into_Cache[3] = way0_cacheline[3];
                                     write_into_Cache[2] = way0_cacheline[2];
                                     write_into_Cache[1] = way0_cacheline[1];
                                     write_into_Cache[0] = way0_cacheline[0]; end
                endcase
            end else if(hit_judge_way1)begin
                case(offset_2[3:2])
                    2'b00: begin  write_into_Cache[3] = collision_way1 ? write_into_Cache_ff[3] : way1_cacheline[3];
                                  write_into_Cache[2] = collision_way1 ? write_into_Cache_ff[2] : way1_cacheline[2];
                                  write_into_Cache[1] = collision_way1 ? write_into_Cache_ff[1] : way1_cacheline[1];
                                  write_into_Cache[0] = (wdata_2 & wsel_expand)|((collision_way1 ? write_into_Cache_ff[0] : way1_cacheline[0]) & ~wsel_expand); end
                    2'b01: begin  write_into_Cache[3] = collision_way1 ? write_into_Cache_ff[3] : way1_cacheline[3];
                                  write_into_Cache[2] = collision_way1 ? write_into_Cache_ff[2] : way1_cacheline[2];
                                  write_into_Cache[1] = (wdata_2 & wsel_expand)|((collision_way1 ? write_into_Cache_ff[1] : way1_cacheline[1]) & ~wsel_expand);
                                  write_into_Cache[0] = collision_way1 ? write_into_Cache_ff[0] : way1_cacheline[0]; end
                    2'b10: begin  write_into_Cache[3] = collision_way1 ? write_into_Cache_ff[3] : way1_cacheline[3];
                                  write_into_Cache[2] = (wdata_2 & wsel_expand)|((collision_way1 ? write_into_Cache_ff[2] : way1_cacheline[2]) & ~wsel_expand);
                                  write_into_Cache[1] = collision_way1 ? write_into_Cache_ff[1] : way1_cacheline[1];
                                  write_into_Cache[0] = collision_way1 ? write_into_Cache_ff[0] : way1_cacheline[0]; end
                    2'b11: begin  write_into_Cache[3] = (wdata_2 & wsel_expand)|((collision_way1 ? write_into_Cache_ff[3] : way1_cacheline[3]) & ~wsel_expand);
                                  write_into_Cache[2] = collision_way1 ? write_into_Cache_ff[2] : way1_cacheline[2];
                                  write_into_Cache[1] = collision_way1 ? write_into_Cache_ff[1] : way1_cacheline[1];
                                  write_into_Cache[0] = collision_way1 ? write_into_Cache_ff[0] : way1_cacheline[0]; end
                    default: begin write_into_Cache[3] = way1_cacheline[3];
                                     write_into_Cache[2] = way1_cacheline[2];
                                     write_into_Cache[1] = way1_cacheline[1];
                                     write_into_Cache[0] = way1_cacheline[0]; end
                endcase
            end else begin
                write_into_Cache[3] = way1_cacheline[3];
                write_into_Cache[2] = way1_cacheline[2];
                write_into_Cache[1] = way1_cacheline[1];
                write_into_Cache[0] = way1_cacheline[0]; 
            end
        end else if(rhit_o|whit_o)begin    //////hit queue
            case(offset_2[3:2])
                2'b00: begin write_into_Cache[3] = queue_rdata_o[32*4-1: 32*3];
                              write_into_Cache[2] = queue_rdata_o[32*3-1: 32*2];
                              write_into_Cache[1] = queue_rdata_o[32*2-1: 32*1];
                              write_into_Cache[0] = wdata_2; end
                2'b01: begin write_into_Cache[3] = queue_rdata_o[32*4-1: 32*3];
                              write_into_Cache[2] = queue_rdata_o[32*3-1: 32*2];
                              write_into_Cache[1] = wdata_2;
                              write_into_Cache[0] = queue_rdata_o[32*1-1: 32*0]; end
                2'b10: begin write_into_Cache[3] = queue_rdata_o[32*4-1: 32*3];
                              write_into_Cache[2] = wdata_2;
                              write_into_Cache[1] = queue_rdata_o[32*2-1: 32*1];
                              write_into_Cache[0] = queue_rdata_o[32*1-1: 32*0]; end
                2'b11: begin write_into_Cache[3] = wdata_2;
                              write_into_Cache[2] = queue_rdata_o[32*3-1: 32*2];
                              write_into_Cache[1] = queue_rdata_o[32*2-1: 32*1];
                              write_into_Cache[0] = queue_rdata_o[32*1-1: 32*0]; end
                default: begin write_into_Cache[3] = queue_rdata_o[32*4-1: 32*3];
                                 write_into_Cache[2] = queue_rdata_o[32*3-1: 32*2];
                                 write_into_Cache[1] = queue_rdata_o[32*2-1: 32*1];
                                 write_into_Cache[0] = queue_rdata_o[32*1-1: 32*0]; end
            endcase
        end else if(nhit && rvalid_2)begin      //read not hit
            write_into_Cache[3] = ret_data_i[32*4-1: 32*3];
            write_into_Cache[2] = ret_data_i[32*3-1: 32*2];
            write_into_Cache[1] = ret_data_i[32*2-1: 32*1];
            write_into_Cache[0] = ret_data_i[32*1-1: 32*0];
        end else if(nhit)begin      //write not hit
            case(offset_2[3:2])
                2'b00: begin write_into_Cache[3] = ret_data_i[32*4-1: 32*3];
                              write_into_Cache[2] = ret_data_i[32*3-1: 32*2];
                              write_into_Cache[1] = ret_data_i[32*2-1: 32*1];
                              write_into_Cache[0] = (wdata_2 & wsel_expand)|(ret_data_i[32*1-1:32*0] & ~wsel_expand); end
                2'b01: begin write_into_Cache[3] = ret_data_i[32*4-1: 32*3];
                              write_into_Cache[2] = ret_data_i[32*3-1: 32*2];
                              write_into_Cache[1] = (wdata_2 & wsel_expand)|(ret_data_i[32*2-1:32*1] & ~wsel_expand);
                              write_into_Cache[0] = ret_data_i[32*1-1: 32*0]; end
                2'b10: begin write_into_Cache[3] = ret_data_i[32*4-1: 32*3];
                              write_into_Cache[2] = (wdata_2 & wsel_expand)|(ret_data_i[32*3-1:32*2] & ~wsel_expand);
                              write_into_Cache[1] = ret_data_i[32*2-1: 32*1];
                              write_into_Cache[0] = ret_data_i[32*1-1: 32*0]; end
                2'b11: begin write_into_Cache[3] = (wdata_2 & wsel_expand)|(ret_data_i[32*4-3:32*3] & ~wsel_expand);
                              write_into_Cache[2] = ret_data_i[32*3-1: 32*2];
                              write_into_Cache[1] = ret_data_i[32*2-1: 32*1];
                              write_into_Cache[0] = ret_data_i[32*1-1: 32*0]; end
                default: begin write_into_Cache[3] = ret_data_i[32*4-1: 32*3];
                                 write_into_Cache[2] = ret_data_i[32*3-1: 32*2];
                                 write_into_Cache[1] = ret_data_i[32*2-1: 32*1];
                                 write_into_Cache[0] = ret_data_i[32*1-1: 32*0]; end
            endcase
        end else begin
            write_into_Cache[3] = 32'b0;
            write_into_Cache[2] = 32'b0;
            write_into_Cache[1] = 32'b0;
            write_into_Cache[0] = 32'b0;
        end
        
    end
    
    //wea
    assign wea_way0 = (nhit && LRU_current == 1'b0 && ret_valid_i && ~duncache_2) ? 4'b1111 : //hit fail
                      (hit && wvalid_2 && hit_judge_way0 && ~duncache_2) ? (wsel_2):    //write hit success
                       4'h0;
    assign wea_way1 = (nhit && LRU_current == 1'b1 && ret_valid_i && ~duncache_2)? 4'b1111 : 
                      (hit && wvalid_2 && hit_judge_way1 && ~duncache_2)?(wsel_2):
                      4'h0;
    
    
    //////////output logics
    //stall
    always@(*)begin
        if(duncache_2 && data_ok_o == 1'b0 && rvalid_2)begin
            stall_o = 1'b1;
        end else if (judge[0] & wr_valid_i) begin
            stall_o = 1'b0;
        end else if(duncache_2 & wvalid_2)begin
            stall_o = 1'b1;
        end else if (ret_valid_i & (&state_o) & write_dirty) begin
            stall_o = 1'b1;
        end else if (~duncache_2 & nhit) begin
            stall_o = ~ret_valid_i;
        end else begin
            stall_o = 1'b0;
        end
    end
    
    //data_ok_o
    assign data_ok_o = (duncache_2 && ret_valid_i) ? 1'b1 :
                        (hit && rvalid_2) ? 1'b1 : 
                        (nhit && ret_valid_i && rvalid_2) ? 1'b1: 
                        1'b0;
    //[31:0] raddr
    //[31:0] rdata_o
    always@(*)begin
        if(duncache_2 && ret_valid_i)begin
            rdata_o = ret_data_i[31:0];
        end else if(hit && hit_judge_way0)begin
            rdata_o = inst_way0;
        end else if(hit && hit_judge_way1)begin
            rdata_o = inst_way1;
        end else if(rhit_o)begin
            case(offset_2[3:2])
                2'b00:begin rdata_o = queue_rdata_o[32*1-1: 32*0]; end
                2'b01:begin rdata_o = queue_rdata_o[32*2-1: 32*1]; end
                2'b10:begin rdata_o = queue_rdata_o[32*3-1: 32*2]; end
                2'b11:begin rdata_o = queue_rdata_o[32*4-1: 32*3]; end
                default:begin rdata_o = 32'b0; end
            endcase
        end else if(nhit && ret_valid_i)begin
            rdata_o = read_from_AXI[offset_2[3:2]];
        end else begin
            rdata_o = 32'h0;
        end
    end

    
    //[7:0] rd_len
    assign rd_len = (duncache_2 & rd_req_o) ? 8'h0 : 8'h3;
    //rd_req_o
    assign rd_req_o = nhit & ~ret_valid_i & !(duncache_2 & wvalid_2);
    //[31:0] rd_addr_o
    assign rd_addr_o = duncache_2 ? {ptag_2, index_2, offset_2} : {ptag_2, index_2, 4'b0};
    
    
endmodule

















