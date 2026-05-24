`define DECL_WIN(A0,A1,A2,A3,A4) \
    reg signed [BITWIDTH-1:0] A0 [0:FEATURE_WIDTH-1]; \
    reg signed [BITWIDTH-1:0] A1 [0:FEATURE_WIDTH-1]; \
    reg signed [BITWIDTH-1:0] A2 [0:FEATURE_WIDTH-1]; \
    reg signed [BITWIDTH-1:0] A3 [0:FEATURE_WIDTH-1]; \
    reg signed [BITWIDTH-1:0] A4 [0:FEATURE_WIDTH-1]

`define STORE_WIN(A0,A1,A2,A3,A4) begin \
    case(load_col_mod) \
        2'd0: begin \
            if(load_fx < FEATURE_WIDTH) A0[load_fx] <= IMAGE_RAM_DIN; \
            if(load_fx != 0) A3[load_fx - 1] <= IMAGE_RAM_DIN; \
        end \
        2'd1: begin \
            if(load_fx < FEATURE_WIDTH) A1[load_fx] <= IMAGE_RAM_DIN; \
            if(load_fx != 0) A4[load_fx - 1] <= IMAGE_RAM_DIN; \
        end \
        default: begin \
            if(load_fx < FEATURE_WIDTH) A2[load_fx] <= IMAGE_RAM_DIN; \
        end \
    endcase \
end

`define CAPTURE_SLOT(A00,A01,A02,A03,A04,A10,A11,A12,A13,A14,A20,A21,A22,A23,A24) begin \
    ifmap_pipe1  <= A00[cur_compute_x]; \
    ifmap_pipe2  <= A01[cur_compute_x]; \
    ifmap_pipe3  <= A02[cur_compute_x]; \
    ifmap_pipe4  <= A03[cur_compute_x]; \
    ifmap_pipe5  <= A04[cur_compute_x]; \
    ifmap_pipe6  <= A10[cur_compute_x]; \
    ifmap_pipe7  <= A11[cur_compute_x]; \
    ifmap_pipe8  <= A12[cur_compute_x]; \
    ifmap_pipe9  <= A13[cur_compute_x]; \
    ifmap_pipe10 <= A14[cur_compute_x]; \
    ifmap_pipe11 <= A20[cur_compute_x]; \
    ifmap_pipe12 <= A21[cur_compute_x]; \
    ifmap_pipe13 <= A22[cur_compute_x]; \
    ifmap_pipe14 <= A23[cur_compute_x]; \
    ifmap_pipe15 <= A24[cur_compute_x]; \
end

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

    localparam IDLE          = 4'd0;
    localparam ISSUE_FILTER  = 4'd1;
    localparam WAIT_FILTER   = 4'd2;
    localparam STORE_FILTER  = 4'd3;
    localparam ISSUE_IMAGE   = 4'd4;
    localparam WAIT_IMAGE    = 4'd5;
    localparam STORE_IMAGE   = 4'd6;
    localparam CLEAR_PSUM    = 4'd7;
    localparam READ_SLOT     = 4'd8;
    localparam COMPUTE       = 4'd9;
    localparam SUM_PARTIAL   = 4'd10;
    localparam SUM_FINAL     = 4'd11;
    localparam ACCUMULATE    = 4'd12;
    localparam WRITE_FEATURE = 4'd13;
    localparam DONE          = 4'd14;

    reg [3:0] cur_state, next_state;
    reg [6:0] cur_filter_idx, next_filter_idx;
    reg [6:0] cur_load_row, next_load_row;
    reg [8:0] cur_load_idx, next_load_idx;
    reg [5:0] cur_load_fx, next_load_fx;
    reg [1:0] cur_load_col_mod, next_load_col_mod;
    reg [4:0] cur_feature_y, next_feature_y;
    reg [4:0] cur_compute_x, next_compute_x;
    reg [2:0] cur_kernel_row, next_kernel_row;
    reg [4:0] cur_clear_idx, next_clear_idx;
    reg [4:0] cur_write_idx, next_write_idx;

    reg signed [BITWIDTH-1:0] ifmap_pipe1;
    reg signed [BITWIDTH-1:0] ifmap_pipe2;
    reg signed [BITWIDTH-1:0] ifmap_pipe3;
    reg signed [BITWIDTH-1:0] ifmap_pipe4;
    reg signed [BITWIDTH-1:0] ifmap_pipe5;
    reg signed [BITWIDTH-1:0] ifmap_pipe6;
    reg signed [BITWIDTH-1:0] ifmap_pipe7;
    reg signed [BITWIDTH-1:0] ifmap_pipe8;
    reg signed [BITWIDTH-1:0] ifmap_pipe9;
    reg signed [BITWIDTH-1:0] ifmap_pipe10;
    reg signed [BITWIDTH-1:0] ifmap_pipe11;
    reg signed [BITWIDTH-1:0] ifmap_pipe12;
    reg signed [BITWIDTH-1:0] ifmap_pipe13;
    reg signed [BITWIDTH-1:0] ifmap_pipe14;
    reg signed [BITWIDTH-1:0] ifmap_pipe15;

    reg signed [BITWIDTH-1:0] filter_pipe1;
    reg signed [BITWIDTH-1:0] filter_pipe2;
    reg signed [BITWIDTH-1:0] filter_pipe3;
    reg signed [BITWIDTH-1:0] filter_pipe4;
    reg signed [BITWIDTH-1:0] filter_pipe5;
    reg signed [BITWIDTH-1:0] filter_pipe6;
    reg signed [BITWIDTH-1:0] filter_pipe7;
    reg signed [BITWIDTH-1:0] filter_pipe8;
    reg signed [BITWIDTH-1:0] filter_pipe9;
    reg signed [BITWIDTH-1:0] filter_pipe10;
    reg signed [BITWIDTH-1:0] filter_pipe11;
    reg signed [BITWIDTH-1:0] filter_pipe12;
    reg signed [BITWIDTH-1:0] filter_pipe13;
    reg signed [BITWIDTH-1:0] filter_pipe14;
    reg signed [BITWIDTH-1:0] filter_pipe15;

    `DECL_WIN(win0_ch0_0, win0_ch0_1, win0_ch0_2, win0_ch0_3, win0_ch0_4);
    `DECL_WIN(win0_ch1_0, win0_ch1_1, win0_ch1_2, win0_ch1_3, win0_ch1_4);
    `DECL_WIN(win0_ch2_0, win0_ch2_1, win0_ch2_2, win0_ch2_3, win0_ch2_4);
    `DECL_WIN(win1_ch0_0, win1_ch0_1, win1_ch0_2, win1_ch0_3, win1_ch0_4);
    `DECL_WIN(win1_ch1_0, win1_ch1_1, win1_ch1_2, win1_ch1_3, win1_ch1_4);
    `DECL_WIN(win1_ch2_0, win1_ch2_1, win1_ch2_2, win1_ch2_3, win1_ch2_4);
    `DECL_WIN(win2_ch0_0, win2_ch0_1, win2_ch0_2, win2_ch0_3, win2_ch0_4);
    `DECL_WIN(win2_ch1_0, win2_ch1_1, win2_ch1_2, win2_ch1_3, win2_ch1_4);
    `DECL_WIN(win2_ch2_0, win2_ch2_1, win2_ch2_2, win2_ch2_3, win2_ch2_4);
    `DECL_WIN(win3_ch0_0, win3_ch0_1, win3_ch0_2, win3_ch0_3, win3_ch0_4);
    `DECL_WIN(win3_ch1_0, win3_ch1_1, win3_ch1_2, win3_ch1_3, win3_ch1_4);
    `DECL_WIN(win3_ch2_0, win3_ch2_1, win3_ch2_2, win3_ch2_3, win3_ch2_4);
    `DECL_WIN(win4_ch0_0, win4_ch0_1, win4_ch0_2, win4_ch0_3, win4_ch0_4);
    `DECL_WIN(win4_ch1_0, win4_ch1_1, win4_ch1_2, win4_ch1_3, win4_ch1_4);
    `DECL_WIN(win4_ch2_0, win4_ch2_1, win4_ch2_2, win4_ch2_3, win4_ch2_4);

    reg signed [BITWIDTH-1:0] filter_buf [0:3*FILTER_WIDTH*FILTER_WIDTH-1];
    reg signed [2*BITWIDTH-1:0] psum [0:FEATURE_WIDTH-1];

    wire [1:0] load_channel = (cur_load_idx < IMAGE_WIDTH) ? 0 :
                              ((cur_load_idx < 2*IMAGE_WIDTH) ? 1 : 2);
    wire [6:0] load_col = (cur_load_idx < IMAGE_WIDTH) ? cur_load_idx[6:0] :
                          ((cur_load_idx < 2*IMAGE_WIDTH) ?
                           (cur_load_idx - IMAGE_WIDTH) :
                           (cur_load_idx - 2*IMAGE_WIDTH));
    wire [5:0] load_fx = cur_load_fx;
    wire [1:0] load_col_mod = cur_load_col_mod;
    wire [2:0] load_slot = cur_load_row % 5;
    wire [6:0] active_abs_row = cur_feature_y * 3 + cur_kernel_row;
    wire [2:0] active_slot = active_abs_row % 5;
    wire [6:0] filter_base = cur_kernel_row * FILTER_WIDTH;
    wire signed [2*BITWIDTH-1:0] mac_result;

    assign IMAGE_RAM_EN = (cur_state == ISSUE_IMAGE);
    assign FILTER_RAM_EN = (cur_state == ISSUE_FILTER);
    assign FEATURE_RAM_EN = (cur_state == WRITE_FEATURE);
    assign FEATURE_RAM_WEN = (cur_state == WRITE_FEATURE);
    assign IMAGE_RAM_ADDRESS = load_channel * IMAGE_WIDTH * IMAGE_WIDTH +
                               cur_load_row * IMAGE_WIDTH + load_col;
    assign FILTER_RAM_ADDRESS = cur_filter_idx;
    assign FEATURE_RAM_ADDRESS = cur_write_idx + cur_feature_y * FEATURE_WIDTH;
    assign FEATURE_RAM_DOUT = psum[cur_write_idx];
    assign eoc = (cur_state == DONE);

    MAC #(.DATA_BW(BITWIDTH)) u_MAC (
        .CLK(clk), .RSTN(resetn), .EN(cur_state == COMPUTE),
        .IFMAP_DATA_IN1(ifmap_pipe1), .IFMAP_DATA_IN2(ifmap_pipe2), .IFMAP_DATA_IN3(ifmap_pipe3),
        .IFMAP_DATA_IN4(ifmap_pipe4), .IFMAP_DATA_IN5(ifmap_pipe5), .IFMAP_DATA_IN6(ifmap_pipe6),
        .IFMAP_DATA_IN7(ifmap_pipe7), .IFMAP_DATA_IN8(ifmap_pipe8), .IFMAP_DATA_IN9(ifmap_pipe9),
        .IFMAP_DATA_IN10(ifmap_pipe10), .IFMAP_DATA_IN11(ifmap_pipe11), .IFMAP_DATA_IN12(ifmap_pipe12),
        .IFMAP_DATA_IN13(ifmap_pipe13), .IFMAP_DATA_IN14(ifmap_pipe14), .IFMAP_DATA_IN15(ifmap_pipe15),
        .FILTER_DATA_IN1(filter_pipe1), .FILTER_DATA_IN2(filter_pipe2), .FILTER_DATA_IN3(filter_pipe3),
        .FILTER_DATA_IN4(filter_pipe4), .FILTER_DATA_IN5(filter_pipe5), .FILTER_DATA_IN6(filter_pipe6),
        .FILTER_DATA_IN7(filter_pipe7), .FILTER_DATA_IN8(filter_pipe8), .FILTER_DATA_IN9(filter_pipe9),
        .FILTER_DATA_IN10(filter_pipe10), .FILTER_DATA_IN11(filter_pipe11), .FILTER_DATA_IN12(filter_pipe12),
        .FILTER_DATA_IN13(filter_pipe13), .FILTER_DATA_IN14(filter_pipe14), .FILTER_DATA_IN15(filter_pipe15),
        .MUL_DATA_OUT(mac_result)
    );

    always @ (posedge clk or negedge resetn) begin
        if(!resetn) begin
            cur_state <= IDLE;
            cur_filter_idx <= 0;
            cur_load_row <= 0;
            cur_load_idx <= 0;
            cur_load_fx <= 0;
            cur_load_col_mod <= 0;
            cur_feature_y <= 0;
            cur_compute_x <= 0;
            cur_kernel_row <= 0;
            cur_clear_idx <= 0;
            cur_write_idx <= 0;
        end
        else begin
            cur_state <= next_state;
            cur_filter_idx <= next_filter_idx;
            cur_load_row <= next_load_row;
            cur_load_idx <= next_load_idx;
            cur_load_fx <= next_load_fx;
            cur_load_col_mod <= next_load_col_mod;
            cur_feature_y <= next_feature_y;
            cur_compute_x <= next_compute_x;
            cur_kernel_row <= next_kernel_row;
            cur_clear_idx <= next_clear_idx;
            cur_write_idx <= next_write_idx;
        end
    end

    always @ (posedge clk or negedge resetn) begin
        if(!resetn) begin
        end
        else if((cur_state == WAIT_FILTER) && FILTER_RAM_DATA_VAL) begin
            filter_buf[cur_filter_idx] <= FILTER_RAM_DIN;
        end
        else if((cur_state == WAIT_IMAGE) && IMAGE_RAM_DATA_VAL) begin
            case({load_slot, load_channel})
                5'b00000: `STORE_WIN(win0_ch0_0, win0_ch0_1, win0_ch0_2, win0_ch0_3, win0_ch0_4)
                5'b00001: `STORE_WIN(win0_ch1_0, win0_ch1_1, win0_ch1_2, win0_ch1_3, win0_ch1_4)
                5'b00010: `STORE_WIN(win0_ch2_0, win0_ch2_1, win0_ch2_2, win0_ch2_3, win0_ch2_4)
                5'b00100: `STORE_WIN(win1_ch0_0, win1_ch0_1, win1_ch0_2, win1_ch0_3, win1_ch0_4)
                5'b00101: `STORE_WIN(win1_ch1_0, win1_ch1_1, win1_ch1_2, win1_ch1_3, win1_ch1_4)
                5'b00110: `STORE_WIN(win1_ch2_0, win1_ch2_1, win1_ch2_2, win1_ch2_3, win1_ch2_4)
                5'b01000: `STORE_WIN(win2_ch0_0, win2_ch0_1, win2_ch0_2, win2_ch0_3, win2_ch0_4)
                5'b01001: `STORE_WIN(win2_ch1_0, win2_ch1_1, win2_ch1_2, win2_ch1_3, win2_ch1_4)
                5'b01010: `STORE_WIN(win2_ch2_0, win2_ch2_1, win2_ch2_2, win2_ch2_3, win2_ch2_4)
                5'b01100: `STORE_WIN(win3_ch0_0, win3_ch0_1, win3_ch0_2, win3_ch0_3, win3_ch0_4)
                5'b01101: `STORE_WIN(win3_ch1_0, win3_ch1_1, win3_ch1_2, win3_ch1_3, win3_ch1_4)
                5'b01110: `STORE_WIN(win3_ch2_0, win3_ch2_1, win3_ch2_2, win3_ch2_3, win3_ch2_4)
                5'b10000: `STORE_WIN(win4_ch0_0, win4_ch0_1, win4_ch0_2, win4_ch0_3, win4_ch0_4)
                5'b10001: `STORE_WIN(win4_ch1_0, win4_ch1_1, win4_ch1_2, win4_ch1_3, win4_ch1_4)
                5'b10010: `STORE_WIN(win4_ch2_0, win4_ch2_1, win4_ch2_2, win4_ch2_3, win4_ch2_4)
            endcase
        end
    end

    always @ (posedge clk or negedge resetn) begin
        if(!resetn) begin
        end
        else begin
            if(cur_state == CLEAR_PSUM) begin
                psum[cur_clear_idx] <= 0;
            end
            else if(cur_state == READ_SLOT) begin
                case(active_slot)
                    3'd0: `CAPTURE_SLOT(win0_ch0_0, win0_ch0_1, win0_ch0_2, win0_ch0_3, win0_ch0_4, win0_ch1_0, win0_ch1_1, win0_ch1_2, win0_ch1_3, win0_ch1_4, win0_ch2_0, win0_ch2_1, win0_ch2_2, win0_ch2_3, win0_ch2_4)
                    3'd1: `CAPTURE_SLOT(win1_ch0_0, win1_ch0_1, win1_ch0_2, win1_ch0_3, win1_ch0_4, win1_ch1_0, win1_ch1_1, win1_ch1_2, win1_ch1_3, win1_ch1_4, win1_ch2_0, win1_ch2_1, win1_ch2_2, win1_ch2_3, win1_ch2_4)
                    3'd2: `CAPTURE_SLOT(win2_ch0_0, win2_ch0_1, win2_ch0_2, win2_ch0_3, win2_ch0_4, win2_ch1_0, win2_ch1_1, win2_ch1_2, win2_ch1_3, win2_ch1_4, win2_ch2_0, win2_ch2_1, win2_ch2_2, win2_ch2_3, win2_ch2_4)
                    3'd3: `CAPTURE_SLOT(win3_ch0_0, win3_ch0_1, win3_ch0_2, win3_ch0_3, win3_ch0_4, win3_ch1_0, win3_ch1_1, win3_ch1_2, win3_ch1_3, win3_ch1_4, win3_ch2_0, win3_ch2_1, win3_ch2_2, win3_ch2_3, win3_ch2_4)
                    3'd4: `CAPTURE_SLOT(win4_ch0_0, win4_ch0_1, win4_ch0_2, win4_ch0_3, win4_ch0_4, win4_ch1_0, win4_ch1_1, win4_ch1_2, win4_ch1_3, win4_ch1_4, win4_ch2_0, win4_ch2_1, win4_ch2_2, win4_ch2_3, win4_ch2_4)
                endcase
                filter_pipe1  <= filter_buf[filter_base + 0];
                filter_pipe2  <= filter_buf[filter_base + 1];
                filter_pipe3  <= filter_buf[filter_base + 2];
                filter_pipe4  <= filter_buf[filter_base + 3];
                filter_pipe5  <= filter_buf[filter_base + 4];
                filter_pipe6  <= filter_buf[25 + filter_base + 0];
                filter_pipe7  <= filter_buf[25 + filter_base + 1];
                filter_pipe8  <= filter_buf[25 + filter_base + 2];
                filter_pipe9  <= filter_buf[25 + filter_base + 3];
                filter_pipe10 <= filter_buf[25 + filter_base + 4];
                filter_pipe11 <= filter_buf[50 + filter_base + 0];
                filter_pipe12 <= filter_buf[50 + filter_base + 1];
                filter_pipe13 <= filter_buf[50 + filter_base + 2];
                filter_pipe14 <= filter_buf[50 + filter_base + 3];
                filter_pipe15 <= filter_buf[50 + filter_base + 4];
            end
            else if(cur_state == ACCUMULATE) begin
                psum[cur_compute_x] <= psum[cur_compute_x] + mac_result;
            end
        end
    end

    always @ (*) begin
        next_state = cur_state;
        next_filter_idx = cur_filter_idx;
        next_load_row = cur_load_row;
        next_load_idx = cur_load_idx;
        next_load_fx = cur_load_fx;
        next_load_col_mod = cur_load_col_mod;
        next_feature_y = cur_feature_y;
        next_compute_x = cur_compute_x;
        next_kernel_row = cur_kernel_row;
        next_clear_idx = cur_clear_idx;
        next_write_idx = cur_write_idx;

        case(cur_state)
            IDLE: begin
                next_state = ISSUE_FILTER;
                next_filter_idx = 0;
                next_load_row = 0;
                next_load_idx = 0;
                next_load_fx = 0;
                next_load_col_mod = 0;
                next_feature_y = 0;
                next_compute_x = 0;
                next_kernel_row = 0;
                next_clear_idx = 0;
                next_write_idx = 0;
            end
            ISSUE_FILTER: begin
                next_state = WAIT_FILTER;
            end
            WAIT_FILTER: begin
                if(FILTER_RAM_DATA_VAL)
                    next_state = STORE_FILTER;
            end
            STORE_FILTER: begin
                if(cur_filter_idx == 74) begin
                    next_state = ISSUE_IMAGE;
                    next_load_row = 0;
                    next_load_idx = 0;
                    next_load_fx = 0;
                    next_load_col_mod = 0;
                end
                else begin
                    next_filter_idx = cur_filter_idx + 1;
                    next_state = ISSUE_FILTER;
                end
            end
            ISSUE_IMAGE: begin
                next_state = WAIT_IMAGE;
            end
            WAIT_IMAGE: begin
                if(IMAGE_RAM_DATA_VAL)
                    next_state = STORE_IMAGE;
            end
            STORE_IMAGE: begin
                if(cur_load_idx == 3*IMAGE_WIDTH-1) begin
                    next_load_idx = 0;
                    next_load_fx = 0;
                    next_load_col_mod = 0;
                    if((cur_feature_y == 0 && cur_load_row == 4) ||
                       (cur_feature_y != 0 && cur_load_row == cur_feature_y*3 + 4)) begin
                        next_state = CLEAR_PSUM;
                        next_clear_idx = 0;
                    end
                    else begin
                        next_load_row = cur_load_row + 1;
                        next_state = ISSUE_IMAGE;
                    end
                end
                else begin
                    next_load_idx = cur_load_idx + 1;
                    if(load_col == IMAGE_WIDTH-1) begin
                        next_load_fx = 0;
                        next_load_col_mod = 0;
                    end
                    else if(cur_load_col_mod == 2) begin
                        next_load_fx = cur_load_fx + 1;
                        next_load_col_mod = 0;
                    end
                    else begin
                        next_load_col_mod = cur_load_col_mod + 1;
                    end
                    next_state = ISSUE_IMAGE;
                end
            end
            CLEAR_PSUM: begin
                if(cur_clear_idx == FEATURE_WIDTH-1) begin
                    next_state = READ_SLOT;
                    next_compute_x = 0;
                    next_kernel_row = 0;
                end
                else begin
                    next_clear_idx = cur_clear_idx + 1;
                end
            end
            READ_SLOT: begin
                next_state = COMPUTE;
            end
            COMPUTE: begin
                next_state = SUM_PARTIAL;
            end
            SUM_PARTIAL: begin
                next_state = SUM_FINAL;
            end
            SUM_FINAL: begin
                next_state = ACCUMULATE;
            end
            ACCUMULATE: begin
                if(cur_kernel_row == 4) begin
                    next_kernel_row = 0;
                    if(cur_compute_x == FEATURE_WIDTH-1) begin
                        next_compute_x = 0;
                        next_state = WRITE_FEATURE;
                        next_write_idx = 0;
                    end
                    else begin
                        next_compute_x = cur_compute_x + 1;
                        next_state = READ_SLOT;
                    end
                end
                else begin
                    next_kernel_row = cur_kernel_row + 1;
                    next_state = READ_SLOT;
                end
            end
            WRITE_FEATURE: begin
                if(cur_write_idx == FEATURE_WIDTH-1) begin
                    if(cur_feature_y == FEATURE_WIDTH-1) begin
                        next_state = DONE;
                    end
                    else begin
                        next_feature_y = cur_feature_y + 1;
                        next_load_row = (cur_feature_y + 1) * 3 + 2;
                        next_load_idx = 0;
                        next_load_fx = 0;
                        next_load_col_mod = 0;
                        next_state = ISSUE_IMAGE;
                    end
                end
                else begin
                    next_write_idx = cur_write_idx + 1;
                end
            end
            DONE: begin
                next_state = DONE;
            end
        endcase
    end

endmodule
