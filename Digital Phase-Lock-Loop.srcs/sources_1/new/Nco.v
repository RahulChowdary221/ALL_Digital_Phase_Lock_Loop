`timescale 1ns / 1ps


module Nco( input wire clk,rst,
input wire [31:0] tuning_word,
output wire clk_out

    );
    reg [31:0] phase_accumulator ;
    always@(posedge clk) begin
    if(rst)  begin
    phase_accumulator <= 32'b0;
     end else begin
     phase_accumulator <= phase_accumulator + tuning_word;
     end
    end
    assign clk_out = phase_accumulator[31];
endmodule
