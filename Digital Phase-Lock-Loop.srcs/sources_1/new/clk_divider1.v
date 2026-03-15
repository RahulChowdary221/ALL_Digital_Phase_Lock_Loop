`timescale 1ns / 1ps


`timescale 1ns / 1ps


module clk_divider1(
input wire clk,
output reg divided_clk=0
    );
    parameter div_value = 4;
    integer counter_value =0;
    always@(posedge clk )
    begin
    if(counter_value == div_value)
    counter_value <=0;//reset counter_value
    else
    counter_value <= counter_value +1;
   
    end
    always@(posedge clk)
    begin
    if(counter_value == div_value)
    divided_clk = ~divided_clk;
    else 
    divided_clk <= divided_clk;
    end
    
endmodule