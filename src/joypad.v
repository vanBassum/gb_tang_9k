module joypad (
    input clock460800hz,
    input clockgb,
    input resetn,
    output reg joy_int,
    input [15:0] address,
    input [7:0] indata,
    output [7:0] outdata,
    input load,
    input store,
    input UART_RX,
    output UART_TX
);

assign UART_TX = 1'b1;

reg [1:0] joy_sel;
reg [7:0] joy_buttons;

reg [7:0] joy_outdata;

always @(*) begin
    joy_outdata = {2'b0, joy_sel, 4'hf};
    
    if (joy_sel[0]) begin
        joy_outdata = joy_outdata & ~joy_buttons[3:0];
    end
    
    if (joy_sel[1]) begin
        joy_outdata = joy_outdata & ~joy_buttons[7:4];
    end
end

wire [7:0] uart_data;
wire uart_recv;

uartrx uartrx (
    .clock460800hz(clock460800hz),
    .resetn(resetn),
    .uart_data(uart_data),
    .uart_recv(uart_recv),
    .UART_RX(UART_RX)
);

always @(posedge clockgb or negedge resetn) begin
    if (!resetn) begin
        joy_sel <= 2'b0;
        joy_buttons <= 8'b0;
        joy_int <= 1'b0;
    end else begin
        joy_int <= 1'b0;
    
        if (joy_store) begin
            joy_sel <= joy_indata[5:4];
        end
        
        if (uart_recv) begin
            joy_buttons <= uart_data;
            
            if (uart_data & ~joy_buttons) begin
                joy_int <= 1'b1;
            end
        end
    end
end

wire [7:0] joy_indata;
wire joy_store;

rrmmap #(16'hff00) joy_mmap (
    .clockgb(clockgb),
    .resetn(resetn),
    .address(address),
    .indata(indata),
    .outdata(outdata),
    .load(load),
    .store(store),
    .joy_indata(joy_indata),
    .joy_outdata(joy_outdata),
    .joy_store(joy_store)
);

endmodule
