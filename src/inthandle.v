module inthandle (
    input clockgb,
    input resetn,
    input [15:0] address,
    input [7:0] indata,
    output [7:0] outdata,
    input load,
    input store,
    input [4:0] interrupts,
    output reg intreq,
    output reg [15:0] intaddress,
    input intack,
    output [4:0] dints
);

assign dints = intf;

reg [2:0] intnum;

reg [4:0] intf;
reg [4:0] inte;

integer i1;
always @(*) begin
    
    
    intreq = 1'b0;
    intnum = 3'b0;
    
    for (i1 = 4; i1 >= 0; i1 = i1 - 1) begin
        if (intf[i1] && inte[i1]) begin
            intreq = 1'b1;
            intnum = i1[2:0];
        end
    end
    
    case (intnum)
        3'd0: intaddress = 16'h40;
        3'd1: intaddress = 16'h48;
        3'd2: intaddress = 16'h50;
        3'd3: intaddress = 16'h58;
        3'd4: intaddress = 16'h60;
        default: intaddress = 16'h00;
    endcase
end

integer i2;
always @(posedge clockgb or negedge resetn) begin
    if (!resetn) begin
        intf <= 5'b0;
        inte <= 5'b0;
    end else begin
        for (i2 = 0; i2 < 5; i2 = i2 + 1) begin
            if (interrupts[i2]) begin
                intf[i2] <= 1'b1;
            end else if (intreq && intack && i2 == intnum) begin
                intf[i2] <= 1'b0;
            end
        end
    
        if (intf_store) begin
            intf <= intf_indata;
        end
        if (inte_store) begin
            inte <= inte_indata;
        end
    end
end

wire [4:0] intf_indata;
wire [7:0] intf_data;
wire intf_store;

rrmmap #(16'hff0f) intf_mmap (
    .clockgb(clockgb),
    .resetn(resetn),
    .address(address),
    .indata(indata),
    .outdata(intf_data),
    .load(load),
    .store(store),
    .intf_indata(intf_indata),
    .intf(intf),
    .intf_store(intf_store)
);

wire [4:0] inte_indata;
wire [7:0] inte_data;
wire inte_store;

rrmmap #(16'hffff) inte_mmap (
    .clockgb(clockgb),
    .resetn(resetn),
    .address(address),
    .indata(indata),
    .outdata(inte_data),
    .load(load),
    .store(store),
    .inte_indata(inte_indata),
    .inte(inte),
    .inte_store(inte_store)
);

assign outdata = intf_data | inte_data;

endmodule
