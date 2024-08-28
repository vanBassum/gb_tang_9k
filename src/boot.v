module boot (
    input clockgb,
    input resetn,

    input [15:0] address,
    input [7:0] indata,
    output [7:0] outdata,
    input load,
    input store,

    output boot_active
);

assign boot_active = boot_load[1];

wire [15:0] boot_address;
wire [7:0] boot_outdata;
wire boot_preload;

bootrom bootrom (
    .ad(boot_address[7:0]),
    //.clockgb(clockgb),
    .dout(boot_outdata)
);


mmap #(16'h0000, 16'h00ff) rom_mmap (
    .clock         (clockgb     ),
    .resetn        (resetn      ),
    .m_address     (address     ),
    .m_indata      (indata      ),
    .m_outdata     (outdata     ),
    .m_load        (load        ),
    .m_store       (store       ),
    .address       (boot_address),
    .outdata       (boot_outdata),
    .load          (boot_preload)
);

reg boot_enabled;
reg boot_load [1:0];

always @(posedge clockgb or negedge resetn) begin
    if (!resetn) begin
        boot_enabled <= 1'b1;
        boot_load[0] <= 0;
        boot_load[1] <= 0;
    end else begin
        boot_load[0] <= boot_enabled && boot_preload;
        boot_load[1] <= boot_load[0];
        
        if (disable_store) begin
            boot_enabled <= 1'b0;
        end
    end
end

wire disable_store;

rrmmap #(16'hff50) disable_mmap (
    .clock        (clockgb      ),
    .resetn       (resetn       ),
    .m_address    (address      ),
    .m_indata     (indata       ),
    .m_load       (load         ),
    .m_store      (store        ),
    .store        (disable_store )
);

endmodule
