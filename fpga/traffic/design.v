`timescale 1ns/1ps
module traffic #(parameter CLK_HZ=50_000_000)(
    input wire clk_50mhz,rst_p,flicker,
    output wire [3:0] led_red,led_yellow,led_green,led_left,
    output wire [3:0] led_walk_red,led_walk_green
);
    wire tick,blink;
    wire [1:0] direction;
    wire [3:0] phase;
    second_tick #(.CLK_HZ(CLK_HZ)) u_tick(clk_50mhz,rst_p,tick,blink);
    traffic_sequence u_sequence(clk_50mhz,rst_p,tick,flicker,direction,phase);
    traffic_lights u_lights(direction,phase,flicker,blink,
        led_red,led_yellow,led_green,led_walk_red,led_walk_green);
    assign led_left=led_green;
endmodule

`timescale 1ns/1ps
// 느린 동작은 새 클록 대신 한 클록 길이의 tick으로 만듭니다.
module second_tick #(parameter CLK_HZ=50_000_000)(
    input wire clk_50mhz, rst_p,
    output wire tick,
    output wire blink
);
    reg [31:0] count;
    assign tick=(count==CLK_HZ-1);
    assign blink=(count < CLK_HZ/2);
    always @(posedge clk_50mhz)
        if(rst_p || tick) count<=0;
        else count<=count+1;
endmodule

`timescale 1ns/1ps
module traffic_lights(
    input wire [1:0] direction,
    input wire [3:0] phase,
    input wire flicker,blink,
    output reg [3:0] red,yellow,green,walk_red,walk_green
);
    reg [3:0] vehicle_mask,pedestrian_mask;
    always @* begin
        // 방향별 차량과 보행자 LED를 선택합니다.
        case(direction)
            0: begin vehicle_mask=4'b1000; pedestrian_mask=4'b0100; end
            1: begin vehicle_mask=4'b0100; pedestrian_mask=4'b0010; end
            2: begin vehicle_mask=4'b0010; pedestrian_mask=4'b0001; end
            3: begin vehicle_mask=4'b0001; pedestrian_mask=4'b1000; end
        endcase
        red=4'b1111; yellow=0; green=0; walk_red=4'b1111; walk_green=0;
        if(flicker) begin
            red=0; yellow={4{blink}}; walk_red={4{blink}};
        end else begin
            if(phase<=10) begin green=vehicle_mask; red=~vehicle_mask; end
            else begin yellow=vehicle_mask; red=~vehicle_mask; end
            if(phase<=3) begin walk_green=pedestrian_mask; walk_red=~pedestrian_mask; end
            else if(phase<=10) begin
                walk_green=blink ? pedestrian_mask : 4'b0000;
                walk_red=~pedestrian_mask;
            end
        end
    end
endmodule

`timescale 1ns/1ps
// 각 방향에서 0~10초는 초록, 11~12초는 노랑입니다.
module traffic_sequence(
    input wire clk_50mhz,rst_p,tick,flicker,
    output reg [1:0] direction,
    output reg [3:0] phase
);
    always @(posedge clk_50mhz) begin
        if(rst_p || flicker) begin direction<=0; phase<=0; end
        else if(tick)
            if(phase==12) begin phase<=0; direction<=direction+1'b1; end
            else phase<=phase+1'b1;
    end
endmodule