`timescale 1ns / 1ps

module DLF(
input wire clk,
input wire rst,
input wire signed [1:0] error,
output wire [31:0] out
    );
    parameter  signed [31:0] KP = 50;
    parameter  signed [31:0] KI = 50;
    parameter   signed [31:0] M_center =42949673 ;
   reg signed [31:0] Pn;
   reg signed [31:0] In;
    always@(*) begin
    if(error==2'b01) begin
     Pn = KP;
     end
      else if(error == 2'b11) begin
      Pn = -KP;
      end
      else Pn = 0;
    end
    always@(posedge clk) begin
     if(rst) begin
     In <=0;
     end
     else if (error==2'b01)begin
     In <= In + KI;
     end
     else if(error == 2'b11)
      begin
     In <= In - KI;
     end
      end
     assign out = $unsigned(M_center + Pn + In);
endmodule
