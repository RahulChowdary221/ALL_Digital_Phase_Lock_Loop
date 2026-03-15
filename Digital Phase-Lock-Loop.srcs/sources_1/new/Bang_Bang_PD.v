`timescale 1ns / 1ps

module Bang_Bang_PD(input wire clk,nco_clk,rst,
output reg  signed [1:0] phase_error

);
 reg Q1,sampled_nco;
always@(posedge clk ) //rising edge of reference clk
begin
if (rst) begin  //reset pins 
        Q1          <= 1'b0;
        sampled_nco <= 1'b0;
        //phase_error <= 2'b00; 
    end
    else begin
 Q1<=nco_clk;
 sampled_nco <= Q1;
  end
 end
 always@(*)
 begin
 if(sampled_nco == 0) begin
  phase_error = 2'b01; //error is lagging speed up +1
  end
  else if (sampled_nco ==1) begin
  phase_error =2'b11; // error is leading speed down -1
  end
  else begin
  phase_error =2'b00; //no Phase_error
  end
 end
endmodule
