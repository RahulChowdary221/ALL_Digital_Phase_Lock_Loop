`timescale 1ns / 1ps


module ADPLL_top( input  wire sys_clk,  
    input  wire ref_clk,  
    input  wire rst,      
    output wire clk_out
);
wire signed [1:0] error_trace;
wire [31:0] tuning_trace;

Bang_Bang_PD u_bbpd (
        .clk(ref_clk),        
        .nco_clk(clk_out), 
        .rst(rst),
        .phase_error(error_trace));
        DLF #(.KP(500000),.KI(10000),.M_center(858993459))
        u_dlf (.clk(ref_clk),.rst(rst),.error(error_trace),.out(tuning_trace));
        //Numerically_controlled Oscillator
        Nco u_nco (
        .clk(sys_clk),      
        .rst(rst),
        .tuning_word(tuning_trace), 
        .clk_out(clk_out)       
    );
  // clk_divider1 #(
    //    .div_value(0))
    //u_divider (
      //  .clk(clk_out),        
        //.divided_clk (feedback_trace));
endmodule
