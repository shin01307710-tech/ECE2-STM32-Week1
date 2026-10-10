`timescale 1ns/1ps
module adc_command(input wire [2:0] channel,output wire [15:0] command);
    // 원본 예제의 WR·SEQ·주소·전원·범위·코딩 비트 구성을 유지합니다.
    assign command={3'b101,channel,2'b11,1'b0,3'b111,4'b0000};
endmodule

`timescale 1ns/1ps
module adc #(parameter HALF_CYCLES=25)(
    input wire clk_50mhz,rst_p,
    input wire [2:0] add_sel,
    output wire adc_sclk,adc_ncs,adc_din,
    input wire adc_dout,
    output reg [11:0] sample,
    output reg data_valid,
    output wire [7:0] led_out
);
    wire [15:0] command,rx_word;
    wire busy,done;
    reg start;
    adc_command u_command(add_sel,command);
    serial_frame16 #(.HALF_CYCLES(HALF_CYCLES)) u_serial(
        clk_50mhz,rst_p,start,command,adc_dout,
        adc_sclk,adc_ncs,adc_din,busy,done,rx_word);
    always @(posedge clk_50mhz) begin
        if(rst_p) begin start<=0; sample<=0; data_valid<=0; end
        else begin
            start<=!busy && !start;
            data_valid<=done;
            if(done) sample<=rx_word[11:0];
        end
    end
    assign led_out=sample[11:4];
endmodule

`timescale 1ns/1ps
// 16비트 직렬 송수신. 클록은 HIGH 대기, 하강 에지에서 준비, 상승 에지에서 수신합니다.
module serial_frame16 #(parameter HALF_CYCLES=25)(
    input wire clk_50mhz,rst_p,start,
    input wire [15:0] tx_word,
    input wire miso,
    output reg sclk,cs_n,mosi,busy,done,
    output reg [15:0] rx_word
);
    reg [31:0] count;
    reg [4:0] bit_index;
    reg [15:0] tx_latched;
    always @(posedge clk_50mhz) begin
        if(rst_p) begin
            sclk<=1; cs_n<=1; mosi<=0; busy<=0; done<=0;
            count<=0; bit_index<=15; tx_latched<=0; rx_word<=0;
        end else begin
            done<=0;
            if(!busy) begin
                if(start) begin
                    cs_n<=0; busy<=1; count<=0; bit_index<=15;
                    tx_latched<=tx_word; rx_word<=0; mosi<=tx_word[15];
                end
            end else if(count==HALF_CYCLES-1) begin
                count<=0;
                if(sclk) begin sclk<=0; mosi<=tx_latched[bit_index]; end
                else begin
                    sclk<=1;
                    rx_word<={rx_word[14:0],miso};
                    if(bit_index==0) begin busy<=0; cs_n<=1; done<=1; end
                    else bit_index<=bit_index-1'b1;
                end
            end else count<=count+1;
        end
    end
endmodule