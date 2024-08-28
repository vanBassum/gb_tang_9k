module link (
    input clock115200hz,
    input clockgb,
    input resetn,
    input [15:0] address,
    input [7:0] indata,
    output [7:0] outdata,
    input load,
    input store,
    input UART_RX,
    output UART_TX
);

reg [7:0] data;
reg sending;
reg [3:0] state;
reg tx;

assign UART_TX = tx;

always @(posedge clock115200hz or negedge resetn) begin
    if (!resetn) begin
        tx <= 1'b1;
        state <= 4'h0;
    end else begin
        if (state == 4'h0) begin
            tx <= 1'b1;
            state <= sending ? 4'h1 : 4'h0;
        end else begin
            tx <= state == 4'h1 ? 1'b0 : data[state-2];
            state <= state == 4'h9 ? 4'h0 : state + 1'b1;
        end
    end
end

always @(posedge clockgb or negedge resetn) begin
    if (!resetn) begin
        data <= 8'b0;
        sending <= 1'b0;
    end else begin
        if (sio_store) begin
            sending <= sio_indata[7];
        end else if (state != 4'h0) begin
            sending <= 1'b0;
        end
        
        if (data_store) begin
            data <= data_indata;
        end
    end
end

wire [7:0] data_indata;
wire [7:0] data_data;
wire data_store;

rrmmap #(16'hff01) data_mmap (
    .clockgb(clockgb),
    .resetn(resetn),
    .address(address),
    .indata(indata),
    .outdata(data_data),
    .load(load),
    .store(store),
    .data_indata(data_indata),
    .data(data),
    .data_store(data_store)
);

wire [7:0] sio_indata;
wire [7:0] sio_data;
wire sio_store;

rrmmap #(16'hff02) sio_mmap (
    .clockgb(clockgb),
    .resetn(resetn),
    .address(address),
    .indata(indata),
    .outdata(sio_data),
    .load(load),
    .store(store),
    .data_indata(sio_indata),
    .data({state != 4'h0 || sending, 7'h00}),
    .sio_store(sio_store)
);

assign outdata = data_data | sio_data;

endmodule
