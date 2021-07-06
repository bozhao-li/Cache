`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/05 20:18:29
// Design Name: 
// Module Name: WriteBuffer_sim
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


module WriteBuffer_sim();

    parameter DLY = 0.1;
    reg clk = 1'b0;
    reg rst = 1'b1;
    
    reg wreq_i;
    reg [31:0] waddr_i;
    reg [127:0] wdata_i;
    wire whit_o;
    
    reg rreq_i;
    reg [31:0] raddr_i;
    wire rhit_o;
    wire [127:0] rdata_o;
    wire [1:0] state_o;
    
    reg AXI_valid_i;
    wire AXI_wen_o;
    wire [127:0] AXI_wdata_o;
    wire [31:0] AXI_waddr_o;
    
    
    reg wreq_i_i = 1'b0;
    reg [31:0] waddr_i_i = 32'b0;
    reg [127:0] wdata_i_i = 128'b0;
    reg rreq_i_i = 1'b0;
    reg [31:0] raddr_i_i = 32'b0;
    reg AXI_valid_i_i = 1'b0;
    
    always @(posedge clk) begin
        if (rst) begin
            wreq_i <= #DLY 1'b0;
            waddr_i <= #DLY 32'b0;
            wdata_i <= #DLY 128'b0;
            rreq_i <= #DLY 1'b0;
            raddr_i <= #DLY 32'b0;
            AXI_valid_i <= #DLY 1'b0;
        end else begin
            wreq_i <= #DLY wreq_i_i;
            waddr_i <= #DLY waddr_i_i;
            wdata_i <= #DLY wdata_i_i;
            rreq_i <= #DLY rreq_i_i;
            raddr_i <= #DLY raddr_i_i;
            AXI_valid_i <= #DLY AXI_valid_i_i;
        end
    end  
    
    WriteBuffer WriteBuffer_u(.clk(clk), .rst(rst), 
    
                              .wreq_i(wreq_i), .waddr_i(waddr_i), .wdata_i(wdata_i), .whit_o(whit_o), 
                              .rreq_i(rreq_i), .raddr_i(raddr_i), .rhit_o(rhit_o), .rdata_o(rdata_o), 
                              .state_o(state_o), 
                              
                              .AXI_valid_i(AXI_valid_i), .AXI_wen_o(AXI_wen_o), 
                              .AXI_wdata_o(AXI_wdata_o), .AXI_waddr_o(AXI_waddr_o));
    
    always begin
        #10 clk = ~clk;
    end
    
    initial begin
        #500 rst = 1'b0;
        
        //1. normal write
        wreq_i_i = 1'b1;
        waddr_i_i = 32'h24687_571;
        wdata_i_i = 128'h34567891_02345678_91023456_78910234;
        #20 wreq_i_i = 1'b0;//Keep one cycle ONLY 
        wait(state_o == 2'b01 && AXI_wen_o == 1'b1
             && AXI_waddr_o == 32'h24687_570
             && AXI_wdata_o == 128'h34567891_02345678_91023456_78910234)begin 
            #200 AXI_valid_i_i = 1'b1;
            #20 AXI_valid_i_i = 1'b0;
        end
        #20
        if(state_o == 2'b00)begin
            $display("Success: Normal Write");
        end
        else begin
            $display("Fail: Normal Write");
            $stop;
        end
        
        
        
        //2. normal read
        //read, normal read not hit
        wreq_i_i = 1;
        waddr_i_i = 32'h24687_571;
        wdata_i_i = 128'h34567891_02345678_91023456_78910234;
        #20 wreq_i_i = 1'b0;//Keep one cycle ONLY
        #20 
        if(state_o == 2'b01)begin
            $display("Success: overflow Write STATE_WORKING");
        end
        else begin
            $display("Fail: overflow Write STATE_WORKING");
            $stop;
        end
        wreq_i_i = 1'b1;
        waddr_i_i = 32'h24697_571;
        wdata_i_i = 128'h12345678_91023456_78910234_56789102;
        #20 wreq_i_i = 0;//Keep one cycle ONLY 
        
        rreq_i_i = 1'b1;
        raddr_i_i = 32'h99617_570;
        #20 rreq_i_i = 1'b0;
        if(rhit_o == 1'b0 )begin
            $display("Success: normal read not hit");
        end
        else begin
            $display("Fail: normal read not hit");
            $stop;
        end
        
        //read, normal read hit
        wreq_i_i = 1'b1;
        waddr_i_i = 32'h25687_571;
        wdata_i_i = 128'h22345678_91023456_91023456_78910234;
        #20 wreq_i_i = 1'b0;//Keep one cycle ONLY 
        wreq_i_i = 1'b1;
        waddr_i_i = 32'h24617_571;
        wdata_i_i = 128'h32345678_91023456_34567891_02345678;
        #20 wreq_i_i = 0;//Keep one cycle ONLY 
        
        rreq_i_i = 1'b1;
        raddr_i_i = 32'h24617_570;
        #20 rreq_i_i = 0;
        #20
        if(rhit_o == 1'b1 &&  rdata_o == 128'h32345678_91023456_34567891_02345678)begin
            $display("Success: normal read hit");
        end
        else begin
            $display("Fail: normal read hit");
            $stop;
        end

        //overflow Write STATE_FULL
        wreq_i_i = 1'b1;
        waddr_i_i = 32'h24387_571;
        wdata_i_i = 128'h42345678_91023456_78910234_56789102;
        #20 wreq_i_i = 1'b0;//Keep one cycle ONLY 
        wreq_i_i = 1'b1;
        waddr_i_i = 32'h24307_571;
        wdata_i_i = 128'h52345678_91023456_78910234_56789102;
        #20 wreq_i_i = 0;//Keep one cycle ONLY 
        wreq_i_i = 1'b1;
        waddr_i_i = 32'h14387_571;
        wdata_i_i = 128'h62345678_91023456_78910234_56789102;
        #20 wreq_i_i = 1'b0;//Keep one cycle ONLY 
        wreq_i_i = 1'b1;
        waddr_i_i = 32'h74387_571;
        wdata_i_i = 128'h72345678_91023456_78910234_56789102;
        #20 wreq_i_i = 0;//Keep one cycle ONLY 
        #20
        if(state_o == 2'b11)begin
            $display("Success: overflow Write STATE_FULL");
        end
        else begin
            $display("Fail: overflow Write STATE_FULL");
            $stop;
        end

        //write response
        #200 AXI_valid_i_i = 1'b1;
        #20 AXI_valid_i_i = 1'b0;
        
        //read
        rreq_i_i = 1'b1;
        raddr_i_i = 32'h24687_570;
        #20 rreq_i_i = 1'b0;
        #20
        if(rhit_o == 1'b0 )begin
            $display("Success: normal read not hit(hit invalid)");
        end
        else begin
            $display("Fail: normal read not hit(hit invalid)");
            $stop;
        end
        
        
        
        //3. write hit   FIFO_data[4]==256'h0
        wreq_i_i = 1'b1;
        waddr_i_i = 32'h24617_573;
        wdata_i_i = 128'h0;
        #20 wreq_i_i = 1'b0;//Keep one cycle ONLY 
        #20
        if(whit_o == 1'b1)begin
            $display("Success: write hit, if FIFO_data[4]==256'h0");
        end
        else begin
            $display("Fail: write hit");
            $stop;
        end
        
        
        
        //4. read hit head
        rreq_i_i = 1'b1;
        raddr_i_i = 32'h24697_570;
        #20 rreq_i_i = 1'b0;
        #20
        if(rhit_o == 1'b1 &&  rdata_o == 128'h12345678_91023456_78910234_56789102)begin
            $display("Success: read hit head");
        end
        else begin
            $display("Fail: read hit head");
            $stop;
        end
        
        
        //5. write hit head
        wreq_i_i = 1'b1;
        waddr_i_i = 32'h24697_57b;
        wdata_i_i = 128'h1111;
        AXI_valid_i_i = 1'b1;//rewrite test
        #20 wreq_i_i = 1'b0;//Keep one cycle ONLY 
        AXI_valid_i_i = 1'b0;
        if(state_o == 2'b01
            && AXI_waddr_o == 32'h24697_570
            && AXI_wdata_o == 128'h1111)begin 
            $display("Success: write hit head");
        end
        else begin
            $display("Fail: write hit head");
            $stop;
        end
        /*
        //5. write hit head
        wreq_i_i = 1'b1;
        waddr_i_i = 32'h24697_57b;
        wdata_i_i = 128'h1111;
        #20 wreq_i_i = 1'b0;//Keep one cycle ONLY 
        #100
        AXI_valid_i_i = 1'b1;//rewrite test
        #20
        AXI_valid_i_i = 1'b0;
        if(state_o == 2'b01
            && AXI_waddr_o == 32'h24697_570
            && AXI_wdata_o == 128'h1111)begin 
            $display("Success: write hit head");
        end
        else begin
            $display("Fail: write hit head");
            $stop;
        end
        */
        
        /*
        //6. read hit head(rewritten)   cpu_rdata_o == 256'h1111
        rreq_i_i = 1'b1;
        raddr_i_i = 32'h24697_57b;
        #20 rreq_i_i = 1'b0;
        #20
        if(rhit_o == 1'b1 &&  rdata_o == 128'h1111)begin
            $display("Success: write hit head(rewritten)");
        end
        else begin
            $display("Fail: write hit head(rewritten)");
            $stop;
        end
        
        
        
        //7. write hit head(when bvalid)  AXI_waddr_o == 32'h24697_560 && AXI_wdata_o == 256'h2222
        #200
        AXI_valid_i_i = 1'b1;
        wreq_i_i = 1'b1;
        waddr_i_i = 32'h24697_571;
        wdata_i_i = 128'h2222;
        #20 wreq_i_i = 1'b0;//Keep one cycle ONLY 
        AXI_valid_i_i = 1'b0;//rewrite test
        #20
        if(state_o == 2'b01
           && AXI_waddr_o == 32'h24697_570
           && AXI_wdata_o == 128'h2222)begin 
            $display("Success: write hit head(when bvalid)");
        end
        else begin
            $display("Fail: write hit head(when bvalid)");
            $stop;
        end
        */
        #500 $finish; 
    end

endmodule












