module timer(
    input clockgb,
    input resetn,
    output overflow_int,
    input [15:0] address,
    input [7:0] indata,
    output [7:0] outdata,
    input load,
    input store,
    output [7:0] dtimer
);

    // Internal signals
    reg [7:0] tma;
    reg [7:0] tac;
    reg [15:0] tdiv;
    reg [7:0] timer;
    reg [15:0] ndiv;
    reg [7:0] ntimer;
    reg increment;
    reg overflow;

    // Assign output values
    assign overflow_int = overflow;
    assign dtimer = timer;

    // Calculate new divider value and increment
    always @(*) begin
        ndiv = tdiv + 1'b1;
        
        case (tac[1:0])
            2'b01: increment = !ndiv[3] && tdiv[3];
            2'b10: increment = !ndiv[5] && tdiv[5];
            2'b11: increment = !ndiv[7] && tdiv[7];
            default: increment = !ndiv[9] && tdiv[9];
        endcase
        
        if (tac[2] && increment) begin
            if (timer + 1'b1 > 8'hff) begin
                overflow = 1'b1;
                ntimer = tma;
            end else begin
                overflow = 1'b0;
                ntimer = timer + 1'b1;
            end
        end else begin
            overflow = 1'b0;
            ntimer = timer;
        end
    end

    // Timer control logic
    always @(posedge clockgb or negedge resetn) begin
        if (!resetn) begin
            // Reset state
            timer <= 0;
            tdiv <= 0;
            tma <= 0;
            tac <= 0;
        end else begin
            // Update timer and divider
            tdiv <= ndiv;
            timer <= ntimer;
    
            // Handle memory-mapped register updates
            if (timer_store) begin
                timer <= timer_indata;
            end
            if (tdiv_store) begin
                tdiv <= 0;
            end
            if (tma_store) begin
                tma <= tma_indata;
            end
            if (tac_store) begin
                tac <= tac_indata;
            end
        end
    end

    // Memory-mapped register instances
    wire [7:0] tdiv_data;
    wire tdiv_store;
    
    rrmmap #(16'hff04) tdiv_mmap (
        .clock(clockgb),
        .resetn(resetn),
        .address(address),
        .indata(indata),
        .data_out(tdiv_data),
        .load(load),
        .store(store),
        .data_in(tdiv[15:8]),
        .store_signal(tdiv_store)
    );

    wire [7:0] timer_indata;
    wire [7:0] timer_data;
    wire timer_store;
    
    rrmmap #(16'hff05) timer_mmap (
        .clock(clockgb),
        .resetn(resetn),
        .address(address),
        .indata(indata),
        .data_out(timer_data),
        .load(load),
        .store(store),
        .data_in(timer_indata),
        .data_out(timer),
        .store_signal(timer_store)
    );

    wire [7:0] tma_indata;
    wire [7:0] tma_data;
    wire tma_store;
    
    rrmmap #(16'hff06) tma_mmap (
        .clock(clockgb),
        .resetn(resetn),
        .address(address),
        .indata(indata),
        .data_out(tma_data),
        .load(load),
        .store(store),
        .data_in(tma_indata),
        .data_out(tma),
        .store_signal(tma_store)
    );

    wire [7:0] tac_indata;
    wire [7:0] tac_data;
    wire tac_store;
    
    rrmmap #(16'hff07) tac_mmap (
        .clock(clockgb),
        .resetn(resetn),
        .address(address),
        .indata(indata),
        .data_out(tac_data),
        .load(load),
        .store(store),
        .data_in(tac_indata),
        .data_out(tac),
        .store_signal(tac_store)
    );

    // Combine output data from memory-mapped registers
    assign outdata = tdiv_data | timer_data | tma_data | tac_data;

endmodule
