module sram(
    // Clock and Reset
    input clock,
    input clock115200hz,
    input clock460800hz,
    input resetn,

    // Address and Data
    input [18:0] address,
    input [7:0] indata,
    output reg [7:0] outdata,
    input load,
    input store,
    input prog,

    // UART to USB
    input UART_RX,
    output UART_TX,

    // SRAM
    output [17:0] SRAM_A,
    inout [15:0] SRAM_D,
    output SRAM_CE_n,
    output SRAM_LB_n,
    output SRAM_OE_n,
    output SRAM_UB_n,
    output SRAM_WE_n
);

    // Internal Signals
    wire [15:0] ram_bus;
    wire [1:0] ram_bytes;
    wire [7:0] ram_indata;
    wire uart_recv;
    wire [7:0] uart_data;
    
    reg [18:0] ram_address;
    reg [7:0] ram_outdata;
    reg ram_load;
    reg ram_store;
    
    reg [31:0] flash_address;
    reg [31:0] flash_count;
    reg [3:0] flash_state;
    reg uart_recv_ack;

    // Assign SRAM Control Signals
    assign SRAM_A = ram_address[18:1];
    assign SRAM_D = ram_store ? {ram_outdata, ram_outdata} : 16'hzzzz;
    assign SRAM_CE_n = 1'b0;
    assign SRAM_UB_n = ~ram_bytes[1];
    assign SRAM_LB_n = ~ram_bytes[0];
    assign SRAM_OE_n = ~ram_load;
    assign SRAM_WE_n = ~ram_store;

    assign ram_bytes = ram_address[0] ? 2'b01 : 2'b10;
    assign ram_indata = ram_address[0] ? SRAM_D[7:0] : SRAM_D[15:8];

    // Instantiate UART Modules
    uartrx comm_uart (
        .clock(clock460800hz),
        .resetn(resetn),
        .data_out(uart_data),
        .recv(uart_recv),
        .uart_rx(UART_RX)
    );

    uarttx check_uart (
        .clock(clock115200hz),
        .resetn(resetn),
        .data_in(uart_data),
        .send(uart_recv),
        .uart_tx(UART_TX)
    );

    // SRAM and Flash Logic
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            // Reset State
            ram_address <= 0;
            ram_outdata <= 0;
            ram_load <= 0;
            ram_store <= 0;
            outdata <= 0;

            flash_state <= 0;
            uart_recv_ack <= 0;
        end else if (prog) begin
            // Program Mode
            uart_recv_ack <= uart_recv;

            if (uart_recv && !uart_recv_ack) begin
                case (flash_state)
                    4'h0: begin
                        flash_state <= 4'h1;
                        flash_address <= {flash_address[23:0], uart_data};
                    end
                    4'h1: begin
                        flash_state <= 4'h2;
                        flash_address <= {flash_address[23:0], uart_data};
                    end
                    4'h2: begin
                        flash_state <= 4'h3;
                        flash_address <= {flash_address[23:0], uart_data};
                    end
                    4'h3: begin
                        flash_state <= 4'h4;
                        flash_address <= {flash_address[23:0], uart_data};
                    end
                    4'h4: begin
                        flash_state <= 4'h5;
                        flash_count <= {flash_count[23:0], uart_data};
                    end
                    4'h5: begin
                        flash_state <= 4'h6;
                        flash_count <= {flash_count[23:0], uart_data};
                    end
                    4'h6: begin
                        flash_state <= 4'h7;
                        flash_count <= {flash_count[23:0], uart_data};
                    end
                    4'h7: begin
                        flash_state <= 4'h8;
                        flash_count <= {flash_count[23:0], uart_data};
                    end
                    4'h8: begin
                        if (flash_count == 0) begin
                            flash_state <= 4'h0;
                        end else begin
                            flash_address <= flash_address + 1;
                            flash_count <= flash_count - 1;
                            ram_address <= flash_address[18:0];
                            ram_outdata <= uart_data;
                            ram_load <= 0;
                            ram_store <= 1;
                        end
                    end
                endcase
            end
        end else begin
            // Normal Operation
            ram_address <= address;
            ram_outdata <= indata;
            ram_load <= load;
            ram_store <= store;
            outdata <= ram_indata;

            flash_state <= 0;
            uart_recv_ack <= 0;
        end 
    end

endmodule
