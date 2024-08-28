module uarttx(
    input clock115200hz,
    input resetn,
    input [7:0] data,
    input send,
    output reg ready,
    output UART_TX
);

    reg tx;
    reg [3:0] state;
    reg [7:0] shift_reg;

    assign UART_TX = tx;

    always @(posedge clock115200hz or negedge resetn) begin
        if (!resetn) begin
            tx <= 1'b1; // Idle state for UART TX is high
            ready <= 1'b1;
            state <= 4'h0;
        end else begin
            case (state)
                4'h0: begin
                    tx <= 1'b1; // Idle state
                    ready <= send ? 1'b0 : 1'b1;
                    state <= send ? 4'h1 : 4'h0;
                end
                4'h1: begin
                    tx <= 1'b0; // Start bit
                    shift_reg <= data;
                    state <= 4'h2;
                end
                4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7, 4'h8: begin
                    tx <= shift_reg[state - 2];
                    state <= state + 1'b1;
                end
                4'h9: begin
                    tx <= 1'b1; // Stop bit
                    state <= 4'h0;
                end
                default: state <= 4'h0;
            endcase
        end
    end

endmodule

module cheapuartrx(
    input clock115200hz,
    input resetn,
    output reg [7:0] data,
    output reg recv,
    input UART_RX
);

    reg [3:0] state;
    reg [7:0] buffer;
    wire rx = UART_RX;

    always @(posedge clock115200hz or negedge resetn) begin
        if (!resetn) begin
            data <= 8'b0;
            recv <= 1'b0;
            state <= 4'h0;
        end else begin
            case (state)
                4'h0: begin
                    recv <= 1'b0;
                    state <= (rx == 1'b0) ? 4'h1 : 4'h0; // Detect start bit
                end
                4'h1: begin
                    buffer <= {rx, buffer[7:1]};
                    state <= (buffer[0] == 1'b1) ? 4'h2 : 4'h1;
                end
                4'h2: begin
                    data <= buffer;
                    recv <= 1'b1;
                    state <= 4'h0;
                end
                default: state <= 4'h0;
            endcase
        end
    end

endmodule


module uartrx(
    input clock460800,
    input resetn,
    output reg [7:0] data,
    output reg recv,
    input UART_RX
);

    reg [3:0] state;
    reg [2:0] bit_count;
    reg [7:0] shift_reg;
    wire rx = UART_RX;

    always @(posedge clock460800 or negedge resetn) begin
        if (!resetn) begin
            data <= 8'b0;
            recv <= 1'b0;
            state <= 4'h0;
            bit_count <= 3'b0;
        end else begin
            case (state)
                4'h0: begin
                    recv <= 1'b0;
                    if (rx == 1'b0) begin
                        state <= 4'h1; // Start bit detected
                        bit_count <= 3'b0;
                    end
                end
                4'h1: begin
                    shift_reg[bit_count] <= rx;
                    bit_count <= bit_count + 1'b1;
                    if (bit_count == 7) begin
                        state <= 4'h2; // Data bits received
                    end
                end
                4'h2: begin
                    data <= shift_reg;
                    recv <= 1'b1;
                    state <= 4'h0;
                end
                default: state <= 4'h0;
            endcase
        end
    end

endmodule

