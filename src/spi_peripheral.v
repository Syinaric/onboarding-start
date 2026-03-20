`default_nettype none

module spi_peripheral (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       COPI,
    input  wire       nCS,
    input  wire       SCLK,
    output reg  [7:0] en_reg_out_7_0,
    output reg  [7:0] en_reg_out_15_8,
    output reg  [7:0] en_reg_pwm_7_0,
    output reg  [7:0] en_reg_pwm_15_8,
    output reg  [7:0] pwm_duty_cycle
);

    localparam MAX_ADDRESS = 7'h04;

    // 2-stage synchronizers
    reg COPI_sync1, COPI_sync2;
    reg nCS_sync1,  nCS_sync2,  nCS_sync3;
    reg SCLK_sync1, SCLK_sync2, SCLK_sync3;

    // Edge detection
    wire SCLK_rising = (SCLK_sync2  && !SCLK_sync3);
    wire nCS_rising  = (nCS_sync2   && !nCS_sync3);

    // Transaction state
    reg [15:0] shift_reg;
    reg [4:0]  bit_count;

    // Synchronizer chain
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            COPI_sync1 <= 0; COPI_sync2 <= 0;
            nCS_sync1  <= 1; nCS_sync2  <= 1; nCS_sync3  <= 1;
            SCLK_sync1 <= 0; SCLK_sync2 <= 0; SCLK_sync3 <= 0;
        end else begin
            COPI_sync1 <= COPI;       COPI_sync2 <= COPI_sync1;
            nCS_sync1  <= nCS;        nCS_sync2  <= nCS_sync1;  nCS_sync3  <= nCS_sync2;
            SCLK_sync1 <= SCLK;       SCLK_sync2 <= SCLK_sync1; SCLK_sync3 <= SCLK_sync2;
        end
    end

    // Shift register and bit counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 16'b0;
            bit_count <= 5'b0;
        end else if (nCS_sync2 == 1'b1) begin
            bit_count <= 5'b0;
        end else if (SCLK_rising && bit_count < 5'd16) begin
            shift_reg <= {shift_reg[14:0], COPI_sync2};
            bit_count <= bit_count + 1;
        end
    end

    // Register update on nCS rising edge
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_reg_out_7_0  <= 8'h00;
            en_reg_out_15_8 <= 8'h00;
            en_reg_pwm_7_0  <= 8'h00;
            en_reg_pwm_15_8 <= 8'h00;
            pwm_duty_cycle  <= 8'h00;
        end else if (nCS_rising && bit_count == 5'd16) begin
            if (shift_reg[15] == 1'b1) begin
                if (shift_reg[14:8] <= MAX_ADDRESS) begin
                    case (shift_reg[14:8])
                        7'h00: en_reg_out_7_0  <= shift_reg[7:0];
                        7'h01: en_reg_out_15_8 <= shift_reg[7:0];
                        7'h02: en_reg_pwm_7_0  <= shift_reg[7:0];
                        7'h03: en_reg_pwm_15_8 <= shift_reg[7:0];
                        7'h04: pwm_duty_cycle  <= shift_reg[7:0];
                    endcase
                end
            end
        end
    end

endmodule