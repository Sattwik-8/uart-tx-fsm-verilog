module uart_tx #(
    parameter BAUD_DIV = 4
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx_line,
    output reg        tx_busy
);

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [7:0] shift_reg;
    reg [2:0] bit_count;

    // Resets the baud counter exactly when a new transmission begins
    wire start_pulse = (state == IDLE) && tx_start;

    reg [15:0] baud_count;
    reg        baud_tick;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_count <= 0;
            baud_tick  <= 0;
        end else if (start_pulse) begin
            baud_count <= 0;
            baud_tick  <= 0;
        end else begin
            if (baud_count == BAUD_DIV - 1) begin
                baud_count <= 0;
                baud_tick  <= 1;
            end else begin
                baud_count <= baud_count + 1;
                baud_tick  <= 0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            tx_line   <= 1'b1;
            tx_busy   <= 1'b0;
            shift_reg <= 8'd0;
            bit_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    tx_line <= 1'b1;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        tx_busy   <= 1'b1;
                        state     <= START;
                    end
                end
                START: begin
                    tx_line <= 1'b0;
                    if (baud_tick) begin
                        state     <= DATA;
                        bit_count <= 3'd0;
                    end
                end
                DATA: begin
                    tx_line <= shift_reg[0];
                    if (baud_tick) begin
                        shift_reg <= shift_reg >> 1;
                        if (bit_count == 3'd7)
                            state <= STOP;
                        else
                            bit_count <= bit_count + 1;
                    end
                end
                STOP: begin
                    tx_line <= 1'b1;
                    if (baud_tick) begin
                        tx_busy <= 1'b0;
                        state   <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
