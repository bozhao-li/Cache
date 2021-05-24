`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/19 19:28:32
// Design Name: 
// Module Name: Cache
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

/*one way*/


`include "defines.v"
module Cache(
    
    input wire clk,
    input wire rst,
    
    //Cache port with CPU
    input wire valid,           //valid request
    input wire [31:0]addr_i,          
    //input wire op,              //1:write, 0:read
    //input wire [7:0] index,     //addr[11:4] index region
    //input wire [19:0] tag,
    //input wire [3:0] offset,    //addr[3:0]
    //input wire [3:0] wstrb,     //write enable
    //input wire [31:0] wdata,    
    //output wire addr_ok,         //address transfer in is OK
    output wire data_ok,         //data transfer out is OK
    output wire [31:0] rdata,    
    
    //Cache port with AXI
    output wire rd_req,          //read valid request
    //output reg [2:0] rd_type,   //000:byte, 001:half, 010:word, 100:cache line
    output wire [31:0] rd_addr,  //read initial address
    //input wire rd_rdy,          //read receive ready handshake signal
    input wire ret_valid,       //return data valid
    //input wire [1:0] ret_last,
    input wire [127:0] ret_data
    //output reg wr_req,          //write valid request
    //output reg [2:0] wr_type,
    //output reg [31:0] wr_addr,
    //output reg [3:0] wr_wstrb,  //byte mask
    //output reg [127:0] wr_data,
    //input wire wr_rdy           //write receive ready handshake signal
    );
    
    wire [19:0] tag;
    wire [7:0] index;
    wire [3:0] offset;
    assign tag = addr_i[31:12];
    assign index = addr_i[11:4];
    assign offset = addr_i[3:0];
    
    
    //each way: 1 TagV(256*21), [1 D(256*1)], 4 DataBank(256*32)
    wire [3:0] wea_way0;
    wire [20:0] way0_tagv;
    wire [31:0] way0_cacheline[3:0];
    TagV_Ram tagv_way0(.addra(index), .clka(clk), .dina({1'b1,tag}), .douta(way0_tagv), .ena(1'b1), .wea(wea_way0));
    Data_Bank_Ram Bank0_way0(.addra(index), .clka(clk), .dina(read_from_AXI[32*1-1:32*0]), .douta(way0_cacheline[0]), .ena(1'b1), .wea(wea_way0));
    Data_Bank_Ram Bank1_way0(.addra(index), .clka(clk), .dina(read_from_AXI[32*2-1:32*1]), .douta(way0_cacheline[1]), .ena(1'b1), .wea(wea_way0));
    Data_Bank_Ram Bank2_way0(.addra(index), .clka(clk), .dina(read_from_AXI[32*3-1:32*2]), .douta(way0_cacheline[2]), .ena(1'b1), .wea(wea_way0));
    Data_Bank_Ram Bank3_way0(.addra(index), .clka(clk), .dina(read_from_AXI[32*4-1:32*3]), .douta(way0_cacheline[3]), .ena(1'b1), .wea(wea_way0));
    
    
    wire [3:0] wea_way1;
    wire [20:0] way1_tagv;
    wire [31:0] way1_cacheline[3:0];
    TagV_Ram tagv_way1(.addra(index), .clka(clk), .dina({1'b1,tag}), .douta(way1_tagv), .ena(1'b1), .wea(wea_way1));
    Data_Bank_Ram Bank0_way1(.addra(index), .clka(clk), .dina(read_from_AXI[32*1-1:32*0]), .douta(way1_cacheline[0]), .ena(1'b1), .wea(wea_way1));
    Data_Bank_Ram Bank1_way1(.addra(index), .clka(clk), .dina(read_from_AXI[32*2-1:32*1]), .douta(way1_cacheline[1]), .ena(1'b1), .wea(wea_way1));
    Data_Bank_Ram Bank2_way1(.addra(index), .clka(clk), .dina(read_from_AXI[32*3-1:32*2]), .douta(way1_cacheline[2]), .ena(1'b1), .wea(wea_way1));
    Data_Bank_Ram Bank3_way1(.addra(index), .clka(clk), .dina(read_from_AXI[32*4-1:32*3]), .douta(way1_cacheline[3]), .ena(1'b1), .wea(wea_way1));
    
    wire hit;                               //hit:1
    wire hit_judge_way0;
    wire hit_judge_way1;
    //LRU
    reg [255:0] LRU;    //LRU width depends on index
    wire LRU_current = LRU[index];
    always@(posedge clk)begin
        if(rst)begin
            LRU <= 256'b0;
        end else if(valid == 1'b1 && hit)begin
            LRU[index] <= hit_judge_way0;
        end else if(valid == 1'b1 && hit == 1'b0)begin
            LRU[index] <= !hit_judge_way0;
        end else begin
            LRU <= LRU;
        end
    end
    
    //******************************** Main state machine ********************************//
    /*five states:: Idle:   000     no operations, 
                    LookUp: 001     looking up and gets the results, 
                    Miss:   010     miss hit, waiting for wr_rdy, 
                    Replace:011     have read cache line, waiting for rd_rdy, 
                    Refill: 100     miss, writing into cache  */
    
    reg [2:0] m_current_state;              //main current state   
    reg [2:0] m_next_state;                 //main next state
    //reg hw_current_state;                 //write buffer current state
    //reg hw_next_state;                    //write buffer next state
    
    
    //three-stage state machine
    always@(posedge clk)begin
        if(rst == 1'b1)begin
            m_current_state <= `MIdle;
        end else begin
            m_current_state <= m_next_state;
        end
    end
    
    always@(*)begin
        m_next_state <= `MIdle;
        case(m_current_state)
            `MIdle:begin
                if(valid)begin       //request valid
                    m_next_state <= `MLookUp;
                end else begin
                    m_next_state <= `MIdle;
                end
            end
            `MLookUp:begin
                if(hit)begin
                    m_next_state <= `MIdle;
                end else begin
                    m_next_state <= `MMiss;
                end
            end
            `MMiss:begin
                m_next_state <= `MReplace;
            end
            `MReplace:begin
                if(ret_valid)begin
                    m_next_state <= `MRefill;
                end else begin
                    m_next_state <= `MReplace;
                end
            end
            `MRefill:begin
                m_next_state <= `MIdle;
            end
        endcase
    end
    
    //data select
    wire [31:0]inst_way0 = way0_cacheline[offset[3:2]];     //cache address partition in page 228
    wire [31:0]inst_way1 = way1_cacheline[offset[3:2]];
    
    //tag compare
    assign hit_judge_way0 = (tag == way0_tagv[19:0] && way0_tagv[20] == 1'b1) ? 1'b1 :1'b0;
    assign hit_judge_way1 = (tag == way1_tagv[19:0] && way1_tagv[20] == 1'b1) ? 1'b1 :1'b0;
    assign hit = (m_current_state == `MLookUp) ? (hit_judge_way0 | hit_judge_way1) : 1'b0;
    
    reg [127:0]read_from_AXI;
    //output to CPU
    //assign addr_ok = (m_current_state == `MIdle) ? 1'b1 : 
    //                 (m_current_state == `MLookUp && hit) ? 1'b1 : 
    //                 1'b0;
    assign data_ok = (m_current_state == `MLookUp && hit) ? 1'b1 : 
                     //(op && m_current_state == `MLookUp ) ? 1'b1 :    //write
                     (m_current_state == `MRefill && ret_valid == 1'b1) ? 1'b1 : 
                     1'b0;
    assign rdata = (m_current_state==`MLookUp && hit_judge_way0 == 1'b1)? inst_way0:
                   (m_current_state==`MLookUp && hit_judge_way1 == 1'b1)? inst_way1:
                   (m_current_state==`MRefill && offset[3:2] == 2'h0)? read_from_AXI[32*1-1:32*0]:
                   (m_current_state==`MRefill && offset[3:2] == 2'h1)? read_from_AXI[32*2-1:32*1]:
                   (m_current_state==`MRefill && offset[3:2] == 2'h2)? read_from_AXI[32*3-1:32*2]:
                   (m_current_state==`MRefill && offset[3:2] == 2'h3)? read_from_AXI[32*4-1:32*3]:
                   32'b0;
    
    //output to AXI
    assign rd_req = (m_current_state == `MReplace && !ret_valid) ? 1 : 0;
    assign rd_addr = {tag, index, offset};
    //miss buffer
    
    always@(posedge clk) begin 
         if(m_current_state==`MReplace)
             read_from_AXI<= ret_data;
         else
             read_from_AXI<= read_from_AXI;
    end
    //write back
    assign wea_way0 = (m_current_state==`MRefill && LRU_current == 1'b0)? 4'b1111 : 4'h0;
    assign wea_way1 = (m_current_state==`MRefill && LRU_current == 1'b1)? 4'b1111 : 4'h0;
    
    //******************************** Write Buffer state machine ********************************//
    /*two states:: Idle:   0     no hit write data, 
                   Write:  1     hit write into cache  */
    /*
    always@(posedge clk)begin
        if(rst == 1'b1)begin
           
        end else begin
            case(hwstate)
                `HWIdle:begin
                     
                end
                `HWWrite:begin
                
                end
                
            endcase
        end
    end
    */
endmodule
