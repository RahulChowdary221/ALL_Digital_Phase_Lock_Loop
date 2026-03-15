`timescale 1ns / 1ps

module tb_ADPLL();




    reg  sys_clk;
    reg  ref_clk;
    reg  rst;
    wire clk_out;

    // )
    ADPLL_top uut (
        .sys_clk(sys_clk),
        .ref_clk(ref_clk),
        .rst(rst),
        .clk_out(clk_out) );
   

    always #5 // 100Mhz sys_clk
    sys_clk = ~sys_clk;
    always #25 //20Mhz refernce clk
    ref_clk = ~ref_clk ;
    initial begin
        //
        sys_clk = 0;
        ref_clk =0;
        rst = 1;
        #100;
        
        rst = 0;
       
        #50000; 
       
        $finish;
    end

endmodule
   
