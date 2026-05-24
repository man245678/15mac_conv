module Convolver
#(
    parameter ADDR_WIDTH    = 15,
    parameter IMAGE_WIDTH   = 98,
    parameter FILTER_WIDTH  = 5,
    parameter FEATURE_WIDTH = 32,
    parameter BITWIDTH      = 8
)(
    input wire clk,
    input wire resetn,
    input wire signed [BITWIDTH-1:0] IMAGE_RAM_DIN,
    input wire signed [BITWIDTH-1:0] FILTER_RAM_DIN,
    input wire signed [2*BITWIDTH-1:0] FEATURE_RAM_DIN,
    input wire IMAGE_RAM_DATA_VAL,
    input wire FILTER_RAM_DATA_VAL,
    input wire FEATURE_RAM_DATA_VAL,

    output wire IMAGE_RAM_EN,
    output wire FILTER_RAM_EN,
    output wire FEATURE_RAM_EN,
    output wire FEATURE_RAM_WEN,

    output wire [ADDR_WIDTH-1:0] IMAGE_RAM_ADDRESS,
    output wire [ADDR_WIDTH-1:0] FILTER_RAM_ADDRESS,
    output wire [ADDR_WIDTH-1:0] FEATURE_RAM_ADDRESS,

    output wire signed [2*BITWIDTH-1:0] FEATURE_RAM_DOUT,
    output wire eoc
);

    localparam IDLE       = 3'd0;
    localparam ISSUE_READ = 3'd1;
    localparam WAIT_DATA  = 3'd2;
    localparam STORE_DATA = 3'd3;
    localparam MAC_ROW    = 3'd4;
    localparam WRITE      = 3'd5;
    localparam EOC        = 3'd6;

    reg [2:0] cur_state, next_state;
    reg [2:0] cur_kernel_row, next_kernel_row;
    reg [3:0] cur_lane, next_lane;
    reg [4:0] cur_feature_x, next_feature_x;
    reg [4:0] cur_feature_y, next_feature_y;
    reg signed [2*BITWIDTH-1:0] cur_acc, next_acc;

    reg signed [BITWIDTH-1:0] ifmap_buf1,  ifmap_buf2,  ifmap_buf3,  ifmap_buf4,  ifmap_buf5;
    reg signed [BITWIDTH-1:0] ifmap_buf6,  ifmap_buf7,  ifmap_buf8,  ifmap_buf9,  ifmap_buf10;
    reg signed [BITWIDTH-1:0] ifmap_buf11, ifmap_buf12, ifmap_buf13, ifmap_buf14, ifmap_buf15;
    reg signed [BITWIDTH-1:0] filter_buf1,  filter_buf2,  filter_buf3,  filter_buf4,  filter_buf5;
    reg signed [BITWIDTH-1:0] filter_buf6,  filter_buf7,  filter_buf8,  filter_buf9,  filter_buf10;
    reg signed [BITWIDTH-1:0] filter_buf11, filter_buf12, filter_buf13, filter_buf14, filter_buf15;

    wire signed [2*BITWIDTH-1:0] mac_result;
    wire [1:0] lane_channel = (cur_lane < 5) ? 0 : ((cur_lane < 10) ? 1 : 2);
    wire [2:0] lane_col = (cur_lane < 5) ? cur_lane[2:0] :
                          ((cur_lane < 10) ? (cur_lane - 5) : (cur_lane - 10));

    wire [ADDR_WIDTH-1:0] image_base =
        cur_feature_x * 3 + cur_feature_y * 3 * IMAGE_WIDTH;
    wire [ADDR_WIDTH-1:0] image_addr =
        image_base + lane_channel * IMAGE_WIDTH * IMAGE_WIDTH +
        cur_kernel_row * IMAGE_WIDTH + lane_col;
    wire [ADDR_WIDTH-1:0] filter_addr =
        lane_channel * FILTER_WIDTH * FILTER_WIDTH +
        cur_kernel_row * FILTER_WIDTH + lane_col;

    assign IMAGE_RAM_EN = (cur_state == ISSUE_READ);
    assign FILTER_RAM_EN = (cur_state == ISSUE_READ);
    assign FEATURE_RAM_EN = (cur_state == WRITE);
    assign FEATURE_RAM_WEN = (cur_state == WRITE);
    assign IMAGE_RAM_ADDRESS = image_addr;
    assign FILTER_RAM_ADDRESS = filter_addr;
    assign FEATURE_RAM_ADDRESS = cur_feature_x + cur_feature_y * FEATURE_WIDTH;
    assign FEATURE_RAM_DOUT = cur_acc;
    assign eoc = (cur_state == EOC);

    MAC #(
        .DATA_BW(BITWIDTH)
    ) u_MAC (
        .CLK(clk),
        .RSTN(resetn),
        .EN(cur_state == MAC_ROW),
        .IFMAP_DATA_IN1(ifmap_buf1),
        .IFMAP_DATA_IN2(ifmap_buf2),
        .IFMAP_DATA_IN3(ifmap_buf3),
        .IFMAP_DATA_IN4(ifmap_buf4),
        .IFMAP_DATA_IN5(ifmap_buf5),
        .IFMAP_DATA_IN6(ifmap_buf6),
        .IFMAP_DATA_IN7(ifmap_buf7),
        .IFMAP_DATA_IN8(ifmap_buf8),
        .IFMAP_DATA_IN9(ifmap_buf9),
        .IFMAP_DATA_IN10(ifmap_buf10),
        .IFMAP_DATA_IN11(ifmap_buf11),
        .IFMAP_DATA_IN12(ifmap_buf12),
        .IFMAP_DATA_IN13(ifmap_buf13),
        .IFMAP_DATA_IN14(ifmap_buf14),
        .IFMAP_DATA_IN15(ifmap_buf15),
        .FILTER_DATA_IN1(filter_buf1),
        .FILTER_DATA_IN2(filter_buf2),
        .FILTER_DATA_IN3(filter_buf3),
        .FILTER_DATA_IN4(filter_buf4),
        .FILTER_DATA_IN5(filter_buf5),
        .FILTER_DATA_IN6(filter_buf6),
        .FILTER_DATA_IN7(filter_buf7),
        .FILTER_DATA_IN8(filter_buf8),
        .FILTER_DATA_IN9(filter_buf9),
        .FILTER_DATA_IN10(filter_buf10),
        .FILTER_DATA_IN11(filter_buf11),
        .FILTER_DATA_IN12(filter_buf12),
        .FILTER_DATA_IN13(filter_buf13),
        .FILTER_DATA_IN14(filter_buf14),
        .FILTER_DATA_IN15(filter_buf15),
        .MUL_DATA_OUT(mac_result)
    );

    always @ (posedge clk or negedge resetn) begin
        if(!resetn) begin
            cur_state <= IDLE;
            cur_kernel_row <= 0;
            cur_lane <= 0;
            cur_feature_x <= 0;
            cur_feature_y <= 0;
            cur_acc <= 0;
        end
        else begin
            cur_state <= next_state;
            cur_kernel_row <= next_kernel_row;
            cur_lane <= next_lane;
            cur_feature_x <= next_feature_x;
            cur_feature_y <= next_feature_y;
            cur_acc <= next_acc;
        end
    end

    always @ (negedge clk or negedge resetn) begin
        if(!resetn) begin
            ifmap_buf1 <= 0;   ifmap_buf2 <= 0;   ifmap_buf3 <= 0;   ifmap_buf4 <= 0;   ifmap_buf5 <= 0;
            ifmap_buf6 <= 0;   ifmap_buf7 <= 0;   ifmap_buf8 <= 0;   ifmap_buf9 <= 0;   ifmap_buf10 <= 0;
            ifmap_buf11 <= 0;  ifmap_buf12 <= 0;  ifmap_buf13 <= 0;  ifmap_buf14 <= 0;  ifmap_buf15 <= 0;
            filter_buf1 <= 0;  filter_buf2 <= 0;  filter_buf3 <= 0;  filter_buf4 <= 0;  filter_buf5 <= 0;
            filter_buf6 <= 0;  filter_buf7 <= 0;  filter_buf8 <= 0;  filter_buf9 <= 0;  filter_buf10 <= 0;
            filter_buf11 <= 0; filter_buf12 <= 0; filter_buf13 <= 0; filter_buf14 <= 0; filter_buf15 <= 0;
        end
        else if((cur_state == WAIT_DATA || cur_state == STORE_DATA) &&
                IMAGE_RAM_DATA_VAL && FILTER_RAM_DATA_VAL) begin
            case(cur_lane)
                4'd0:  begin ifmap_buf1 <= IMAGE_RAM_DIN;  filter_buf1 <= FILTER_RAM_DIN;  end
                4'd1:  begin ifmap_buf2 <= IMAGE_RAM_DIN;  filter_buf2 <= FILTER_RAM_DIN;  end
                4'd2:  begin ifmap_buf3 <= IMAGE_RAM_DIN;  filter_buf3 <= FILTER_RAM_DIN;  end
                4'd3:  begin ifmap_buf4 <= IMAGE_RAM_DIN;  filter_buf4 <= FILTER_RAM_DIN;  end
                4'd4:  begin ifmap_buf5 <= IMAGE_RAM_DIN;  filter_buf5 <= FILTER_RAM_DIN;  end
                4'd5:  begin ifmap_buf6 <= IMAGE_RAM_DIN;  filter_buf6 <= FILTER_RAM_DIN;  end
                4'd6:  begin ifmap_buf7 <= IMAGE_RAM_DIN;  filter_buf7 <= FILTER_RAM_DIN;  end
                4'd7:  begin ifmap_buf8 <= IMAGE_RAM_DIN;  filter_buf8 <= FILTER_RAM_DIN;  end
                4'd8:  begin ifmap_buf9 <= IMAGE_RAM_DIN;  filter_buf9 <= FILTER_RAM_DIN;  end
                4'd9:  begin ifmap_buf10 <= IMAGE_RAM_DIN; filter_buf10 <= FILTER_RAM_DIN; end
                4'd10: begin ifmap_buf11 <= IMAGE_RAM_DIN; filter_buf11 <= FILTER_RAM_DIN; end
                4'd11: begin ifmap_buf12 <= IMAGE_RAM_DIN; filter_buf12 <= FILTER_RAM_DIN; end
                4'd12: begin ifmap_buf13 <= IMAGE_RAM_DIN; filter_buf13 <= FILTER_RAM_DIN; end
                4'd13: begin ifmap_buf14 <= IMAGE_RAM_DIN; filter_buf14 <= FILTER_RAM_DIN; end
                4'd14: begin ifmap_buf15 <= IMAGE_RAM_DIN; filter_buf15 <= FILTER_RAM_DIN; end
            endcase
        end
    end

    always @ (*) begin
        next_state = cur_state;
        next_kernel_row = cur_kernel_row;
        next_lane = cur_lane;
        next_feature_x = cur_feature_x;
        next_feature_y = cur_feature_y;
        next_acc = cur_acc;

        case(cur_state)
            IDLE: begin
                next_state = ISSUE_READ;
                next_kernel_row = 0;
                next_lane = 0;
                next_feature_x = 0;
                next_feature_y = 0;
                next_acc = 0;
            end
            ISSUE_READ: begin
                next_state = WAIT_DATA;
            end
            WAIT_DATA: begin
                if(IMAGE_RAM_DATA_VAL && FILTER_RAM_DATA_VAL)
                    next_state = STORE_DATA;
            end
            STORE_DATA: begin
                if(cur_lane == 14) begin
                    next_lane = 0;
                    next_state = MAC_ROW;
                end
                else begin
                    next_lane = cur_lane + 1;
                    next_state = ISSUE_READ;
                end
            end
            MAC_ROW: begin
                next_acc = cur_acc + mac_result;
                if(cur_kernel_row == 4) begin
                    next_kernel_row = 0;
                    next_state = WRITE;
                end
                else begin
                    next_kernel_row = cur_kernel_row + 1;
                    next_lane = 0;
                    next_state = ISSUE_READ;
                end
            end
            WRITE: begin
                next_acc = 0;
                if((cur_feature_x == FEATURE_WIDTH-1) && (cur_feature_y == FEATURE_WIDTH-1)) begin
                    next_state = EOC;
                end
                else begin
                    if(cur_feature_x == FEATURE_WIDTH-1) begin
                        next_feature_x = 0;
                        next_feature_y = cur_feature_y + 1;
                    end
                    else begin
                        next_feature_x = cur_feature_x + 1;
                    end
                    next_kernel_row = 0;
                    next_lane = 0;
                    next_state = ISSUE_READ;
                end
            end
            EOC: begin
                next_state = EOC;
            end
        endcase
    end

endmodule
