`timescale 1ns / 1ps

module tb_BBD();
 reg clk;
 reg nco_clk;
 reg rst;
wire  signed   [1:0] phase_error;
Bang_Bang_PD DUT (.clk(clk),.nco_clk(nco_clk),.rst(rst),.phase_error(phase_error));
always #5  //100Mhz clk signal
clk = ~clk;
always #20  //25Mhz nco_signal
nco_clk = ~nco_clk ;
initial begin
rst = 1'b1;
clk = 1'b0;
nco_clk = 1'b0;
#30;
rst = 1'b0;
$display("SIMULATION COMPLETE");
$finish;
end
endmodule
