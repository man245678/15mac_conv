module MAC
#(
    parameter DATA_BW = 8
)(
    input CLK,
    input RSTN,
    input EN,

    input signed [DATA_BW-1:0] IFMAP_DATA_IN1,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN2,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN3,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN4,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN5,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN6,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN7,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN8,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN9,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN10,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN11,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN12,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN13,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN14,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN15,

    input signed [DATA_BW-1:0] FILTER_DATA_IN1,
    input signed [DATA_BW-1:0] FILTER_DATA_IN2,
    input signed [DATA_BW-1:0] FILTER_DATA_IN3,
    input signed [DATA_BW-1:0] FILTER_DATA_IN4,
    input signed [DATA_BW-1:0] FILTER_DATA_IN5,
    input signed [DATA_BW-1:0] FILTER_DATA_IN6,
    input signed [DATA_BW-1:0] FILTER_DATA_IN7,
    input signed [DATA_BW-1:0] FILTER_DATA_IN8,
    input signed [DATA_BW-1:0] FILTER_DATA_IN9,
    input signed [DATA_BW-1:0] FILTER_DATA_IN10,
    input signed [DATA_BW-1:0] FILTER_DATA_IN11,
    input signed [DATA_BW-1:0] FILTER_DATA_IN12,
    input signed [DATA_BW-1:0] FILTER_DATA_IN13,
    input signed [DATA_BW-1:0] FILTER_DATA_IN14,
    input signed [DATA_BW-1:0] FILTER_DATA_IN15,

    output signed [2*DATA_BW-1:0] MUL_DATA_OUT
);

reg signed [2*DATA_BW-1:0] mul1;
reg signed [2*DATA_BW-1:0] mul2;
reg signed [2*DATA_BW-1:0] mul3;
reg signed [2*DATA_BW-1:0] mul4;
reg signed [2*DATA_BW-1:0] mul5;
reg signed [2*DATA_BW-1:0] mul6;
reg signed [2*DATA_BW-1:0] mul7;
reg signed [2*DATA_BW-1:0] mul8;
reg signed [2*DATA_BW-1:0] mul9;
reg signed [2*DATA_BW-1:0] mul10;
reg signed [2*DATA_BW-1:0] mul11;
reg signed [2*DATA_BW-1:0] mul12;
reg signed [2*DATA_BW-1:0] mul13;
reg signed [2*DATA_BW-1:0] mul14;
reg signed [2*DATA_BW-1:0] mul15;
reg signed [2*DATA_BW-1:0] partial1;
reg signed [2*DATA_BW-1:0] partial2;
reg signed [2*DATA_BW-1:0] partial3;
reg signed [2*DATA_BW-1:0] partial4;
reg signed [2*DATA_BW-1:0] sum_reg;

assign MUL_DATA_OUT = sum_reg;

always @(posedge CLK or negedge RSTN) begin
    if(!RSTN) begin
        mul1 <= 0;
        mul2 <= 0;
        mul3 <= 0;
        mul4 <= 0;
        mul5 <= 0;
        mul6 <= 0;
        mul7 <= 0;
        mul8 <= 0;
        mul9 <= 0;
        mul10 <= 0;
        mul11 <= 0;
        mul12 <= 0;
        mul13 <= 0;
        mul14 <= 0;
        mul15 <= 0;
        partial1 <= 0;
        partial2 <= 0;
        partial3 <= 0;
        partial4 <= 0;
        sum_reg <= 0;
    end
    else begin
        partial1 <= mul1 + mul2 + mul3 + mul4;
        partial2 <= mul5 + mul6 + mul7 + mul8;
        partial3 <= mul9 + mul10 + mul11 + mul12;
        partial4 <= mul13 + mul14 + mul15;
        sum_reg <= partial1 + partial2 + partial3 + partial4;

        if(EN) begin
            mul1 <= IFMAP_DATA_IN1 * FILTER_DATA_IN1;
            mul2 <= IFMAP_DATA_IN2 * FILTER_DATA_IN2;
            mul3 <= IFMAP_DATA_IN3 * FILTER_DATA_IN3;
            mul4 <= IFMAP_DATA_IN4 * FILTER_DATA_IN4;
            mul5 <= IFMAP_DATA_IN5 * FILTER_DATA_IN5;
            mul6 <= IFMAP_DATA_IN6 * FILTER_DATA_IN6;
            mul7 <= IFMAP_DATA_IN7 * FILTER_DATA_IN7;
            mul8 <= IFMAP_DATA_IN8 * FILTER_DATA_IN8;
            mul9 <= IFMAP_DATA_IN9 * FILTER_DATA_IN9;
            mul10 <= IFMAP_DATA_IN10 * FILTER_DATA_IN10;
            mul11 <= IFMAP_DATA_IN11 * FILTER_DATA_IN11;
            mul12 <= IFMAP_DATA_IN12 * FILTER_DATA_IN12;
            mul13 <= IFMAP_DATA_IN13 * FILTER_DATA_IN13;
            mul14 <= IFMAP_DATA_IN14 * FILTER_DATA_IN14;
            mul15 <= IFMAP_DATA_IN15 * FILTER_DATA_IN15;
        end
    end
end

endmodule
