`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/08/02 17:10:50
// Design Name: 
// Module Name: ICache_pipeline_34way8bank
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


module ICache_pipeline_34way8bank(

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
    output reg [31:0] rdata1,
    output reg [31:0] rdata2,
    output reg [31:0] raddr1,
    output reg [31:0] raddr2,
    
    // with BPU
    input wire ex_branch_flag,
	input wire predict_success,
	input wire [31:0] ex_inst_addr_i1,
	input wire [34:0] corr_pkt,
    input wire instbuffer_full,
    output wire [34:0] predict_pkto1,
    output wire [34:0] predict_pkto2,
    output reg [31:0] icache_npc,
    
    // with tlb
    input wire [31:0] excepttype_i1,
    output wire [31:0] excepttype_o1,
    
    //Cache port with AXI
    output reg iuncache_s2,
    output wire [7:0] rd_len,
    output wire rd_req,          //read valid request
    output wire [31:0] rd_addr,  //read initial address
    input wire ret_valid,        //return data valid
    input wire [255:0] ret_data
    
    );
    
// stage 1
    wire valid_s1 = valid;
    // 4way
//    wire [20:0] ptag_s1 = paddr_i[31:11];
//    reg [20:0] ptag_s2;
//    wire [5:0] index_s1 = paddr_i[10:5];
//    reg  [5:0] index_s2;

    // 2way
    wire [19:0] ptag_s1 = paddr_i[31:12];
    reg [19:0] ptag_s2;
    wire [6:0] index_s1 = vaddr_i1[11:5];
    reg  [6:0] index_s2;
    
    wire [4:0] offset_s1 = vaddr_i1[4:0];
    wire [31:0] vaddr_i1_s1 = vaddr_i1;
    wire [31:0] vaddr_i2_s1 = vaddr_i2;
    
    wire tlb_flush_s1 = excepttype_i1[15] | excepttype_i1[16] | excepttype_i1[17];
    wire across_page_s1 = &vaddr_i1[12:2];

    // first branch predict
    wire [31:0] predict_pta1_s1, predict_pta2_s1;
    wire predict_dir1_s1 = |predict_pta1_s1;
    wire predict_dir2_s1 = |predict_pta2_s1;
    
    // hit judge
    // 4way
//    wire [21:0] way0_tagv;
//    wire wea_way0;
//    wire [21:0] way1_tagv;
//    wire wea_way1;
//    wire [21:0] way2_tagv;
//    wire wea_way2;
//    wire [21:0] way3_tagv;
//    wire wea_way3;

    // 2way
    wire [20:0] way0_tagv;
    wire wea_way0;
    wire [20:0] way1_tagv;
    wire wea_way1;
    

    // 4way
//    wire hit_judge_way0_s1 = (wea_way0 && index_s1 == index_s2 && ptag_s1 == ptag_s2) ? 1'b1 : 
//                            (way0_tagv[21] != 1'b1) ? 1'b0 : 
//                            (ptag_s1 == way0_tagv[20:0]) ? 1'b1 : 
//                            1'b0;
//    wire hit_judge_way1_s1 = (wea_way1 && index_s1 == index_s2 && ptag_s1 == ptag_s2) ? 1'b1 : 
//                            (way1_tagv[21] != 1'b1) ? 1'b0 : 
//                            (ptag_s1 == way1_tagv[20:0]) ? 1'b1 : 
//                            1'b0;
//    wire hit_judge_way2_s1 = (wea_way2 && index_s1 == index_s2 && ptag_s1 == ptag_s2) ? 1'b1 : 
//                            (way2_tagv[21] != 1'b1) ? 1'b0 : 
//                            (ptag_s1 == way2_tagv[20:0]) ? 1'b1 : 
//                            1'b0;
//    wire hit_judge_way3_s1 = (wea_way3 && index_s1 == index_s2 && ptag_s1 == ptag_s2) ? 1'b1 : 
//                            (way3_tagv[21] != 1'b1) ? 1'b0 : 
//                            (ptag_s1 == way3_tagv[20:0]) ? 1'b1 : 
//                            1'b0;
                            
//    wire hit_s1 = (hit_judge_way0_s1 | hit_judge_way1_s1 | hit_judge_way2_s1 | hit_judge_way3_s1) && valid_s1 && !iuncache_i;
//    wire nhit_s1 = iuncache_i ? 1'b1 : 
//                    ((wea_way0 | wea_way1 | wea_way2 | wea_way3) && index_s1 == index_s2 && ptag_s1 == ptag_s2) ? 1'b0 :
//                    ~(hit_judge_way0_s1 | hit_judge_way1_s1 | hit_judge_way2_s1 | hit_judge_way3_s1) & valid_s1;  

    // 2way
    wire hit_judge_way0_s2 = (way0_tagv[20] != 1'b1) ? 1'b0 : 
                            (ptag_s1 == way0_tagv[19:0]) ? 1'b1 : 
                            1'b0;
    wire hit_judge_way1_s2 = (way1_tagv[20] != 1'b1) ? 1'b0 : 
                            (ptag_s1 == way1_tagv[19:0]) ? 1'b1 : 
                            1'b0;
    wire hit_s2 = ((hit_judge_way0_s2 | hit_judge_way1_s2) && valid_s1 && !iuncache_i) | tlb_flush_s1;
    wire nhit_s2 = iuncache_i ? 1'b1 : 
                    ~(hit_judge_way0_s2 | hit_judge_way1_s2) & valid_s1;        
      
    
    
        
// stage 2
    reg [4:0] offset_s2;
    reg [31:0] vaddr_i1_s2;
    reg [31:0] vaddr_i2_s2;
    reg instbuffer_full_s2;
    
    // first branch predict: s2
    reg [31:0] predict_pta1_s2, predict_pta2_s2;
    reg predict_dir1_s2, predict_dir2_s2;
//    reg [1:0] hit_judge_way_s2;

    reg [31:0] excepttype_s2;
    reg tlb_flush_s2;
    reg across_page_s2;
    
    reg hit_judge_way0_s3;
    reg hit_judge_way1_s3;
    reg hit_s3;
    reg nhit_s3;
    
    assign excepttype_o1 = excepttype_s2;
    
    // from stage1 to stage2
    always@(posedge clk)begin
        if(~rst | flush)begin
            // 4 way
//            ptag_s2 <= 21'b0;
//            index_s2 <= 6'b0;
            // 2way
            ptag_s2 <= 20'b0;
            index_s2 <= 7'b0;
            offset_s2 <= 5'b0;
            vaddr_i1_s2 <= 32'h0;
            vaddr_i2_s2 <= 32'h0;
            iuncache_s2 <= 1'b0;
            predict_pta1_s2 <= 32'b0;
            predict_pta2_s2 <= 32'b0;
            predict_dir1_s2 <= 1'b0;
            predict_dir2_s2 <= 1'b0;
//            hit_judge_way_s2 <= 2'b0;
            instbuffer_full_s2 <= 1'b0; 
            excepttype_s2 <= 32'b0;     
            tlb_flush_s2 <= 1'b0;
            across_page_s2 <= 1'b0;      
            
            hit_judge_way0_s3 <= 1'b0;
            hit_judge_way1_s3 <= 1'b0;
            hit_s3 <= 1'b0;
            nhit_s3 <= 1'b0;
        end else if(stall)begin
            ptag_s2 <= ptag_s2;
            index_s2 <= index_s2;
            offset_s2 <= offset_s2;
            vaddr_i1_s2 <= vaddr_i1_s2;
            vaddr_i2_s2 <= vaddr_i2_s2;
            iuncache_s2 <= iuncache_s2;
            predict_pta1_s2 <= predict_pta1_s2;
            predict_pta2_s2 <= predict_pta2_s2;
            predict_dir1_s2 <= predict_dir1_s2;
            predict_dir2_s2 <= predict_dir2_s2;
//            hit_judge_way_s2 <= hit_judge_way_s2;
            instbuffer_full_s2 <= instbuffer_full_s2; 
            excepttype_s2 <= excepttype_s2;
            tlb_flush_s2 <= tlb_flush_s2;
            across_page_s2 <= across_page_s2;
            hit_judge_way0_s3 <= hit_judge_way0_s3;
            hit_judge_way1_s3 <= hit_judge_way1_s3;
            hit_s3 <= hit_s3;
            nhit_s3 <= nhit_s3;
        end else begin
            ptag_s2 <= ptag_s1;
            index_s2 <= index_s1;
            offset_s2 <= offset_s1;
            vaddr_i1_s2 <= vaddr_i1_s1;
            vaddr_i2_s2 <= vaddr_i2_s1;
            iuncache_s2 <= iuncache_i & ~tlb_flush_s1;
            predict_pta1_s2 <= predict_pta1_s1;
            predict_pta2_s2 <= predict_pta2_s1;
            predict_dir1_s2 <= predict_dir1_s1;
            predict_dir2_s2 <= predict_dir2_s1;
//            hit_judge_way_s2 <= {hit_judge_way3_s1 | hit_judge_way2_s1, hit_judge_way3_s1 | hit_judge_way1_s1};
            instbuffer_full_s2 <= instbuffer_full;
            excepttype_s2 <= excepttype_i1;
            tlb_flush_s2 <= tlb_flush_s1;
            across_page_s2 <= across_page_s1;
            hit_judge_way0_s3 <= hit_judge_way0_s2;
            hit_judge_way1_s3 <= hit_judge_way1_s2;
            hit_s3 <= hit_s2;
            nhit_s3 <= nhit_s2;
        end
    end
    
    wire [31:0] read_from_AXI[7:0];
    for(genvar i = 0 ;i < 8; i = i+1) begin
        assign read_from_AXI[i] = ret_data[32*(i+1)-1:32*i];
    end
    
    // cache define
    // 4 way
//    wire [5:0] read_addr = stall ? index_s2 : index_s1;
    
    // 2 way
    wire [6:0] read_addr = stall ? index_s2 : index_s1;
    
    wire [31:0] way0_cacheline[7:0];
    wire read_enb0 = ~(wea_way0 && index_s2 == read_addr);
    dram_tagv_i8 tagv_way0(.a(index_s2), .d({1'b1, ptag_s2}), .dpra(index_s1), .clk(clk), .we(wea_way0), .dpo(way0_tagv));
    Data_dual_ram_i8 Bank0_way0(.addra(index_s2), .clka(clk), .dina(read_from_AXI[0]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[0]), .enb(read_enb0));
    Data_dual_ram_i8 Bank1_way0(.addra(index_s2), .clka(clk), .dina(read_from_AXI[1]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[1]), .enb(read_enb0));
    Data_dual_ram_i8 Bank2_way0(.addra(index_s2), .clka(clk), .dina(read_from_AXI[2]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[2]), .enb(read_enb0));
    Data_dual_ram_i8 Bank3_way0(.addra(index_s2), .clka(clk), .dina(read_from_AXI[3]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[3]), .enb(read_enb0));
    Data_dual_ram_i8 Bank4_way0(.addra(index_s2), .clka(clk), .dina(read_from_AXI[4]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[4]), .enb(read_enb0));
    Data_dual_ram_i8 Bank5_way0(.addra(index_s2), .clka(clk), .dina(read_from_AXI[5]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[5]), .enb(read_enb0));
    Data_dual_ram_i8 Bank6_way0(.addra(index_s2), .clka(clk), .dina(read_from_AXI[6]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[6]), .enb(read_enb0));
    Data_dual_ram_i8 Bank7_way0(.addra(index_s2), .clka(clk), .dina(read_from_AXI[7]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[7]), .enb(read_enb0));

    wire [31:0] way1_cacheline[7:0];
    wire read_enb1 = ~(wea_way1 && index_s2 == read_addr);   
    dram_tagv_i8 tagv_way1(.a(index_s2), .d({1'b1, ptag_s2}), .dpra(index_s1), .clk(clk), .we(wea_way1), .dpo(way1_tagv));
    Data_dual_ram_i8 Bank0_way1(.addra(index_s2), .clka(clk), .dina(read_from_AXI[0]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[0]), .enb(read_enb1));
    Data_dual_ram_i8 Bank1_way1(.addra(index_s2), .clka(clk), .dina(read_from_AXI[1]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[1]), .enb(read_enb1));
    Data_dual_ram_i8 Bank2_way1(.addra(index_s2), .clka(clk), .dina(read_from_AXI[2]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[2]), .enb(read_enb1));
    Data_dual_ram_i8 Bank3_way1(.addra(index_s2), .clka(clk), .dina(read_from_AXI[3]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[3]), .enb(read_enb1));
    Data_dual_ram_i8 Bank4_way1(.addra(index_s2), .clka(clk), .dina(read_from_AXI[4]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[4]), .enb(read_enb1));
    Data_dual_ram_i8 Bank5_way1(.addra(index_s2), .clka(clk), .dina(read_from_AXI[5]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[5]), .enb(read_enb1));
    Data_dual_ram_i8 Bank6_way1(.addra(index_s2), .clka(clk), .dina(read_from_AXI[6]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[6]), .enb(read_enb1));
    Data_dual_ram_i8 Bank7_way1(.addra(index_s2), .clka(clk), .dina(read_from_AXI[7]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[7]), .enb(read_enb1));
    
//    wire [31:0] way2_cacheline[7:0];
//    wire read_enb2 = ~(wea_way2 && index_s2 == read_addr);   
//    dram_tagv_i8 tagv_way2(.a(index_s2), .d({1'b1, ptag_s2}), .dpra(index_s1), .clk(clk), .we(wea_way2), .dpo(way2_tagv));
//    Data_dual_ram_i8 Bank0_way2(.addra(index_s2), .clka(clk), .dina(read_from_AXI[0]), .ena(wea_way2), .wea(wea_way2), .addrb(read_addr), .clkb(clk), .doutb(way2_cacheline[0]), .enb(read_enb2));
//    Data_dual_ram_i8 Bank1_way2(.addra(index_s2), .clka(clk), .dina(read_from_AXI[1]), .ena(wea_way2), .wea(wea_way2), .addrb(read_addr), .clkb(clk), .doutb(way2_cacheline[1]), .enb(read_enb2));
//    Data_dual_ram_i8 Bank2_way2(.addra(index_s2), .clka(clk), .dina(read_from_AXI[2]), .ena(wea_way2), .wea(wea_way2), .addrb(read_addr), .clkb(clk), .doutb(way2_cacheline[2]), .enb(read_enb2));
//    Data_dual_ram_i8 Bank3_way2(.addra(index_s2), .clka(clk), .dina(read_from_AXI[3]), .ena(wea_way2), .wea(wea_way2), .addrb(read_addr), .clkb(clk), .doutb(way2_cacheline[3]), .enb(read_enb2));
//    Data_dual_ram_i8 Bank4_way2(.addra(index_s2), .clka(clk), .dina(read_from_AXI[4]), .ena(wea_way2), .wea(wea_way2), .addrb(read_addr), .clkb(clk), .doutb(way2_cacheline[4]), .enb(read_enb2));
//    Data_dual_ram_i8 Bank5_way2(.addra(index_s2), .clka(clk), .dina(read_from_AXI[5]), .ena(wea_way2), .wea(wea_way2), .addrb(read_addr), .clkb(clk), .doutb(way2_cacheline[5]), .enb(read_enb2));
//    Data_dual_ram_i8 Bank6_way2(.addra(index_s2), .clka(clk), .dina(read_from_AXI[6]), .ena(wea_way2), .wea(wea_way2), .addrb(read_addr), .clkb(clk), .doutb(way2_cacheline[6]), .enb(read_enb2));
//    Data_dual_ram_i8 Bank7_way2(.addra(index_s2), .clka(clk), .dina(read_from_AXI[7]), .ena(wea_way2), .wea(wea_way2), .addrb(read_addr), .clkb(clk), .doutb(way2_cacheline[7]), .enb(read_enb2));
    
//    wire [31:0] way3_cacheline[7:0];
//    wire read_enb3 = ~(wea_way3 && index_s2 == read_addr);   
//    dram_tagv_i8 tagv_way3(.a(index_s2), .d({1'b1, ptag_s2}), .dpra(index_s1), .clk(clk), .we(wea_way3), .dpo(way3_tagv));
//    Data_dual_ram_i8 Bank0_way3(.addra(index_s2), .clka(clk), .dina(read_from_AXI[0]), .ena(wea_way3), .wea(wea_way3), .addrb(read_addr), .clkb(clk), .doutb(way3_cacheline[0]), .enb(read_enb3));
//    Data_dual_ram_i8 Bank1_way3(.addra(index_s2), .clka(clk), .dina(read_from_AXI[1]), .ena(wea_way3), .wea(wea_way3), .addrb(read_addr), .clkb(clk), .doutb(way3_cacheline[1]), .enb(read_enb3));
//    Data_dual_ram_i8 Bank2_way3(.addra(index_s2), .clka(clk), .dina(read_from_AXI[2]), .ena(wea_way3), .wea(wea_way3), .addrb(read_addr), .clkb(clk), .doutb(way3_cacheline[2]), .enb(read_enb3));
//    Data_dual_ram_i8 Bank3_way3(.addra(index_s2), .clka(clk), .dina(read_from_AXI[3]), .ena(wea_way3), .wea(wea_way3), .addrb(read_addr), .clkb(clk), .doutb(way3_cacheline[3]), .enb(read_enb3));
//    Data_dual_ram_i8 Bank4_way3(.addra(index_s2), .clka(clk), .dina(read_from_AXI[4]), .ena(wea_way3), .wea(wea_way3), .addrb(read_addr), .clkb(clk), .doutb(way3_cacheline[4]), .enb(read_enb3));
//    Data_dual_ram_i8 Bank5_way3(.addra(index_s2), .clka(clk), .dina(read_from_AXI[5]), .ena(wea_way3), .wea(wea_way3), .addrb(read_addr), .clkb(clk), .doutb(way3_cacheline[5]), .enb(read_enb3));
//    Data_dual_ram_i8 Bank6_way3(.addra(index_s2), .clka(clk), .dina(read_from_AXI[6]), .ena(wea_way3), .wea(wea_way3), .addrb(read_addr), .clkb(clk), .doutb(way3_cacheline[6]), .enb(read_enb3));
//    Data_dual_ram_i8 Bank7_way3(.addra(index_s2), .clka(clk), .dina(read_from_AXI[7]), .ena(wea_way3), .wea(wea_way3), .addrb(read_addr), .clkb(clk), .doutb(way3_cacheline[7]), .enb(read_enb3));
                  
        
    // data_ok                                   
    wire data_ok1_s2_temp = (iuncache_s2 && ret_valid) ? 1'b1 :
                            hit_s2 ? 1'b1 : (nhit_s3 && ret_valid);
                       
    wire data_ok2_s2_temp = (iuncache_s2 && ret_valid) ? 1'b0 :
                            (&offset_s2[4:2] | across_page_s2) ? 1'b0 : 
                            data_ok1_s2_temp;
                            
    wire data_ok1_s2, data_ok2_s2;
                            
    // valid_flush
    wire fpredict_flag1, fpredict_flag2;
    reg predict_dir1_s3, predict_dir2_s3;
    reg spredict_dir1, spredict_dir2;
    
    wire predict_en_s3 = ~stall & ~instbuffer_full_s2;
    reg  predict_en1_s2;
    always @(posedge clk) begin
        if (~rst | flush)
            predict_en1_s2 <= 1'b1;
        else if (~fpredict_flag1 & (stall | instbuffer_full) & data_ok2)
            predict_en1_s2 <= 1'b0;
        else if (data_ok1_s2_temp)
            predict_en1_s2 <= 1'b1;
    end
    
    reg predict_en2_s2;
    always @(posedge clk) begin
        if (~rst | flush)
            predict_en2_s2 <= 1'b1;
        else if ((spredict_dir1 ^ predict_dir1_s3) & data_ok2 & (stall | instbuffer_full))
            predict_en2_s2 <= 1'b0;
        else if (spredict_dir1 & ~predict_dir1_s3 & data_ok1 & (stall | instbuffer_full))
            predict_en2_s2 <= 1'b0;
        else if (spredict_dir2 & ~predict_dir2_s3 & data_ok2 & (stall | instbuffer_full))
            predict_en2_s2 <= 1'b0;
        else if (data_ok1_s2_temp)
            predict_en2_s2 <= 1'b1;
    end
    
    reg inst_valid1_s2, inst_valid2_s2;
    reg inst_valid1_s3, inst_valid2_s3;
    always @(posedge clk) begin
        if (~rst | flush) begin
            inst_valid1_s2 <= 1'b1;
            inst_valid2_s2 <= 1'b1;
        end else if (~fpredict_flag1 & data_ok1 & predict_en_s3) begin
            inst_valid1_s2 <= 1'b0;
            inst_valid2_s2 <= 1'b0;
        end else if (~fpredict_flag2 & data_ok2 & predict_en_s3) begin
            inst_valid1_s2 <= 1'b0;
            inst_valid2_s2 <= 1'b0;
        end else if (predict_dir1_s2 & data_ok1_s2 & ~data_ok2_s2 & predict_en1_s2) begin
            inst_valid1_s2 <= 1'b1;
            inst_valid2_s2 <= 1'b0;
        end else if (predict_dir2_s2 & data_ok2_s2 & predict_en2_s2) begin
            inst_valid1_s2 <= 1'b1;
            inst_valid2_s2 <= 1'b0;
        end else if (data_ok1_s2_temp) begin
            inst_valid1_s2 <= 1'b1;
            inst_valid2_s2 <= 1'b1;
        end
    end
    
    // keep pta
    reg keep_pta;
    always @(posedge clk) begin
        if (~rst | flush)                                               keep_pta <= 1'b0;
        else if (~fpredict_flag1 & data_ok1)                            keep_pta <= 1'b1;
        else if (~fpredict_flag2 & data_ok2)                            keep_pta <= 1'b1;   
        else if (predict_dir1_s2 & data_ok1_s2 & ~data_ok2_s2)          keep_pta <= 1'b1;
        else if (predict_dir2_s2 & data_ok2_s2)                         keep_pta <= 1'b1;
        else if (predict_dir1_s1 & ~(iuncache_i | &offset_s1[4:2]))     keep_pta <= 1'b1;
        else if (data_ok1_s2_temp)                                      keep_pta <= 1'b0;
    end
    
    assign data_ok1_s2 = (data_ok1_s2_temp & inst_valid1_s2);
    assign data_ok2_s2 = (data_ok2_s2_temp & inst_valid2_s2);
    
    // LRU 
    //* LRU *//
    // 4 way
//    reg [63:0] LRU_1;
//    reg [127:0] LRU_2;//µ¥Êý£º1-63£¬Ë«Êý£º64-127
//    wire LRU_current_1 = LRU_1[index_s2];
//    wire LRU_current_2 = LRU_2[index_s2];
//    wire LRU_current_3 = LRU_2[index_s2+'h40];
//    always@(posedge clk)begin
//        if(~rst)begin
//            LRU_1 <= 64'b0;
//        end else if(data_ok1_s2_temp & hit_s2)begin
//            LRU_1[index_s2] <= (hit_judge_way_s2 == 2'b00 | hit_judge_way_s2 == 2'b01);
//        end else if(data_ok1_s2_temp & !hit_s2)begin
//            LRU_1[index_s2] <= (wea_way0 | wea_way1);
//        end else begin
//            LRU_1 <= LRU_1;
//        end
//    end
//    always@(posedge clk)begin
//        if(~rst)begin
//            LRU_2 <= 128'b0;
//        end else if(data_ok1_s2_temp & hit_s2)begin
//            if(hit_judge_way_s2 == 2'b00 | hit_judge_way_s2 == 2'b01)begin
//                LRU_2[index_s2] <= hit_judge_way_s2[0];
//            end else begin
//                LRU_2[index_s2+'h40] <= hit_judge_way_s2[0];
//            end
//        end else if(data_ok1_s2_temp && !hit_s2)begin
//            if(wea_way0 | wea_way1)begin
//                LRU_2[index_s2] <= wea_way0;
//            end else begin
//                LRU_2[index_s2+'h40] <= wea_way2;
//            end
//        end else begin
//            LRU_2 <= LRU_2;
//        end
//    end

    // 2 way
    reg [127:0] LRU;    //LRU width depends on index
    wire LRU_current = LRU[index_s2];
    always@(posedge clk)begin
        if(~rst)begin
            LRU <= 128'b0;
        end else if(data_ok1_s2_temp && hit_s2)begin
            LRU[index_s2] <= hit_judge_way0_s2;
        end else if(data_ok1_s2_temp && !hit_s3)begin
            LRU[index_s2] <= wea_way0;
        end else begin
            LRU <= LRU;
        end
    end
    
    // collision 
    reg collision_way0;
    reg collision_way1;
//    reg collision_way2;
//    reg collision_way3;
    reg [31:0]inst1_from_mem_s2;
    reg [31:0]inst2_from_mem_s2;
    
    
    always@(posedge clk)begin
        collision_way0 <= (wea_way0 && index_s1 == index_s2);
        collision_way1 <= (wea_way1 && index_s1 == index_s2);
//        collision_way2 <= (wea_way2 && index_s1 == index_s2);
//        collision_way3 <= (wea_way3 && index_s1 == index_s2);
        inst1_from_mem_s2 <= read_from_AXI[offset_s1[4:2]];
        inst2_from_mem_s2 <= read_from_AXI[offset_s1[4:2]+3'h1];
    end
    
    // inner logics
//    assign wea_way0 = (ret_valid && LRU_current_1 == 1'b0 && LRU_current_2 == 1'b0 && ~iuncache_s2);
//    assign wea_way1 = (ret_valid && LRU_current_1 == 1'b0 && LRU_current_2 == 1'b1 && ~iuncache_s2);
//    assign wea_way2 = (ret_valid && LRU_current_1 == 1'b1 && LRU_current_3 == 1'b0 && ~iuncache_s2);
//    assign wea_way3 = (ret_valid && LRU_current_1 == 1'b1 && LRU_current_3 == 1'b1 && ~iuncache_s2);

    // 2 way
    assign wea_way0 = (ret_valid && LRU_current == 1'b0 && ~iuncache_s2);
    assign wea_way1 = (ret_valid && LRU_current == 1'b1 && ~iuncache_s2);
    
    //data select
    // 4 way
//    wire [31:0] inst1_way[3:0];
//    wire [31:0] inst2_way[3:0];
//    assign inst1_way[0] = collision_way0 ? inst1_from_mem_s2 : way0_cacheline[offset_s2[4:2]];     //cache address partition in page 228
//    assign inst2_way[0] = ~(|vaddr_i2_s2[4:0]) ? 32'b0 : collision_way0 ? inst2_from_mem_s2 : way0_cacheline[offset_s2[4:2] + 3'b1];
//    assign inst1_way[1] = collision_way1 ? inst1_from_mem_s2 : way1_cacheline[offset_s2[4:2]];
//    assign inst2_way[1] = ~(|vaddr_i2_s2[4:0]) ? 32'b0 : collision_way1 ? inst2_from_mem_s2 : way1_cacheline[offset_s2[4:2] + 3'b1];
//    assign inst1_way[2] = collision_way2 ? inst1_from_mem_s2 : way2_cacheline[offset_s2[4:2]];
//    assign inst2_way[2] = ~(|vaddr_i2_s2[4:0]) ? 32'b0 : collision_way2 ? inst2_from_mem_s2 : way2_cacheline[offset_s2[4:2] + 3'b1];
//    assign inst1_way[3] = collision_way3 ? inst1_from_mem_s2 : way3_cacheline[offset_s2[4:2]];
//    assign inst2_way[3] = ~(|vaddr_i2_s2[4:0]) ? 32'b0 : collision_way3 ? inst2_from_mem_s2 : way3_cacheline[offset_s2[4:2] + 3'b1];

    // 2 way
    wire [31:0] inst1_way0 = collision_way0 ? inst1_from_mem_s2 : way0_cacheline[offset_s2[4:2]];
    wire [31:0] inst2_way0 = ~(|vaddr_i2_s2[4:0]) ? 32'b0 : collision_way0 ? inst2_from_mem_s2 : way0_cacheline[offset_s2[4:2] + 3'b1];
    wire [31:0] inst1_way1 = collision_way1 ? inst1_from_mem_s2 : way1_cacheline[offset_s2[4:2]];
    wire [31:0] inst2_way1 = ~(|vaddr_i2_s2[4:0]) ? 32'b0 : collision_way1 ? inst2_from_mem_s2 : way1_cacheline[offset_s2[4:2] + 3'b1];
    
    // rdata
    // 4 way
//    wire [31:0] rdata1_s2 = (iuncache_s2 && ret_valid) ? ret_data[31:0] :
//                            hit_s2 ? inst1_way[hit_judge_way_s2] : 
//                            (nhit_s2 && ret_valid) ? read_from_AXI[offset_s2[4:2]] :
//                            32'b0;
    
//    wire [31:0] rdata2_s2 = hit_s2 ? inst2_way[hit_judge_way_s2] : 
//                            (nhit_s2 && ret_valid) ? read_from_AXI[offset_s2[4:2]+3'h1] :
//                            32'b0;

    // 2 way
    wire [31:0] rdata1_s2 = tlb_flush_s2 ? 32'b0 :
                            (iuncache_s2 && ret_valid) ? ret_data[31:0] :
                            (hit_s2 && hit_judge_way0_s2) ? inst1_way0 : 
                            (hit_s2 && hit_judge_way1_s2) ? inst1_way1 :
                            (nhit_s3 && ret_valid) ? read_from_AXI[offset_s2[4:2]] :
                            32'b0;
    
    wire [31:0] rdata2_s2 = tlb_flush_s2 ? 32'b0 :
                             (hit_s2 && hit_judge_way0_s2) ? inst2_way0 : 
                             (hit_s2 && hit_judge_way1_s2) ? inst2_way1 :
                             (nhit_s3 && ret_valid) ? read_from_AXI[offset_s2[4:2]+3'h1] :
                             32'b0;
                             
    // output logics    
    assign rd_len = (iuncache_s2 & rd_req) ? 8'h0 : 8'h7;
    
    assign rd_req = ((nhit_s2 | nhit_s3) && !ret_valid);

    assign rd_addr = iuncache_s2 ? {ptag_s1, index_s2, offset_s2} : {ptag_s1, index_s2, 5'b0};
    
    assign stall = (iuncache_s2 & ~data_ok1_s2_temp) ? 1'b1 :
                   ((nhit_s2 | nhit_s3) & ~data_ok1_s2_temp);
                   
   // second branch predict
    wire spredict_dir1_s2, spredict_dir2_s2;
    wire [31:0] spredict_pta1_s2, spredict_pta2_s2;
    
    reg fpredict_flag1_temp, fpredict_flag2_temp;
    
    always @(posedge clk) begin
        if (~rst | flush) begin
            fpredict_flag1_temp <= 1'b1;
            fpredict_flag2_temp <= 1'b1;
        end else begin
            fpredict_flag1_temp <= (predict_dir1_s2 && spredict_dir1_s2 && predict_pta1_s2 == spredict_pta1_s2) ||
                            (~predict_dir1_s2 & ~spredict_dir1_s2);
            fpredict_flag2_temp <= (predict_dir2_s2 && spredict_dir2_s2 && predict_pta2_s2 == spredict_pta2_s2) ||
                            (~predict_dir2_s2 & ~spredict_dir2_s2);
        end
    end
                   
// stage 3

    // second branch predict
    reg [31:0] spredict_pta1, spredict_pta2;
    
    // from stage2 to stage3
    reg [31:0] predict_pta1_s3, predict_pta2_s3;   
    reg data_ok1_s3, data_ok2_s3; 
    
    always @(posedge clk) begin
        if(~rst | flush)begin
            data_ok1_s3 <= 1'b0;
            data_ok2_s3 <= 1'b0;
            rdata1 <= 32'b0;
            rdata2 <= 32'b0;
            raddr1 <= 32'b0;
            raddr2 <= 32'b0;
            predict_dir1_s3 <= 1'b0;
            predict_dir2_s3 <= 1'b0;
            predict_pta1_s3 <= 32'b0;
            predict_pta2_s3 <= 32'b0; 
            spredict_dir1 <= 1'b0;
            spredict_dir2 <= 1'b0;
            spredict_pta1 <= 32'b0;
            spredict_pta2 <= 32'b0;        
        end else if (data_ok1_s2) begin
            data_ok1_s3 <= data_ok1_s2;
            data_ok2_s3 <= data_ok2_s2;
            rdata1 <= rdata1_s2;
            rdata2 <= rdata2_s2;
            raddr1 <= vaddr_i1_s2;
            raddr2 <= vaddr_i2_s2;
            predict_dir1_s3 <= predict_dir1_s2;
            predict_dir2_s3 <= predict_dir2_s2;
            predict_pta1_s3 <= predict_pta1_s2;
            predict_pta2_s3 <= predict_pta2_s2;   
            spredict_dir1 <= spredict_dir1_s2;
            spredict_dir2 <= spredict_dir2_s2;
            spredict_pta1 <= spredict_pta1_s2;
            spredict_pta2 <= spredict_pta2_s2;
        end else begin
            data_ok1_s3 <= 1'b0;
            data_ok2_s3 <= 1'b0;
        end
    end        
    
    bpu bpu0(
        .clk(clk),
        .rst(rst),
        
        .first_inst_addr1(vaddr_i1),
        .first_inst_addr2(vaddr_i2),
        .first_predict_inst_addr1(predict_pta1_s1),
        .first_predict_inst_addr2(predict_pta2_s1),
        
        // on stage2
        .second_inst_addr1(vaddr_i1_s2),
        .second_inst1(rdata1_s2),
        .second_inst_addr2(vaddr_i2_s2),
        .second_inst2(rdata2_s2),
        
        .second_branch_predict_happen1(spredict_dir1_s2),
        .second_branch_predict_happen2(spredict_dir2_s2),
        .second_predict_inst_addr1(spredict_pta1_s2),
        .second_predict_inst_addr2(spredict_pta2_s2),
        
        // on stage3
//        .second_inst_addr1(raddr1),
//        .second_inst1(rdata1),
//        .second_inst_addr2(raddr2),
//        .second_inst2(rdata2),
        
//        .second_branch_predict_happen1(spredict_dir1),
//        .second_branch_predict_happen2(spredict_dir2),
//        .second_predict_inst_addr1(spredict_pta1),
//        .second_predict_inst_addr2(spredict_pta2),
    
        .ex_branch_type(corr_pkt[1:0]),
        .ex_branch_success(ex_branch_flag), 
        .ex_inst_addr(ex_inst_addr_i1),
        .ex_next_inst_addr(corr_pkt[33:2]),
        .ex_predict_success(predict_success)
    );
    
//    assign fpredict_flag1 = data_ok1 ? (predict_dir1_s3 && spredict_dir1 && predict_pta1_s3 == spredict_pta1) ||
//                            (~predict_dir1_s3 & ~spredict_dir1) : 1'b1;
//    assign fpredict_flag2 = data_ok2 ? (predict_dir2_s3 && spredict_dir2 && predict_pta2_s3 == spredict_pta2) ||
//                            (~predict_dir2_s3 & ~spredict_dir2) : 1'b1;

    assign fpredict_flag1 = ~data_ok1 | fpredict_flag1_temp;
    assign fpredict_flag2 = ~data_ok2 | fpredict_flag2_temp;
                            
    always @(posedge clk) begin
        if (~rst | flush) begin
            inst_valid1_s3 <= 1'b1;
            inst_valid2_s3 <= 1'b1;
        end else if (~spredict_dir1 & predict_dir1_s3 & data_ok2) begin
            inst_valid1_s3 <= 1'b0;
            inst_valid2_s3 <= 1'b0;
        end else if (spredict_dir1 & ~predict_dir1_s3 & data_ok2) begin
            inst_valid1_s3 <= 1'b0;
            inst_valid2_s3 <= 1'b0;
        end else if (spredict_dir1 & ~predict_dir1_s3 & data_ok1) begin
            inst_valid1_s3 <= 1'b1;
            inst_valid2_s3 <= 1'b0;
        end else if (spredict_dir2 & ~predict_dir2_s3 & data_ok2) begin
            inst_valid1_s3 <= 1'b1;
            inst_valid2_s3 <= 1'b0;
        end else if (data_ok1_s3) begin
            inst_valid1_s3 <= 1'b1;
            inst_valid2_s3 <= 1'b1;
        end
    end 
    
    // output logics
    assign predict_pkto1 = {spredict_dir1, spredict_pta1, 2'b00};
    assign predict_pkto2 = {spredict_dir2, spredict_pta2, 2'b00};
    assign data_ok1 = inst_valid1_s3 & data_ok1_s3;
    assign data_ok2 = inst_valid2_s3 & data_ok2_s3;
    
    // icache_npc
    reg [31:0] icache_npc_ff;
    always @(posedge clk) begin
        if (flush) 
            icache_npc_ff <= 32'b0;
        else 
            icache_npc_ff <= icache_npc;
    end
    
    always @(*) begin
        if (~fpredict_flag1 & data_ok1)                                                 icache_npc = spredict_pta1;
        else if (~fpredict_flag2 & data_ok2)                                            icache_npc = spredict_pta2;     
        else if (predict_dir1_s2 & data_ok1_s2 & ~data_ok2_s2 & predict_en1_s2)         icache_npc = predict_pta1_s2;
        else if (predict_dir2_s2 & data_ok2_s2 & predict_en2_s2)                        icache_npc = predict_pta2_s2;
        else if (instbuffer_full_s2)                                                    icache_npc = icache_npc_ff;
        else if (iuncache_s2 & ~keep_pta)                                               icache_npc = vaddr_i2_s2;
        else if (stall)                                                                 icache_npc = vaddr_i1;
        else if (predict_dir1_s1 & ~(iuncache_i | &offset_s1[4:2]))                     icache_npc = predict_pta1_s1;
        else if (&offset_s1[4:2])                                                       icache_npc = vaddr_i1 + 32'h4;
        else                                                                            icache_npc = vaddr_i1 + 32'h8;
    end
    
endmodule