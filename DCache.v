`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/05/20 20:06:32
// Design Name: 
// Module Name: DCache
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

`include "defines.v"
module DCache(
    input clk,
    input rst,
    //Cache port with CPU
    input wire rvalid_i,                //valid request
    input wire [31:0]addr_i,          
    input wire wvalid_i,                //1:write, 0:read
    input wire [3:0] wsel_i,            //write enable
    input wire [31:0] wdata_i,    
    //output wire addr_ok,              //address transfer in is OK
    output wire data_ok_o,             //data transfer out is OK
    output wire [31:0] rdata_o,    
    output reg stall_o,
    
    //Cache port with AXI
    output wire rd_req_o,              //read valid request
    //output reg [2:0] rd_type,         //000:byte, 001:half, 010:word, 100:cache line
    output wire [31:0] rd_addr_o,     //read initial address
    //input wire rd_rdy,               //read receive ready handshake signal
    input wire ret_valid_i,            //return data valid
    //input wire [1:0] ret_last,
    input wire [127:0] ret_data_i,
    
    output reg wr_req_o,          //write valid request 
    //output reg [2:0] wr_type,
    output wire [31:0] wr_addr_o,
    //output reg [3:0] wr_wstrb,  //byte mask
    output reg [127:0] wr_data_o,
    input wire wr_rdy_i           //write receive ready handshake signal
    );
    //Initialize
    wire [31:0]wsel_expand;
    assign wsel_expand={{8{wsel_i[3]}} , {8{wsel_i[2]}} , {8{wsel_i[1]}} , {8{wsel_i[0]}}};
    
    reg [2:0] m_current_state;              //main current state   
    reg [2:0] m_next_state;                 //main next state
    
    reg wvalid_i_lock;
    reg [31:0] addr_i_lock;
    reg [31:0] wdata_i_lock;
    always@(posedge clk)begin
        if(rst)begin
            wvalid_i_lock <= 1'b0;
            addr_i_lock <= 332'b0;
            wdata_i_lock <= 32'b0;
        end else if(m_current_state == `MIdle)begin
            wvalid_i_lock <= wvalid_i;
            addr_i_lock <= addr_i;
            wdata_i_lock <= wdata_i;
        end else begin
            wvalid_i_lock <= wvalid_i_lock;
            addr_i_lock <= addr_i_lock;
            wdata_i_lock <= wdata_i_lock;
        end
    end
    
    wire [19:0] tag;
    wire [7:0] index;
    wire [3:0] offset;
    assign tag = addr_i_lock[31:12];
    assign index = addr_i_lock[11:4];
    assign offset = addr_i_lock[3:0];
        
    
    //each way: 1 TagV(256*21), [1 D(256*1)], 4 DataBank(256*32)
    reg [127:0]read_from_AXI;
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
        end else if(data_ok_o == 1'b1 && hit && m_current_state == `MLookUp)begin
            LRU[index] <= hit_judge_way0;
        end else if(data_ok_o == 1'b1 && hit == 1'b0 && m_current_state == `MLookUp)begin
            LRU[index] <= !hit_judge_way0;
        end else begin
            LRU <= LRU;
        end
    end
    
    
    
    //stall
    
    //******************************** Main state machine ********************************//
    /*five states:: Idle:   000     no operations, 
                    LookUp: 001     looking up and gets the results, 
                    Miss:   010     miss hit, waiting for wr_rdy, 
                    Replace:011     have read cache line, waiting for rd_rdy, 
                    Refill: 100     miss, writing into cache  */
    
    
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
                if(rvalid_i | wvalid_i)begin       //request valid
                    m_next_state <= `MLookUp;
                end else begin
                    m_next_state <= `MIdle;
                end
            end
            `MLookUp:begin
                if(hit)begin
                    m_next_state <= `MIdle;
                end else if(LRU_current && way1_tagv[20] == 1'b0 && wvalid_i_lock)begin
                    m_next_state <= `MIdle;
                end else if(LRU_current == 1'b0 && way0_tagv[20] == 1'b0 && wvalid_i_lock)begin
                    m_next_state <= `MIdle;
                end else begin
                    m_next_state <= `MMiss;
                end
            end
            `MMiss:begin
                if(wr_rdy_i)begin
                    m_next_state <= `MReplace;
                end else begin
                    m_next_state <= `MMiss;
                end
            end
            `MReplace:begin
                if(ret_valid_i)begin
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
    
    //WriteBuffer
    
    //******************************** Write Buffer state machine ********************************//
    /*two states:: Idle:   0     no hit write data, 
                   Write:  1     hit write into cache  */
    reg hw_current_state;                 //write buffer current state
    reg hw_next_state;                    //write buffer next state
    
    always@(posedge clk)begin
        if(rst == 1'b1)begin
            hw_current_state <= `HWIdle;
        end else begin
            hw_current_state <= hw_next_state;
        end
    end
    
    always@(*)begin
        hw_next_state <= `HWIdle;
        case(hw_current_state)
            `HWIdle:begin
                if(m_current_state == `MLookUp && hit && wvalid_i)begin       //request valid
                    hw_next_state <= `HWWrite;
                end else begin
                    hw_next_state <= `HWIdle;
                end
            end
            `HWWrite:begin
                if(m_current_state == `MLookUp && hit && wvalid_i)begin
                    hw_next_state <= `HWWrite;
                end else begin
                    hw_next_state <= `HWIdle;
                end
            end
        endcase
    end
    
    //wr_req_o [31:0] wr_addr_o [127:0] wr_data_o
    always@(posedge clk)begin
        if(rst)begin
            wr_req_o <= 1'b0;
        end else if (m_current_state == `MMiss /*&& m_next_state == `MReplace*/) begin
            wr_req_o <= 1'b1;
        end else if(wr_req_o == 1'b1)begin
            wr_req_o <= 1'b0;
        end else begin
            wr_req_o <= wr_req_o;
        end
    end
    
    assign wr_addr_o = (wr_req_o && hit_judge_way0) ? {way0_tagv, index, offset} : 
                       (wr_req_o && hit_judge_way1) ? {way1_tagv, index, offset} : 
                       32'b0;
    
    always@(*)begin
        if(LRU_current && m_current_state == `MReplace && wr_req_o)begin
            wr_data_o <= {way1_cacheline[3], way1_cacheline[2], way1_cacheline[1], way1_cacheline[0]};
        end else if(LRU_current == 1'b0 && m_current_state == `MReplace && wr_req_o)begin
            wr_data_o <= {way0_cacheline[3], way0_cacheline[2], way0_cacheline[1], way0_cacheline[0]};
        end else begin
            wr_data_o <= 128'b0;
        end
    end
    /*
    //Dirty signal
    reg [255:0] dirty_way0;
    reg [255:0] dirty_way1;
    wire write_dirty = (LRU_current == 0) ? dirty_way0[index] : dirty_way1[index];
    always@(posedge clk)begin
        if(rst)begin
            dirty_way0 <= 256'b0;
            dirty_way1 <= 256'b0;
        end else if(m_current_state == `MReplace && wr_rdy_i == 1'b1 && wvalid_i_lock == 1'b0)begin      //read not hit
            if(LRU_current)begin
                dirty_way1[index] <= 1'b0;
            end else begin
                dirty_way0[index] <= 1'b0;
            end
        end else if(m_current_state == `MReplace && wr_rdy_i == 1'b1 && wvalid_i_lock == 1'b1)begin      //write not hit
            if(LRU_current)begin
                dirty_way1[index] <= 1'b1;
            end else begin
                dirty_way0[index] <= 1'b1;
            end
        end else if(hit && wvalid_i_lock == 1'b1)begin   //hit write
            if(hit_judge_way1)begin
                dirty_way1[index] <= 1'b1;
            end else begin
                dirty_way0[index] <= 1'b1;
            end
        end else begin
            dirty_way0 <= dirty_way0;
            dirty_way1 <= dirty_way1;
        end
    end
    */
    //data select
    wire [31:0]inst1_way0 = way0_cacheline[offset[3:2]];     //cache address partition in page 228
    //wire [31:0]inst2_way0 = way0_cacheline[offset[3:2] + 'b1];
    wire [31:0]inst1_way1 = way1_cacheline[offset[3:2]];
    //wire [31:0]inst2_way1 = way1_cacheline[offset[3:2] + 'b1];
    
    //tag compare
    assign hit_judge_way0 = (tag == way0_tagv[19:0] && way0_tagv[20] == 1'b1) ? 1'b1 :1'b0;
    assign hit_judge_way1 = (tag == way1_tagv[19:0] && way1_tagv[20] == 1'b1) ? 1'b1 :1'b0;
    assign hit = hit_judge_way0 | hit_judge_way1;
    
    //output to CPU
    //assign addr_ok = (m_current_state == `MIdle) ? 1'b1 : 
    //                 (m_current_state == `MLookUp && hit) ? 1'b1 : 
    //                 1'b0;
    assign data_ok_o = (m_current_state == `MLookUp && hit) ? 1'b1 : 
                     //(op && m_current_state == `MLookUp ) ? 1'b1 :    //write
                     (m_current_state == `MRefill) ? 1'b1 : 
                     1'b0;
                     
    always@(*)begin
        if(m_current_state == `MIdle && (rvalid_i | wvalid_i))begin
            stall_o <= 1'b1;
        end else if(m_current_state==`MReplace)begin
            stall_o <= 1'b1;
        end else if(m_current_state==`MLookUp)begin
            if(rvalid_i)begin
                stall_o <= ~data_ok_o;
            end else begin
                stall_o <= ~hit;
            end
        end else if(m_current_state==`MMiss)begin
            stall_o <= 1'b1;
        end else if(m_current_state==`MRefill)begin
            stall_o <= 1'b0;
        end else begin
            stall_o <= 1'b0;
        end
    end
                     
    assign rdata_o = (m_current_state==`MLookUp && hit_judge_way0 == 1'b1)? inst1_way0:
                     (m_current_state==`MLookUp && hit_judge_way1 == 1'b1)? inst1_way1:
                     (m_current_state==`MRefill && offset[3:2] == 2'h0)? read_from_AXI[32*1-1:32*0]:
                     (m_current_state==`MRefill && offset[3:2] == 2'h1)? read_from_AXI[32*2-1:32*1]:
                     (m_current_state==`MRefill && offset[3:2] == 2'h2)? read_from_AXI[32*3-1:32*2]:
                     (m_current_state==`MRefill && offset[3:2] == 2'h3)? read_from_AXI[32*4-1:32*3]:
                     32'b0;

    
    //output to AXI
    assign rd_req_o = (m_current_state == `MReplace && !ret_valid_i) ? 1 : 0;
    assign rd_addr_o = {tag, index, offset};
    //miss buffer
    
    always@(*) begin 
        if(m_current_state==`MRefill && wvalid_i_lock == 1'b0)begin     //read hit fail
            read_from_AXI<= ret_data_i;
        end else if(m_current_state==`MRefill && wvalid_i_lock == 1'b1) begin    //write hit fail
           case(offset[3:2])
               2'b00: read_from_AXI <= {ret_data_i[32*4-1:32*3], ret_data_i[32*3-1:32*2], ret_data_i[32*2-1:32*1], (wdata_i_lock & wsel_expand)|(ret_data_i[32*1-1:32*0] & ~wsel_expand)};
               2'b01: read_from_AXI <= {ret_data_i[32*4-1:32*3], ret_data_i[32*3-1:32*2], (wdata_i_lock & wsel_expand)|(ret_data_i[32*2-1:32*1] & ~wsel_expand), ret_data_i[32*1-1:32*0]};
               2'b10: read_from_AXI <= {ret_data_i[32*4-1:32*3], (wdata_i_lock & wsel_expand)|(ret_data_i[32*3-1:32*2] & ~wsel_expand), ret_data_i[32*2-1:32*1], ret_data_i[32*1-1:32*0]};
               2'b11: read_from_AXI <= {(wdata_i_lock & wsel_expand)|(ret_data_i[32*4-3:32*3] & ~wsel_expand),ret_data_i[32*3-1:32*2] , ret_data_i[32*2-1:32*1], ret_data_i[32*1-1:32*0]};
               default:read_from_AXI<= ret_data_i;
           endcase
        end else if(hit && wvalid_i_lock && m_current_state == `MLookUp)begin    //write hit success
            if(hit_judge_way0)begin
                case(offset[3:2])
                    2'b00: read_from_AXI <= {way0_cacheline[3], way0_cacheline[2], way0_cacheline[1], wdata_i_lock};
                    2'b01: read_from_AXI <= {way0_cacheline[3], way0_cacheline[2], wdata_i_lock, way0_cacheline[0]};
                    2'b10: read_from_AXI <= {way0_cacheline[3], wdata_i_lock, way0_cacheline[1], way0_cacheline[0]};
                    2'b11: read_from_AXI <= {wdata_i_lock, way0_cacheline[2], way0_cacheline[1], way0_cacheline[0]};
                    default:read_from_AXI <= {way0_cacheline[3], way0_cacheline[2], way0_cacheline[1], way0_cacheline[0]};
                endcase
            end else if(hit_judge_way1)begin
                case(offset[3:2])
                    2'b00: read_from_AXI <= {way1_cacheline[3], way1_cacheline[2], way1_cacheline[1], wdata_i_lock};
                    2'b01: read_from_AXI <= {way1_cacheline[3], way1_cacheline[2], wdata_i_lock, way1_cacheline[0]};
                    2'b10: read_from_AXI <= {way1_cacheline[3], wdata_i_lock, way1_cacheline[1], way1_cacheline[0]};
                    2'b11: read_from_AXI <= {wdata_i_lock, way1_cacheline[2], way1_cacheline[1], way1_cacheline[0]};
                    default:read_from_AXI <= {way1_cacheline[3], way1_cacheline[2], way1_cacheline[1], way1_cacheline[0]};
                endcase
            end else begin
                read_from_AXI <= 128'b0;
            end
        end else if(LRU_current == 1'b0 && way0_tagv[20] == 1'b0 && wvalid_i_lock && m_current_state == `MLookUp)begin//initialize 0
            case(offset[3:2])
                2'b00: read_from_AXI <= {way0_cacheline[3], way0_cacheline[2], way0_cacheline[1], wdata_i_lock};
                2'b01: read_from_AXI <= {way0_cacheline[3], way0_cacheline[2], wdata_i_lock, way0_cacheline[0]};
                2'b10: read_from_AXI <= {way0_cacheline[3], wdata_i_lock, way0_cacheline[1], way0_cacheline[0]};
                2'b11: read_from_AXI <= {wdata_i_lock, way0_cacheline[2], way0_cacheline[1], way0_cacheline[0]};
                default:read_from_AXI <= {way0_cacheline[3], way0_cacheline[2], way0_cacheline[1], way0_cacheline[0]};
            endcase
        end else if(LRU_current == 1'b1 && way1_tagv[20] == 1'b0 && wvalid_i_lock && m_current_state == `MLookUp)begin//initialize 1
            case(offset[3:2])
                2'b00: read_from_AXI <= {way1_cacheline[3], way1_cacheline[2], way1_cacheline[1], wdata_i_lock};
                2'b01: read_from_AXI <= {way1_cacheline[3], way1_cacheline[2], wdata_i_lock, way1_cacheline[0]};
                2'b10: read_from_AXI <= {way1_cacheline[3], wdata_i_lock, way1_cacheline[1], way1_cacheline[0]};
                2'b11: read_from_AXI <= {wdata_i_lock, way1_cacheline[2], way1_cacheline[1], way1_cacheline[0]};
                default:read_from_AXI <= {way1_cacheline[3], way1_cacheline[2], way1_cacheline[1], way1_cacheline[0]};
            endcase
        end else begin
            read_from_AXI<= 128'b0;
        end
    end
    
    
    assign wea_way0 = (m_current_state==`MRefill && LRU_current == 1'b0) ? 4'b1111 : //read hit fail
                      (hit && wvalid_i_lock && hit_judge_way0 && m_current_state == `MLookUp) ? (wsel_i):    //write hit success
                      (LRU_current == 1'b0 && way0_tagv[20] == 1'b0 && wvalid_i_lock && m_current_state == `MLookUp) ? (wsel_i): // initialize 0
                       4'h0;
    assign wea_way1 = (m_current_state==`MRefill && LRU_current == 1'b1)? 4'b1111 : 
                      (hit && wvalid_i_lock && hit_judge_way1 && m_current_state == `MLookUp)?(wsel_i):    //write hit success
                      (LRU_current == 1'b1 && way1_tagv[20] == 1'b0 && wvalid_i_lock && m_current_state == `MLookUp) ? (wsel_i): // initialize 1
                      4'h0;
    
    
    
    
endmodule



























