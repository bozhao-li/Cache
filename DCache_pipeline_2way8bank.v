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

module DCache_pipeline_2way8bank(
    input clk,
    input rst,
    input wire duncache_i,
    output reg stall_o, 
    
    //Cache port with CPU
    input wire rvalid_i,                //valid request
    input wire [2:0] arsize_i,
    input wire [31:0] paddr_i,  
    input wire wvalid_i,                //1:write, 0:read
    input wire [3:0] wsel_i,            //write enable
    input wire [31:0] wdata_i,    
    
    output reg [31:0] rdata_o,    
    
    //Cache port with AXI
    output wire [7:0] rd_len,
    output wire rd_req_o,              //read valid request
    output wire [31:0] rd_addr_o,     //read initial address
    output wire [2:0] rd_arsize_o,
    input wire ret_valid_i,            //return data valid
    input wire [255:0] ret_data_i,
    
    output wire [7:0] wr_len,
    output wire wr_req_o,          //write valid request 
    output wire [31:0] wr_addr_o,
    output wire [255:0] wr_data_o,
    output wire [3:0] wr_wstrb_o,
    input wire wr_valid_i,
    
    output reg [1:0] judge,
    output reg duncache_2
    
//    //debug
//    output wire [255:0] de_dirty_way0,
//    output wire [255:0] de_dirty_way1,
//    output wire hit_o
    
    );
    
    wire data_ok_o;
    
    //*Cycle 1 and Cycla 2*//
    wire [19:0] ptag_1;
    wire [6:0] index_1;
    wire [4:0] offset_1;
    wire rvalid_1;
    wire wvalid_1;
    wire [3:0] wsel_1;
    wire [31:0] wdata_1;
    
    reg [19:0] ptag_2;
    reg [6:0] index_2;
    reg [4:0] offset_2;
    reg [2:0] arsize_2;
    reg rvalid_2;
    reg wvalid_2;
    reg [3:0] wsel_2;
    reg [31:0] wdata_2;
        
    assign ptag_1 = paddr_i[31:12];
    assign index_1 = paddr_i[11:5];
    assign offset_1 = paddr_i[4:0];
    assign rvalid_1 = rvalid_i;
    assign wvalid_1 = wvalid_i;
    assign wsel_1 = wsel_i;
    assign wdata_1 = wdata_i;
    
    always@(posedge clk)begin
        if(~rst)begin
            rvalid_2 <= 1'b0;
            arsize_2 <= 3'b010;
            wvalid_2 <= 1'b0;
            ptag_2 <= 20'b0;
            index_2 <= 7'b0;
            offset_2 <= 5'b0;
            wsel_2 <= 4'b0;
            wdata_2 <= 32'b0;
            duncache_2 <= 1'b0;
        end else if(stall_o)begin
            rvalid_2 <= rvalid_2;
            arsize_2 <= arsize_2;
            wvalid_2 <= wvalid_2;
            ptag_2 <= ptag_2;
            index_2 <= index_2;
            offset_2 <= offset_2;
            wsel_2 <= wsel_2;
            wdata_2 <= wdata_2;
            duncache_2 <= duncache_2;
        end else begin
            rvalid_2 <= rvalid_1;
            arsize_2 <= arsize_i;
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
    reg [31:0]write_into_Cache[7:0];
    
    wire [6:0] read_addr = stall_o ? index_2 : index_1;
    wire [3:0] wea_way0;
    wire [20:0] way0_tagv;
    wire [31:0] way0_cacheline[7:0];
    wire read_enb0 = ~(|wea_way0 && index_2 == read_addr);
    Tagv_dual_ram_d8 tagv_way0(.addra(index_2), .clka(clk), .dina({1'b1, ptag_2}), .ena(|wea_way0), .wea(|wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_tagv), .enb(read_enb0));
    Data_dual_ram_d8 Bank0_way0(.addra(index_2), .clka(clk), .dina(write_into_Cache[0]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[0]), .enb(read_enb0));
    Data_dual_ram_d8 Bank1_way0(.addra(index_2), .clka(clk), .dina(write_into_Cache[1]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[1]), .enb(read_enb0));
    Data_dual_ram_d8 Bank2_way0(.addra(index_2), .clka(clk), .dina(write_into_Cache[2]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[2]), .enb(read_enb0));
    Data_dual_ram_d8 Bank3_way0(.addra(index_2), .clka(clk), .dina(write_into_Cache[3]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[3]), .enb(read_enb0));
    Data_dual_ram_d8 Bank4_way0(.addra(index_2), .clka(clk), .dina(write_into_Cache[4]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[4]), .enb(read_enb0));
    Data_dual_ram_d8 Bank5_way0(.addra(index_2), .clka(clk), .dina(write_into_Cache[5]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[5]), .enb(read_enb0));
    Data_dual_ram_d8 Bank6_way0(.addra(index_2), .clka(clk), .dina(write_into_Cache[6]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[6]), .enb(read_enb0));
    Data_dual_ram_d8 Bank7_way0(.addra(index_2), .clka(clk), .dina(write_into_Cache[7]), .ena(|wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[7]), .enb(read_enb0));
    
    wire [3:0] wea_way1;
    wire [20:0] way1_tagv;
    wire [31:0] way1_cacheline[7:0];
    wire read_enb1 = ~(|wea_way1 && index_2 == read_addr);   
    Tagv_dual_ram_d8 tagv_way1(.addra(index_2), .clka(clk), .dina({1'b1, ptag_2}), .ena(|wea_way1), .wea(|wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_tagv), .enb(read_enb1));
    Data_dual_ram_d8 Bank0_way1(.addra(index_2), .clka(clk), .dina(write_into_Cache[0]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[0]), .enb(read_enb1));
    Data_dual_ram_d8 Bank1_way1(.addra(index_2), .clka(clk), .dina(write_into_Cache[1]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[1]), .enb(read_enb1));
    Data_dual_ram_d8 Bank2_way1(.addra(index_2), .clka(clk), .dina(write_into_Cache[2]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[2]), .enb(read_enb1));
    Data_dual_ram_d8 Bank3_way1(.addra(index_2), .clka(clk), .dina(write_into_Cache[3]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[3]), .enb(read_enb1));
    Data_dual_ram_d8 Bank4_way1(.addra(index_2), .clka(clk), .dina(write_into_Cache[4]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[4]), .enb(read_enb1));
    Data_dual_ram_d8 Bank5_way1(.addra(index_2), .clka(clk), .dina(write_into_Cache[5]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[5]), .enb(read_enb1));
    Data_dual_ram_d8 Bank6_way1(.addra(index_2), .clka(clk), .dina(write_into_Cache[6]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[6]), .enb(read_enb1));
    Data_dual_ram_d8 Bank7_way1(.addra(index_2), .clka(clk), .dina(write_into_Cache[7]), .ena(|wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[7]), .enb(read_enb1));
     
    
    
    //* LRU *//
    wire hit;                               //hit:1
    wire nhit;
    wire hit_judge_way0;
    wire hit_judge_way1;
        
    reg [127:0] LRU;    //LRU width depends on index
    wire LRU_current = LRU[index_2];
    always@(posedge clk)begin
        if(~rst)begin
            LRU <= 128'b0;
        end else if(hit)begin
            LRU[index_2] <= hit_judge_way0;
        end else if(ret_valid_i & nhit)begin
            LRU[index_2] <= ~LRU_current;
        end else begin
            LRU <= LRU;     
        end
    end
    
    
    
    //Dirty signal
    reg [127:0] dirty_way0;
    reg [127:0] dirty_way1;
    wire write_dirty = (LRU_current == 0) ? dirty_way0[index_2] : dirty_way1[index_2];
    always@(posedge clk)begin
        if(~rst)begin
            dirty_way0 <= 128'b0;
            dirty_way1 <= 128'b0;
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
    
    //* WriteBuffer *//
    wire queue_wreq_i;
    
    wire [31:0] queue_waddr_i;
    wire [31:0] queue_waddr_temp;
    reg [31:0] queue_waddr_ff = 32'b0;
    
    wire [255:0] queue_wdata_i;
    reg [255:0] queue_wdata_temp;
    reg [255:0] queue_wdata_ff = 256'b0;
    
    wire whit_o;
    wire rhit_o;
    wire [255:0] queue_rdata_o ;
    wire [1:0] state_o;
    
    reg [20:0]tagv_way0_2;
    reg [20:0]tagv_way1_2;
    
    reg write_stall;
        
    wire write_stall_cond = ret_valid_i & wr_valid_i & judge[1] ? 1'b0 :
                             ret_valid_i & &state_o & write_dirty & ~duncache_2;
    //queue_wreq_i
    assign queue_wreq_i = (rhit_o == 1'b1 && wvalid_2 == 1'b1) ? 1'b1:
                          (ret_valid_i & wr_valid_i & judge[1]) ? 1'b1 :
                          (ret_valid_i && state_o != 2'b11 && write_dirty && ~duncache_2)? 1'b1: 
                          (wr_valid_i & write_stall);
                          
    assign queue_waddr_i = write_stall ? queue_waddr_ff : queue_waddr_temp;
    assign queue_wdata_i = write_stall ? queue_wdata_ff : queue_wdata_temp;
             
             
    wire [20:0]tagv_final_way0;
    wire [20:0]tagv_final_way1;
    
    //queue_waddr_temp
    assign queue_waddr_temp = (rhit_o == 1'b1 && wvalid_2 == 1'b1) ? {ptag_2, index_2, offset_2} : 
                                (LRU_current == 1'b1)?  {tagv_final_way1[19:0], index_2, offset_2}:
                                {tagv_final_way0[19:0], index_2, offset_2};
                           
    always @(posedge clk) begin
        if (write_stall) begin
            queue_waddr_ff <= queue_waddr_ff;
            queue_wdata_ff <= queue_wdata_ff;
        end else begin
            queue_waddr_ff <= queue_waddr_temp;
            queue_wdata_ff <= queue_wdata_temp;
        end
    end
    
    reg [7:0] wsel_into_FIFO;
    always @(*)begin
        if(rhit_o == 1'b1 && wvalid_2 == 1'b1)begin
            case(offset_2[4:2])
                3'b000:wsel_into_FIFO = 8'b00000001;
                3'b001:wsel_into_FIFO = 8'b00000010;
                3'b010:wsel_into_FIFO = 8'b00000100;
                3'b011:wsel_into_FIFO = 8'b00001000;
                3'b100:wsel_into_FIFO = 8'b00010000;
                3'b101:wsel_into_FIFO = 8'b00100000;
                3'b110:wsel_into_FIFO = 8'b01000000;
                3'b111:wsel_into_FIFO = 8'b10000000;
                default:wsel_into_FIFO = 8'b00000000;
            endcase
        end else begin
            wsel_into_FIFO = 8'b11111111;
        end
    end
    
    //queue_wdata_temp
    always@(*)begin
        if(ret_valid_i)begin    //write back
            if(LRU_current)begin
                queue_wdata_temp = {way1_cacheline[7], way1_cacheline[6], way1_cacheline[5], way1_cacheline[4], way1_cacheline[3], way1_cacheline[2], way1_cacheline[1], way1_cacheline[0]};
            end else begin
                queue_wdata_temp = {way0_cacheline[7], way0_cacheline[6], way0_cacheline[5], way0_cacheline[4], way0_cacheline[3], way0_cacheline[2], way0_cacheline[1], way0_cacheline[0]};
            end
        end else if(wvalid_2 && rhit_o)begin
            case(offset_2[4:2])
                3'b000:begin queue_wdata_temp = {write_into_Cache[7], write_into_Cache[6], write_into_Cache[5], write_into_Cache[4], write_into_Cache[3], write_into_Cache[2], write_into_Cache[1], wdata_2}; end
                3'b001:begin queue_wdata_temp = {write_into_Cache[7], write_into_Cache[6], write_into_Cache[5], write_into_Cache[4], write_into_Cache[3], write_into_Cache[2], wdata_2, write_into_Cache[0]}; end
                3'b010:begin queue_wdata_temp = {write_into_Cache[7], write_into_Cache[6], write_into_Cache[5], write_into_Cache[4], write_into_Cache[3], wdata_2, write_into_Cache[1], write_into_Cache[0]}; end
                3'b011:begin queue_wdata_temp = {write_into_Cache[7], write_into_Cache[6], write_into_Cache[5], write_into_Cache[4], wdata_2, write_into_Cache[2], write_into_Cache[1], write_into_Cache[0]}; end
                3'b100:begin queue_wdata_temp = {write_into_Cache[7], write_into_Cache[6], write_into_Cache[5], wdata_2, write_into_Cache[3], write_into_Cache[2], write_into_Cache[1], write_into_Cache[0]}; end
                3'b101:begin queue_wdata_temp = {write_into_Cache[7], write_into_Cache[6], wdata_2, write_into_Cache[4], write_into_Cache[3], write_into_Cache[2], write_into_Cache[1], write_into_Cache[0]}; end
                3'b110:begin queue_wdata_temp = {write_into_Cache[7], wdata_2, write_into_Cache[5], write_into_Cache[4], write_into_Cache[3], write_into_Cache[2], write_into_Cache[1], write_into_Cache[0]}; end
                3'b111:begin queue_wdata_temp = {wdata_2, write_into_Cache[6], write_into_Cache[5], write_into_Cache[4], write_into_Cache[3], write_into_Cache[2], write_into_Cache[1], write_into_Cache[0]}; end
                default:    ;
            endcase
        end else begin
            queue_wdata_temp = 256'b0;
        end
    end
    
    
    //UnCache
    wire UnCache_req;
    wire [255:0] UnCache_data;
    wire [31:0] UnCache_addr;
    
    assign UnCache_req = (wr_valid_i && judge[0]) ? 1'b0 :  
                         (duncache_2 & wvalid_2);
    assign UnCache_data = (duncache_2 & wr_req_o) ? {8{wdata_2}}: 256'b0;
    assign UnCache_addr = (duncache_2 & wr_req_o) ? {ptag_2, index_2, offset_2[4:2], 2'b00} : 32'b0;    
    
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
    

    
    wire [255:0] FIFO_data;
    wire [31:0] FIFO_addr;
    WriteBuffer_8bank WriteBuffer_8bank_u(.clk(clk), .rst(rst), .judge(judge),  .duncache_i(duncache_2),
        
                              .wreq_i(queue_wreq_i), .waddr_i(queue_waddr_i), .wdata_i(queue_wdata_i), 
                              .wsel(wsel_into_FIFO), .whit_o(whit_o), 
                              .rreq_i(rvalid_2 || wvalid_2), .raddr_i({ptag_2, index_2, offset_2}), .rhit_o(rhit_o), .rdata_o(queue_rdata_o), 
                              .state_o(state_o), 
                              
                              .AXI_valid_i(wr_valid_i), .AXI_wen_o(FIFO_req), 
                              .AXI_wdata_o(FIFO_data), .AXI_waddr_o(FIFO_addr));
    
    always @(posedge clk) begin
        if (~rst)
            write_stall <= 1'b0;
        else if (wr_valid_i & judge[1])
            write_stall <= 1'b0;
        else if (write_stall_cond)
            write_stall <= 1'b1;
    end
    
    assign wr_len = (judge[0] & wr_req_o) ? 8'h0 : 8'h7;
    
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
      write_into_Cache_inst_2 <= write_into_Cache[offset_1[4:2]];
      tagv_way0_2 <= {1'b1,ptag_2};
      tagv_way1_2 <= {1'b1,ptag_2};
    end
    
    reg [31:0] write_into_Cache_ff [7:0];
    always @(posedge clk) begin
//        if (~rst) begin
//            write_into_Cache_ff[7] <= 32'b0;
//            write_into_Cache_ff[6] <= 32'b0;
//            write_into_Cache_ff[5] <= 32'b0;
//            write_into_Cache_ff[4] <= 32'b0;
//            write_into_Cache_ff[3] <= 32'b0;
//            write_into_Cache_ff[2] <= 32'b0;
//            write_into_Cache_ff[1] <= 32'b0;
//            write_into_Cache_ff[0] <= 32'b0;
//        end else begin
        write_into_Cache_ff[7] <= write_into_Cache[7];
        write_into_Cache_ff[6] <= write_into_Cache[6];
        write_into_Cache_ff[5] <= write_into_Cache[5];
        write_into_Cache_ff[4] <= write_into_Cache[4];
        write_into_Cache_ff[3] <= write_into_Cache[3];
        write_into_Cache_ff[2] <= write_into_Cache[2];
        write_into_Cache_ff[1] <= write_into_Cache[1];
        write_into_Cache_ff[0] <= write_into_Cache[0];
//        end
    end
    
    //* logics *//
    //////////inner logics
    wire [31:0]read_from_AXI[7:0];
    for(genvar i = 0 ;i < 8; i = i + 1)begin
            assign read_from_AXI[i] = ret_data_i[32*(i+1)-1:32*i];
    end
    //data_select
    wire [31:0]inst_way0 = collision_way0 ? write_into_Cache_inst_2 : 
                             way0_tagv[20] ? way0_cacheline[offset_2[4:2]] : 32'b0;     //cache address partition in page 228
    wire [31:0]inst_way1 = collision_way1 ? write_into_Cache_inst_2 : 
                             way1_tagv[20] ? way1_cacheline[offset_2[4:2]] : 32'b0;
    assign tagv_final_way0 = collision_way0 ? tagv_way0_2 : way0_tagv;
    assign tagv_final_way1 = collision_way1 ? tagv_way1_2 : way1_tagv;
    
    //hit
    assign hit_judge_way0 = (tagv_final_way0[20] != 1'b1) ? 1'b0 : 
                            (ptag_2 == tagv_final_way0[19:0]) ? 1'b1 : 1'b0;
    assign hit_judge_way1 = (tagv_final_way1[20] != 1'b1) ? 1'b0 : 
                            (ptag_2 == tagv_final_way1[19:0]) ? 1'b1 : 1'b0;
    assign hit = (hit_judge_way0 | hit_judge_way1 | rhit_o|whit_o) && (rvalid_2||wvalid_2) && ~duncache_2;
    assign nhit = write_stall ? 1'b0 : ~hit && (rvalid_2||wvalid_2);
    
//    assign hit_o = hit;
    
    //write_into_Cache
    wire [31:0]wsel_expand;
    assign wsel_expand={{8{wsel_2[3]}} , {8{wsel_2[2]}} , {8{wsel_2[1]}} , {8{wsel_2[0]}}};
    always @(*)begin
        if(hit)begin        //////hit write
            if(hit_judge_way0)begin
                write_into_Cache[7] = collision_way0 ? write_into_Cache_ff[7] : way0_cacheline[7];
                write_into_Cache[6] = collision_way0 ? write_into_Cache_ff[6] : way0_cacheline[6];
                write_into_Cache[5] = collision_way0 ? write_into_Cache_ff[5] : way0_cacheline[5];
                write_into_Cache[4] = collision_way0 ? write_into_Cache_ff[4] : way0_cacheline[4];
                write_into_Cache[3] = collision_way0 ? write_into_Cache_ff[3] : way0_cacheline[3];
                write_into_Cache[2] = collision_way0 ? write_into_Cache_ff[2] : way0_cacheline[2];
                write_into_Cache[1] = collision_way0 ? write_into_Cache_ff[1] : way0_cacheline[1];
                write_into_Cache[0] = collision_way0 ? write_into_Cache_ff[0] : way0_cacheline[0];
                write_into_Cache[offset_2[4:2]] = (wdata_2 & wsel_expand)|((collision_way0 ? write_into_Cache_ff[offset_2[4:2]] : way0_cacheline[offset_2[4:2]]) & ~wsel_expand);
            end else if(hit_judge_way1)begin
                write_into_Cache[7] = collision_way1 ? write_into_Cache_ff[7] : way1_cacheline[7];
                write_into_Cache[6] = collision_way1 ? write_into_Cache_ff[6] : way1_cacheline[6];
                write_into_Cache[5] = collision_way1 ? write_into_Cache_ff[5] : way1_cacheline[5];
                write_into_Cache[4] = collision_way1 ? write_into_Cache_ff[4] : way1_cacheline[4];
                write_into_Cache[3] = collision_way1 ? write_into_Cache_ff[3] : way1_cacheline[3];
                write_into_Cache[2] = collision_way1 ? write_into_Cache_ff[2] : way1_cacheline[2];
                write_into_Cache[1] = collision_way1 ? write_into_Cache_ff[1] : way1_cacheline[1];
                write_into_Cache[0] = collision_way1 ? write_into_Cache_ff[0] : way1_cacheline[0];
                write_into_Cache[offset_2[4:2]] = (wdata_2 & wsel_expand)|((collision_way1 ? write_into_Cache_ff[offset_2[4:2]] : way1_cacheline[offset_2[4:2]]) & ~wsel_expand);
            end else begin
                write_into_Cache[7] = way1_cacheline[7];
                write_into_Cache[6] = way1_cacheline[6];
                write_into_Cache[5] = way1_cacheline[5];
                write_into_Cache[4] = way1_cacheline[4];
                write_into_Cache[3] = way1_cacheline[3];
                write_into_Cache[2] = way1_cacheline[2];
                write_into_Cache[1] = way1_cacheline[1];
                write_into_Cache[0] = way1_cacheline[0];
            end
        end else if(rhit_o|whit_o)begin    //////hit queue
            write_into_Cache[7] = queue_rdata_o[32*8-1: 32*7];
            write_into_Cache[6] = queue_rdata_o[32*7-1: 32*6];
            write_into_Cache[5] = queue_rdata_o[32*6-1: 32*5];
            write_into_Cache[4] = queue_rdata_o[32*5-1: 32*4];
            write_into_Cache[3] = queue_rdata_o[32*4-1: 32*3];
            write_into_Cache[2] = queue_rdata_o[32*3-1: 32*2];
            write_into_Cache[1] = queue_rdata_o[32*2-1: 32*1];
            write_into_Cache[0] = queue_rdata_o[32*1-1: 32*0];
            write_into_Cache[offset_2[4:2]] = wdata_2;
        end else if(nhit && rvalid_2)begin      //read not hit
            write_into_Cache[7] = read_from_AXI[7];
            write_into_Cache[6] = read_from_AXI[6];
            write_into_Cache[5] = read_from_AXI[5];
            write_into_Cache[4] = read_from_AXI[4];
            write_into_Cache[3] = read_from_AXI[3];
            write_into_Cache[2] = read_from_AXI[2];
            write_into_Cache[1] = read_from_AXI[1];
            write_into_Cache[0] = read_from_AXI[0];
        end else if(nhit)begin      //write not hit
            write_into_Cache[7] = read_from_AXI[7];
            write_into_Cache[6] = read_from_AXI[6];
            write_into_Cache[5] = read_from_AXI[5];
            write_into_Cache[4] = read_from_AXI[4];
            write_into_Cache[3] = read_from_AXI[3];
            write_into_Cache[2] = read_from_AXI[2];
            write_into_Cache[1] = read_from_AXI[1];
            write_into_Cache[0] = read_from_AXI[0];
            write_into_Cache[offset_2[4:2]] = (wdata_2 & wsel_expand)|(read_from_AXI[offset_2[4:2]] & ~wsel_expand);
        end else begin
            write_into_Cache[7] = 32'b0;
            write_into_Cache[6] = 32'b0;
            write_into_Cache[5] = 32'b0;
            write_into_Cache[4] = 32'b0;
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
        end else if (write_stall | write_stall_cond) begin
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
            case(offset_2[4:2])
                3'b000:begin rdata_o = queue_rdata_o[32*1-1: 32*0]; end
                3'b001:begin rdata_o = queue_rdata_o[32*2-1: 32*1]; end
                3'b010:begin rdata_o = queue_rdata_o[32*3-1: 32*2]; end
                3'b011:begin rdata_o = queue_rdata_o[32*4-1: 32*3]; end
                3'b100:begin rdata_o = queue_rdata_o[32*5-1: 32*4]; end
                3'b101:begin rdata_o = queue_rdata_o[32*6-1: 32*5]; end
                3'b110:begin rdata_o = queue_rdata_o[32*7-1: 32*6]; end
                3'b111:begin rdata_o = queue_rdata_o[32*8-1: 32*7]; end
                default:begin rdata_o = 32'b0; end
            endcase
        end else if(nhit && ret_valid_i)begin
            rdata_o = read_from_AXI[offset_2[4:2]];
        end else begin
            rdata_o = 32'h0;
        end
    end

    
    //[7:0] rd_len
    assign rd_len = (duncache_2 & rd_req_o) ? 8'h0 : 8'h7;
    //rd_req_o
    assign rd_req_o = nhit & ~ret_valid_i & !(duncache_2 & wvalid_2);
    //[31:0] rd_addr_o
    assign rd_addr_o = duncache_2 ? {ptag_2, index_2, offset_2} : {ptag_2, index_2, 5'b0};
    
    assign rd_arsize_o = duncache_2 ? arsize_2 : 3'b010;
    
    
endmodule
















