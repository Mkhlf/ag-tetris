`timescale 1ns / 1ps

module debouncer(
    input clk,
    input I0,
    input I1,
    output reg O0,
    output reg O1
    );
    
    reg [17:0] cnt0, cnt1; // 18-bit counter for ~10ms at 25MHz
    reg Iv0=0,Iv1=0;
    
    localparam CNT_MAX = 250000; // 10ms @ 25MHz

always@(posedge(clk))begin
    if (I0==Iv0)begin
        if (cnt0==CNT_MAX) O0<=I0;
        else cnt0<=cnt0+1;
      end
    else begin
        cnt0<=0;
        Iv0<=I0;
    end
    if (I1==Iv1)begin
            if (cnt1==CNT_MAX) O1<=I1;
            else cnt1<=cnt1+1;
          end
        else begin
            cnt1<=0;
            Iv1<=I1;
        end
    end
    
endmodule
