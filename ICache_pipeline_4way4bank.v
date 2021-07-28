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
/*TODO:valid在rst时清空， cache指令， 同时读写时特判*/
module ICache_pipeline_4way4bank(
    input wire clk,
    input wire rst,
    input wire iuncache_i,
    output wire stall, 
    input wire flush,
    
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
    
    // with BPU
//    input wire fpredict_flag1,
//	input wire fpredict_flag2,
//    input wire [32:0] spredict_pkt1,
//    input wire [32:0] spredict_pkt2,
//    input wire [34:0] predict_pkti1,
//    input wire [34:0] predict_pkti2,
//    input wire instbuffer_full,
//    output wire [34:0] predict_pkto1,
//    output wire [34:0] predict_pkto2,
//    output reg [31:0] icache_npc,
    
    //Cache port with AXI
    output reg iuncache_2,
    output wire [7:0] rd_len,
    output wire rd_req,          //read valid request
    output wire [31:0] rd_addr,  //read initial address
    input wire ret_valid        //return data valid
//    input wire [127:0] ret_data
    
    );
    wire fpredict_flag1;
    wire fpredict_flag2;
    wire [32:0] spredict_pkt1;
    wire [32:0] spredict_pkt2;
    wire [34:0] predict_pkti1;
    wire [34:0] predict_pkti2;
    wire instbuffer_full;
    wire [34:0] predict_pkto1;
    wire [34:0] predict_pkto2;
    reg [31:0] icache_npc;
    wire [127:0] ret_data;
    
    
    
    wire [20:0] ptag_1;
    wire [6:0] index_1;
    wire [3:0] offset_1;
    wire valid_1;
    wire [31:0] vaddr_i1_1;
    wire [31:0] vaddr_i2_1;
    
    reg [20:0] ptag_2;
    reg [6:0] index_2;
    reg [3:0] offset_2;
    reg valid_2;
    reg [31:0] vaddr_i1_2;
    reg [31:0] vaddr_i2_2;
    
    // branch_predict
//    reg [31:0] inst_delayslot_addr, inst_delayslot_addr_ff;
    reg keep_pta, keep_pta_ff;
    reg inst_delayslot, inst_delayslot_ff;
    reg instbuffer_full_ff;
    reg fpredict_flag1_ff, fpredict_flag2_ff;
    reg [32:0] spredict_pkt1_ff, spredict_pkt2_ff;
    reg [31:0] icache_npc_ff;
    reg [34:0] predict_pkti1_2, predict_pkti2_2;
    reg inst_delayslot_fetch;  // 为1表示取到了延迟槽指令
    reg inst_delayslot_fetch_ff;
    
    wire predict_dir1 = predict_pkti1[34];
    wire predict_dir1_2 = predict_pkti1_2[34];
    wire predict_dir2_2 = predict_pkti2_2[34];
    wire [31:0] predict_pta1 = predict_pkti1[33:2];
    wire spredict_dir1 = spredict_pkt1[32];
    wire spredict_dir2 = spredict_pkt2[32];
    wire [31:0] spredict_pta1 = spredict_pkt1[31:0];
    wire [31:0] spredict_pta2 = spredict_pkt2[31:0];
    
    assign ptag_1 = paddr_i[31:11];
    assign index_1 = paddr_i[10:4];
    assign offset_1 = paddr_i[3:0];
    assign valid_1 = valid;
    assign vaddr_i1_1 = vaddr_i1;
    assign vaddr_i2_1 = vaddr_i2;
    
    //* Cache main part: Tagv + Data *//
    
    //each way: 1 TagV(256*21), [1 D(256*1)], 4 DataBank(256*32)
    wire [6:0] read_addr = stall ? index_2 : index_1;
    wire wea_way0;
    wire [21:0] way0_tagv;
    wire [31:0] way0_cacheline[3:0];
//    wire rsta_busy1;
//    wire rstb_busy1;
    wire read_enb0 = ~(wea_way0 && index_2 == read_addr);
//    Tagv_dual_ram tagv_way0(.addra(index_2), .clka(clk), .dina({1'b1, ptag_2}), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_tagv), .enb(read_enb0), .rstb(~rst), .rsta_busy(rsta_busy1), .rstb_busy(rstb_busy1));
    dram_tagv tagv_way0(.a(index_2), .d({1'b1, ptag_2}), .dpra(index_1), .clk(clk), .we(wea_way0), .dpo(way0_tagv));
    Data_dual_ram_i Bank0_way0(.addra(index_2), .clka(clk), .dina(read_from_AXI[0]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[0]), .enb(read_enb0));
    Data_dual_ram_i Bank1_way0(.addra(index_2), .clka(clk), .dina(read_from_AXI[1]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[1]), .enb(read_enb0));
    Data_dual_ram_i Bank2_way0(.addra(index_2), .clka(clk), .dina(read_from_AXI[2]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[2]), .enb(read_enb0));
    Data_dual_ram_i Bank3_way0(.addra(index_2), .clka(clk), .dina(read_from_AXI[3]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[3]), .enb(read_enb0));
    
    wire wea_way1;
    wire [21:0] way1_tagv;
    wire [31:0] way1_cacheline[3:0];
//    wire rsta_busy2;
//    wire rstb_busy2;
    wire read_enb1 = ~(wea_way1 && index_2 == read_addr);   
    dram_tagv tagv_way1(.a(index_2), .d({1'b1, ptag_2}), .dpra(index_1), .clk(clk), .we(wea_way1), .dpo(way1_tagv));
//    Tagv_dual_ram tagv_way1(.addra(index_2), .clka(clk), .dina({1'b1, ptag_2}), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_tagv), .enb(read_enb1), .rstb(~rst), .rsta_busy(rsta_busy2), .rstb_busy(rstb_busy2));
    Data_dual_ram_i Bank0_way1(.addra(index_2), .clka(clk), .dina(read_from_AXI[0]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[0]), .enb(read_enb1));
    Data_dual_ram_i Bank1_way1(.addra(index_2), .clka(clk), .dina(read_from_AXI[1]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[1]), .enb(read_enb1));
    Data_dual_ram_i Bank2_way1(.addra(index_2), .clka(clk), .dina(read_from_AXI[2]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[2]), .enb(read_enb1));
    Data_dual_ram_i Bank3_way1(.addra(index_2), .clka(clk), .dina(read_from_AXI[3]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[3]), .enb(read_enb1));
    
    wire wea_way2;
    wire [21:0] way2_tagv;
    wire [31:0] way2_cacheline[3:0];
    wire read_enb2 = ~(wea_way2 && index_2 == read_addr);   
    dram_tagv tagv_way2(.a(index_2), .d({1'b1, ptag_2}), .dpra(index_1), .clk(clk), .we(wea_way2), .dpo(way2_tagv));
    Data_dual_ram_i Bank0_way2(.addra(index_2), .clka(clk), .dina(read_from_AXI[0]), .ena(wea_way2), .wea(wea_way2), .addrb(read_addr), .clkb(clk), .doutb(way2_cacheline[0]), .enb(read_enb2));
    Data_dual_ram_i Bank1_way2(.addra(index_2), .clka(clk), .dina(read_from_AXI[1]), .ena(wea_way2), .wea(wea_way2), .addrb(read_addr), .clkb(clk), .doutb(way2_cacheline[1]), .enb(read_enb2));
    Data_dual_ram_i Bank2_way2(.addra(index_2), .clka(clk), .dina(read_from_AXI[2]), .ena(wea_way2), .wea(wea_way2), .addrb(read_addr), .clkb(clk), .doutb(way2_cacheline[2]), .enb(read_enb2));
    Data_dual_ram_i Bank3_way2(.addra(index_2), .clka(clk), .dina(read_from_AXI[3]), .ena(wea_way2), .wea(wea_way2), .addrb(read_addr), .clkb(clk), .doutb(way2_cacheline[3]), .enb(read_enb2));
    
    wire wea_way3;
    wire [21:0] way3_tagv;
    wire [31:0] way3_cacheline[3:0];
    wire read_enb3 = ~(wea_way3 && index_2 == read_addr);   
    dram_tagv tagv_way3(.a(index_2), .d({1'b1, ptag_2}), .dpra(index_1), .clk(clk), .we(wea_way3), .dpo(way3_tagv));
    Data_dual_ram_i Bank0_way3(.addra(index_2), .clka(clk), .dina(read_from_AXI[0]), .ena(wea_way3), .wea(wea_way3), .addrb(read_addr), .clkb(clk), .doutb(way3_cacheline[0]), .enb(read_enb3));
    Data_dual_ram_i Bank1_way3(.addra(index_2), .clka(clk), .dina(read_from_AXI[1]), .ena(wea_way3), .wea(wea_way3), .addrb(read_addr), .clkb(clk), .doutb(way3_cacheline[1]), .enb(read_enb3));
    Data_dual_ram_i Bank2_way3(.addra(index_2), .clka(clk), .dina(read_from_AXI[2]), .ena(wea_way3), .wea(wea_way3), .addrb(read_addr), .clkb(clk), .doutb(way3_cacheline[2]), .enb(read_enb3));
    Data_dual_ram_i Bank3_way3(.addra(index_2), .clka(clk), .dina(read_from_AXI[3]), .ena(wea_way3), .wea(wea_way3), .addrb(read_addr), .clkb(clk), .doutb(way3_cacheline[3]), .enb(read_enb3));
            
    //hit
    reg hit;                               //hit:1
    reg nhit;
    reg [1:0] hit_judge_way;
    
    wire hit_1;
    wire nhit_1;      
    wire hit_judge_way0_1;
    wire hit_judge_way1_1;
    wire hit_judge_way2_1;
    wire hit_judge_way3_1;
    
    //* Hit Pipeline: 2 states, Idle and LookUp*//
    //* Not Hit: stall pipeline *//
    
    always@(posedge clk)begin
        if(~rst | flush)begin
            valid_2 <= 1'b0;
            ptag_2 <= 21'b0;
            index_2 <= 7'b0;
            offset_2 <= 4'b0;
            vaddr_i1_2 <= 32'h0;
            vaddr_i2_2 <= 32'h0;
            iuncache_2 <= 1'b0;
            keep_pta_ff <= 1'b0;
            predict_pkti1_2 <= 35'b0;
            predict_pkti2_2 <= 35'b0;
            instbuffer_full_ff <= 1'b0;
            fpredict_flag1_ff <= 1'b1;
            fpredict_flag2_ff <= 1'b1;
            spredict_pkt1_ff <= 33'b0;
            spredict_pkt2_ff <= 33'b0;
            hit <= 1'b0;
            nhit <= 1'b0;
            hit_judge_way <= 2'b0;    
        end else if(stall)begin
            valid_2 <= valid_2;
            ptag_2 <= ptag_2;
            index_2 <= index_2;
            offset_2 <= offset_2;
            vaddr_i1_2 <= vaddr_i1_2;
            vaddr_i2_2 <= vaddr_i2_2;
            iuncache_2 <= iuncache_2;
            keep_pta_ff <= keep_pta_ff;
            predict_pkti1_2 <= predict_pkti1_2;
            predict_pkti2_2 <= predict_pkti2_2;
            instbuffer_full_ff <= instbuffer_full_ff;
            fpredict_flag1_ff <= fpredict_flag1_ff;
            fpredict_flag2_ff <= fpredict_flag2_ff;
            spredict_pkt1_ff <= spredict_pkt1_ff;
            spredict_pkt2_ff <= spredict_pkt2_ff;
            hit <= hit;
            nhit <= nhit;
            hit_judge_way <= hit_judge_way;
        end else begin
            valid_2 <= valid_1;
            ptag_2 <= ptag_1;
            index_2 <= index_1;
            offset_2 <= offset_1;
            vaddr_i1_2 <= vaddr_i1_1;
            vaddr_i2_2 <= vaddr_i2_1;
            iuncache_2 <= iuncache_i;
            keep_pta_ff <= keep_pta;
            predict_pkti1_2 <= predict_pkti1;
            predict_pkti2_2 <= predict_pkti2;
            instbuffer_full_ff <= instbuffer_full;
            fpredict_flag1_ff <= fpredict_flag1;
            fpredict_flag2_ff <= fpredict_flag2;
            spredict_pkt1_ff <= spredict_pkt1;
            spredict_pkt2_ff <= spredict_pkt2;
            hit <= hit_1;
            nhit <= nhit_1;
            hit_judge_way <= hit_judge_way1_1 + 2*hit_judge_way2_1 + 3*hit_judge_way3_1;
        end
    end

    
    always @(posedge clk) begin
        if (~rst | flush) begin
            icache_npc_ff <= 32'b0;
            inst_delayslot_fetch_ff <= 1'b1;
            inst_delayslot_ff <= 1'b0;
        end else begin
            icache_npc_ff <= icache_npc;
            inst_delayslot_fetch_ff <= inst_delayslot_fetch;
            inst_delayslot_ff <= inst_delayslot;
        end
    end
       
    wire data_ok_for_delayslot =  (iuncache_2 && ret_valid) ? 1'b1 :
                                   hit ? 1'b1 : 
                                   (nhit && ret_valid) ? 1'b1: 
                                   1'b0;
   
    // icache_npc
    always @(*) begin
        if (~rst)                                                               icache_npc = 32'hbfc00000;
        else if (~fpredict_flag1 & spredict_dir1 & data_ok1)                    icache_npc = spredict_pta1;
        else if (~fpredict_flag1 & ~spredict_dir1 & data_ok2)                   icache_npc = vaddr_i1_2 + 32'h8;
        else if (fpredict_flag1 & spredict_dir1 & data_ok1 & ~data_ok2)         icache_npc = spredict_pta1;    
        else if ((~fpredict_flag2 | predict_dir2_2) & spredict_dir2 & data_ok2) icache_npc = spredict_pta2;
        else if (instbuffer_full_ff)                                            icache_npc = icache_npc_ff;
//        else if (predict_dir1 & ~(iuncache_i | &offset_1[3:2]))                 icache_npc = predict_pta1;
        else if (iuncache_2 & ~keep_pta)                                        icache_npc = vaddr_i2_2;
        else if (stall)                                                         icache_npc = vaddr_i1;  // 暂停则保持
        else if (predict_dir1 & ~(iuncache_i | &offset_1[3:2]))                 icache_npc = predict_pta1;
        else if (&offset_1[3:2])                                                icache_npc = vaddr_i1 + 32'h4;  // 不同字块时，为pc+4
        else                                                                    icache_npc = vaddr_i1 + 32'h8;
    end
    
    // inst_delayslot
    always @(*) begin
        if (~rst) begin
            inst_delayslot = 1'b0;
            inst_delayslot_fetch = 1'b1;
            keep_pta = 1'b0;
        end else if (~inst_delayslot_fetch_ff & data_ok_for_delayslot) begin
            inst_delayslot = inst_delayslot_ff;
            inst_delayslot_fetch = 1'b1;
            keep_pta = 1'b0;
        end else if (inst_delayslot_fetch_ff & inst_delayslot_ff & data_ok1) begin
            inst_delayslot = 1'b0;
            inst_delayslot_fetch = 1'b1;
            keep_pta = 1'b0;
        end else if (~fpredict_flag1 & data_ok2) begin
            inst_delayslot = 1'b0;
            inst_delayslot_fetch = 1'b0;
            keep_pta = 1'b1;
        end else if (~fpredict_flag1 & spredict_dir1 & data_ok1) begin
            inst_delayslot = 1'b1;
            inst_delayslot_fetch = 1'b1;
            keep_pta = 1'b1;
        end else if (fpredict_flag1 & spredict_dir1 & data_ok1 & ~data_ok2) begin
            inst_delayslot = 1'b1;
            inst_delayslot_fetch = 1'b1;
            keep_pta = 1'b1;
        end else if (spredict_dir2 & data_ok2) begin
            inst_delayslot = 1'b1;
            inst_delayslot_fetch = 1'b1;
            keep_pta = 1'b1;
        end else if (data_ok_for_delayslot) begin
            inst_delayslot = inst_delayslot_ff;
            inst_delayslot_fetch = inst_delayslot_fetch_ff;
            keep_pta = 1'b0;
        end else begin
            inst_delayslot = inst_delayslot_ff;
            inst_delayslot_fetch = inst_delayslot_fetch_ff;
            keep_pta = keep_pta_ff;
        end
    end
    
    assign predict_pkto1 = predict_pkti1_2;
    assign predict_pkto2 = predict_pkti2_2;
   
    
    //* LRU *//
    reg [127:0] LRU_1;
    reg [255:0] LRU_2;//单数：1-127，双数：128-255
    wire LRU_current_1 = LRU_1[index_2];
    wire LRU_current_2 = LRU_2[index_2];
    wire LRU_current_3 = LRU_2[index_2+'h80];
    //LRU_1 = 0 & LRU_2 = 0 : way0
    //LRU_1 = 0 & LRU_2 = 1 : way1
    //LRU_1 = 1 & LRU_2 = 0 : way2
    //LRU_1 = 1 & LRU_2 = 1 : way3
    always@(posedge clk)begin
        if(~rst)begin
            LRU_1 <= 128'b0;
        end else if(data_ok_for_delayslot && hit)begin
            LRU_1[index_2] <= (hit_judge_way[0] | hit_judge_way[1]);
        end else if(data_ok_for_delayslot && !hit)begin
            LRU_1[index_2] <= (wea_way0 | wea_way1);
        end else begin
            LRU_1 <= LRU_1;
        end
    end
    always@(posedge clk)begin
        if(~rst)begin
            LRU_2 <= 256'b0;
        end else if(data_ok_for_delayslot && hit)begin
            if(hit_judge_way[0] | hit_judge_way[1])begin
                LRU_2[index_2] <= hit_judge_way[0];
            end else begin
                LRU_2[index_2+'h80] <= hit_judge_way[2];
            end
        end else if(data_ok_for_delayslot && !hit)begin
            if(wea_way0 | wea_way1)begin
                LRU_2[index_2] <= wea_way0;
            end else begin
                LRU_2[index_2+'h80] <= wea_way2;
            end
        end else begin
            LRU_2 <= LRU_2;
        end
    end
    
    wire [31:0]read_from_AXI[3:0];
    for(genvar i = 0 ;i < 4; i = i+1) begin
        assign read_from_AXI[i] = ret_data[32*(i+1)-1:32*i];
    end
    
    // collision 
    reg collision_way0;
    reg collision_way1;
    reg collision_way2;
    reg collision_way3;
    reg [31:0]inst1_from_mem_2;
    reg [31:0]inst2_from_mem_2;
    reg [21:0]tagv_way0_2;
    reg [21:0]tagv_way1_2;
    reg [21:0]tagv_way2_2;
    reg [21:0]tagv_way3_2;
    
    always@(posedge clk)begin
        collision_way0 <= (wea_way0 && index_1 == index_2);
        collision_way1 <= (wea_way1 && index_1 == index_2);
        collision_way2 <= (wea_way2 && index_1 == index_2);
        collision_way3 <= (wea_way3 && index_1 == index_2);
        inst1_from_mem_2 <= read_from_AXI[offset_1[3:2]];
        inst2_from_mem_2 <= read_from_AXI[offset_1[3:2]+3'h1];
        tagv_way0_2 <= {1'b1,ptag_2};
        tagv_way1_2 <= {1'b1,ptag_2};
        tagv_way2_2 <= {1'b1,ptag_2};
        tagv_way3_2 <= {1'b1,ptag_2};
    end
    
    //*logics*//
    //////////inner logics
    assign wea_way0 = (ret_valid && LRU_current_1 == 1'b0 && LRU_current_2 == 1'b0 && ~iuncache_2);
    assign wea_way1 = (ret_valid && LRU_current_1 == 1'b0 && LRU_current_2 == 1'b1 && ~iuncache_2);
    assign wea_way2 = (ret_valid && LRU_current_1 == 1'b1 && LRU_current_3 == 1'b0 && ~iuncache_2);
    assign wea_way3 = (ret_valid && LRU_current_1 == 1'b1 && LRU_current_3 == 1'b1 && ~iuncache_2);
    
    
    //data select
    wire [31:0] inst1_way[3:0];
    wire [31:0] inst2_way[3:0];
    assign inst1_way[0] = collision_way0 ? inst1_from_mem_2 : way0_cacheline[offset_2[3:2]];     //cache address partition in page 228
    assign inst2_way[0] = ~(|raddr2[3:0]) ? 32'b0 : collision_way0 ? inst2_from_mem_2 : way0_cacheline[offset_2[3:2] + 'b1];
    assign inst1_way[1] = collision_way1 ? inst1_from_mem_2 : way1_cacheline[offset_2[3:2]];
    assign inst2_way[1] = ~(|raddr2[3:0]) ? 32'b0 : collision_way1 ? inst2_from_mem_2 : way1_cacheline[offset_2[3:2] + 'b1];
    assign inst1_way[2] = collision_way2 ? inst1_from_mem_2 : way2_cacheline[offset_2[3:2]];
    assign inst2_way[2] = ~(|raddr2[3:0]) ? 32'b0 : collision_way2 ? inst2_from_mem_2 : way2_cacheline[offset_2[3:2] + 'b1];
    assign inst1_way[3] = collision_way3 ? inst1_from_mem_2 : way3_cacheline[offset_2[3:2]];
    assign inst2_way[3] = ~(|raddr2[3:0]) ? 32'b0 : collision_way3 ? inst2_from_mem_2 : way3_cacheline[offset_2[3:2] + 'b1];
    
//    wire [20:0]tagv_final_way0 = collision_way0 ? tagv_way0_2 : way0_tagv;
//    wire [20:0]tagv_final_way1 = collision_way1 ? tagv_way1_2 : way1_tagv;
    
    
    assign hit_judge_way0_1 = (wea_way0 && index_1 == index_2) ? 1'b1 : 
                            (way0_tagv[21] != 1'b1) ? 1'b0 : 
                            (ptag_1 == way0_tagv[20:0]) ? 1'b1 : 
                            1'b0;
    assign hit_judge_way1_1 = (wea_way1 && index_1 == index_2) ? 1'b1 : 
                            (way1_tagv[21] != 1'b1) ? 1'b0 : 
                            (ptag_1 == way1_tagv[20:0]) ? 1'b1 : 
                            1'b0;
    assign hit_judge_way2_1 = (wea_way2 && index_1 == index_2) ? 1'b1 : 
                            (way2_tagv[21] != 1'b1) ? 1'b0 : 
                            (ptag_1 == way2_tagv[20:0]) ? 1'b1 : 
                            1'b0;
    assign hit_judge_way3_1 = (wea_way3 && index_1 == index_2) ? 1'b1 : 
                            (way3_tagv[21] != 1'b1) ? 1'b0 : 
                            (ptag_1 == way3_tagv[20:0]) ? 1'b1 : 
                            1'b0;
    
//    assign hit_judge_way0_1 = (way0_tagv[20] != 1'b1) ? 1'b0 : 
//                            (ptag_1 == way0_tagv[19:0]) ? 1'b1 : 1'b0;
//    assign hit_judge_way1_1 = (way0_tagv[20] != 1'b1) ? 1'b0 : 
//                            (ptag_1 == way0_tagv[19:0]) ? 1'b1 : 1'b0;    
                            
    assign hit_1 = (hit_judge_way0_1 | hit_judge_way1_1 | hit_judge_way2_1 | hit_judge_way3_1) && valid_1 && !iuncache_i;
    assign nhit_1 = iuncache_i ? 1'b1 : 
                    ((wea_way0 | wea_way1 | wea_way2 | wea_way3) && index_1 == index_2) ? 1'b0 :
                    ~(hit_judge_way0_1 | hit_judge_way1_1 | hit_judge_way2_1 | hit_judge_way3_1) & valid_1;  
          
    
    //////////output logics
    assign data_ok1 = ~inst_delayslot_fetch_ff ? 1'b0 :
                      (iuncache_2 && ret_valid) ? 1'b1 :
                      hit ? 1'b1 : 
                      (nhit && ret_valid) ? 1'b1: 
                      1'b0;
    
    assign data_ok2 = ~inst_delayslot_fetch_ff ? 1'b0 :
                      inst_delayslot_ff ? 1'b0 : 
                      (iuncache_2 && ret_valid) ? 1'b0 :
                      (offset_2[3:2] == 2'b11) ? 1'b0 : 
                      data_ok1;
    
    assign rdata1 = (iuncache_i && ret_valid) ? ret_data[31:0] :
                    hit ? inst1_way[hit_judge_way] : 
                    (nhit && ret_valid) ? read_from_AXI[offset_2[3:2]] :
                    32'b0;
    
    assign rdata2 = hit ? inst2_way[hit_judge_way] : 
                    (nhit && ret_valid) ? read_from_AXI[offset_2[3:2]+2'h1] :
                    32'b0;
    
    assign raddr1 = vaddr_i1_2;
    
    assign raddr2 = vaddr_i2_2;
        
    assign rd_len = (iuncache_2 & rd_req) ? 8'h0 : 8'h3;
    
    assign rd_req = (nhit && !ret_valid);

    assign rd_addr = iuncache_2 ? {ptag_2, index_2, offset_2} : {ptag_2, index_2, 4'b0};
    
    assign stall = (iuncache_2 && data_ok_for_delayslot == 1'b0) ? 1'b1 :
                   (nhit && data_ok_for_delayslot == 1'b0) ? 1'b1 :1'b0 ;
    
endmodule