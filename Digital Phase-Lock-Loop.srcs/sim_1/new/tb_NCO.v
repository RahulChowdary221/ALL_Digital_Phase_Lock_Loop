`timescale 1ns / 1ps

module tb_NCO();
 reg clk;
 reg rst;
 reg [31:0] tuning_word;
 wire clk_out;
 
 Nco uut(.clk(clk),.
 rst(rst),.tuning_word(tuning_word),
 .clk_out(clk_out)
         );
      always #5
      clk= ~clk;
      initial begin
       clk = 0;
       rst =1;
       tuning_word = 32'b0;
        #20;
        rst =0;
        tuning_word = 32'd42949673;//generate 1Mhz)
        #5000;
        tuning_word = 32'd214748365;//generate5Mhz
        #2000;
        $display("Simulation Complete");
        $finish;
        end
        
      
endmodule
