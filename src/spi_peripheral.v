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

    // Parameters
    localparam MAX_ADDRESS = 5'h04;

    // 2-stage synchronizers for CDC
    reg COPI_sync1, COPI_sync2;
    reg nCS_sync1,  nCS_sync2;
    reg SCLK_sync1, SCLK_sync2, SCLK_sync3;

    // Edge detection
    wire SCLK_rising  = ( SCLK_sync2 && !SCLK_sync3);
    wire nCS_falling  = (!nCS_sync1  &&  nCS_sync2);
    wire nCS_rising   = ( nCS_sync1  && !nCS_sync2);

    // Transaction state
    reg [15:0] shift_reg;
    reg [3:0]  bit_count;
    reg        transaction_ready;
    reg        transaction_processed;

    // Synchronizer chain
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            COPI_sync1 <= 0; COPI_sync2 <= 0;
            nCS_sync1  <= 1; nCS_sync2  <= 1;
            SCLK_sync1 <= 0; SCLK_sync2 <= 0; SCLK_sync3 <= 0;
        end else begin
            COPI_sync1 <= COPI;   COPI_sync2 <= COPI_sync1;
            nCS_sync1  <= nCS;    nCS_sync2  <= nCS_sync1;
            SCLK_sync1 <= SCLK;   SCLK_sync2 <= SCLK_sync1; SCLK_sync3 <= SCLK_sync2;
        end
    end

    // SPI shift register + bit counter + transaction_ready flag
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg         <= 16'b0;
            bit_count         <= 4'b0;
            transaction_ready <= 1'b0;
        end else if (nCS_sync2 == 1'b1) begin
            // nCS high = idle, reset counter
            bit_count <= 4'b0;
            if (nCS_rising && bit_count == 4'd15) begin
                transaction_ready <= 1'b1;
            end else if (transaction_processed) begin
                transaction_ready <= 1'b0;
            end
        end else begin
            // nCS low = active transaction
            if (SCLK_rising) begin
                shift_reg <= {shift_reg[14:0], COPI_sync2};
                bit_count <= bit_count + 1;
            end
        end
    end

    // Register update block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_reg_out_7_0   <= 8'h00;
            en_reg_out_15_8  <= 8'h00;
            en_reg_pwm_7_0   <= 8'h00;
            en_reg_pwm_15_8  <= 8'h00;
            pwm_duty_cycle   <= 8'h00;
            transaction_processed <= 1'b0;
        end else if (transaction_ready && !transaction_processed) begin
            // Parse: bit[15] = R/W, bits[14:8] = address, bits[7:0] = data
            if (shift_reg[15] == 1'b1) begin // Write
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
            transaction_processed <= 1'b1;
        end else if (!transaction_ready && transaction_processed) begin
            transaction_processed <= 1'b0;
        end
    end

endmodule