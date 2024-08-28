module z80(
    input clock,
    input resetn,
    output reg [15:0] address,
    input [7:0] indata,
    output reg [7:0] outdata,
    output reg load,
    output reg store,
    input intreq,
    input [15:0] intaddress,
    output reg intack,
    output [15:0] du,
    output [3:0] df,
    output [15:0] daf,
    output [15:0] dbc,
    output [15:0] dde,
    output [15:0] dhl,
    output [15:0] dsp,
    output [15:0] dpc
);

    // Internal signals and registers
    reg [15:0] u;
    reg [7:0] a, b, c, d, e, h, l;
    reg [3:0] f;
    reg [15:0] sp, pc, temp;
    reg ie;
    wire [15:0] bus_a, bus_b, bus_d;
    wire [3:0] nf;

    // Outputs
    assign du = u;
    assign df = f;
    assign daf = {a, f, 4'h0};
    assign dbc = {b, c};
    assign dde = {d, e};
    assign dhl = {h, l};
    assign dsp = sp;
    assign dpc = pc;


    // Microcode Unit
    wire [15:0] uc_u;
    wire [4:0] uc_d, uc_op, uc_a, uc_b, uc_cc;
    z80_ucode uc(.u(u), .clock(clock), .resetn(resetn), 
                  .uc_u(uc_u), .uc_d(uc_d), .uc_op(uc_op), 
                  .uc_a(uc_a), .uc_b(uc_b), .load(load), 
                  .store(store), .uc_cc(uc_cc));

    // Update `u` and `intack` signals
    always @(*) begin
        if (intreq && ie && (uc_u[7:0] == 8'h00 || uc_u[7:0] == 8'h70)) begin
            u = 16'h0050;
        end else if (uc_d == D_UC) begin
            u = {bus_d[7:0], bus_d[15:8]};
        end else begin
            u = uc_u;
        end
        intack = (uc_d == D_IACK);
    end

    // ALU and Register definitions
    z80_alu alu(.bus_d(bus_d), .uc_op(uc_op), .bus_a(bus_a), .bus_b(bus_b), .f(f), .nf(nf));

    // Continuous assignments for bus_a
    assign bus_a = (uc_a == A_0)     ? 16'h0 :
                   (uc_a == A_1)     ? 16'h1 :
                   (uc_a == A_8)     ? 16'h08 :
                   (uc_a == A_10)    ? 16'h10 :
                   (uc_a == A_18)    ? 16'h18 :
                   (uc_a == A_20)    ? 16'h20 :
                   (uc_a == A_28)    ? 16'h28 :
                   (uc_a == A_30)    ? 16'h30 :
                   (uc_a == A_38)    ? 16'h38 :
                   (uc_a == A_PC)    ? pc :
                   (uc_a == A_UC)    ? {uc_u[7:0], uc_u[15:8]} :
                   (uc_a == A_D16)   ? {indata, temp[7:0]} :
                   (uc_a == A_D8)    ? {{8{indata[7]}}, indata} :
                   (uc_a == A_A)     ? {{8{a[7]}}, a} :
                   (uc_a == A_B)     ? {{8{b[7]}}, b} :
                   (uc_a == A_C)     ? {{8{c[7]}}, c} :
                   (uc_a == A_D)     ? {{8{d[7]}}, d} :
                   (uc_a == A_E)     ? {{8{e[7]}}, e} :
                   (uc_a == A_H)     ? {{8{h[7]}}, h} :
                   (uc_a == A_L)     ? {{8{l[7]}}, l} :
                   (uc_a == A_AF)    ? {a, f, 4'h0} :
                   (uc_a == A_BC)    ? {b, c} :
                   (uc_a == A_DE)    ? {d, e} :
                   (uc_a == A_HL)    ? {h, l} :
                   (uc_a == A_SP)    ? sp :
                   (uc_a == A_IADDR) ? intaddress :
                   (uc_a == A_TEMP)  ? temp :
                   (uc_a == A_MASK)  ? 16'hff00 :
                   16'h0000;

    // Continuous assignments for bus_b
    assign bus_b = (uc_b == B_0)     ? 16'h0 :
                   (uc_b == B_1)     ? 16'h1 :
                   (uc_b == B_2)     ? 16'h02 :
                   (uc_b == B_4)     ? 16'h04 :
                   (uc_b == B_8)     ? 16'h08 :
                   (uc_b == B_10)    ? 16'h10 :
                   (uc_b == B_20)    ? 16'h20 :
                   (uc_b == B_40)    ? 16'h40 :
                   (uc_b == B_80)    ? 16'h80 :
                   (uc_b == B_fe)    ? 16'hfe :
                   (uc_b == B_fd)    ? 16'hfd :
                   (uc_b == B_fb)    ? 16'hfb :
                   (uc_b == B_f7)    ? 16'hf7 :
                   (uc_b == B_ef)    ? 16'hef :
                   (uc_b == B_df)    ? 16'hdf :
                   (uc_b == B_bf)    ? 16'hbf :
                   (uc_b == B_7f)    ? 16'h7f :
                   (uc_b == B_D8)    ? {{8{indata[7]}}, indata} :
                   (uc_b == B_A)     ? {{8{a[7]}}, a} :
                   (uc_b == B_F)     ? {8'h00, f, 4'h0} :
                   (uc_b == B_B)     ? {{8{b[7]}}, b} :
                   (uc_b == B_C)     ? {{8{c[7]}}, c} :
                   (uc_b == B_D)     ? {{8{d[7]}}, d} :
                   (uc_b == B_E)     ? {{8{e[7]}}, e} :
                   (uc_b == B_H)     ? {{8{h[7]}}, h} :
                   (uc_b == B_L)     ? {{8{l[7]}}, l} :
                   (uc_b == B_BC)    ? {b, c} :
                   (uc_b == B_DE)    ? {d, e} :
                   (uc_b == B_HL)    ? {h, l} :
                   (uc_b == B_SP)    ? sp :
                   (uc_b == B_IE)    ? ie :
                   16'h0000;

    // Sequential logic
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            pc <= 16'h0000;
            sp <= 16'hfffe;
            a <= 8'h01; // 8'h11 for gbc
            f <= 4'hb;
            b <= 8'h00;
            c <= 8'h13;
            d <= 8'h00;
            e <= 8'hd8;
            h <= 8'h01;
            l <= 8'h4d;
            ie <= 0;
        end else begin
            case (uc_d)
            D_PC:   pc      <= bus_d;
            D_DATA: outdata <= bus_d[7:0];
            D_A:    a       <= bus_d[7:0];
            D_B:    b       <= bus_d[7:0];
            D_C:    c       <= bus_d[7:0];
            D_D:    d       <= bus_d[7:0];
            D_E:    e       <= bus_d[7:0];
            D_H:    h       <= bus_d[7:0];
            D_L:    l       <= bus_d[7:0];
            D_AF:   begin a <= bus_d[15:8]; f <= bus_d[7:4]; end
            D_BC:   begin b <= bus_d[15:8]; c <= bus_d[7:0]; end
            D_DE:   begin d <= bus_d[15:8]; e <= bus_d[7:0]; end
            D_HL:   begin h <= bus_d[15:8]; l <= bus_d[7:0]; end
            D_SP:   sp      <= bus_d;
            D_IE:   ie      <= bus_d[0];
            D_TEMP: temp    <= bus_d;
            endcase
        
            case (uc_cc)
            CC_Z0Hx: begin f[3] <= nf[3]; f[2] <= 1'b0; f[1] <= nf[1];                end
            CC_Z1Hx: begin f[3] <= nf[3]; f[2] <= 1'b1; f[1] <= nf[1];                end
            CC_000C: begin f[3] <= 1'b0;  f[2] <= 1'b0; f[1] <= 1'b0;  f[0] <= nf[0]; end
            CC_x0HC: begin                f[2] <= 1'b0; f[1] <= nf[1]; f[0] <= nf[0]; end
            CC_Zx0C: begin f[3] <= nf[3];               f[1] <= 1'b0;  f[0] <= nf[0]; end
            CC_x11x: begin                f[2] <= 1'b1; f[1] <= 1'b1;                 end
            CC_x001: begin                f[2] <= 1'b0; f[1] <= 1'b0;  f[0] <= 1'b1;  end
            CC_Z0HC: begin f[3] <= nf[3]; f[2] <= 1'b0; f[1] <= nf[1]; f[0] <= nf[0]; end
            CC_x00x: begin                f[2] <= 1'b0; f[1] <= 1'b0;                 end
            CC_Z1HC: begin f[3] <= nf[3]; f[2] <= 1'b1; f[1] <= nf[1]; f[0] <= nf[0]; end
            CC_Z010: begin f[3] <= nf[3]; f[2] <= 1'b0; f[1] <= 1'b1;  f[0] <= 1'b0;  end
            CC_Z000: begin f[3] <= nf[3]; f[2] <= 1'b0; f[1] <= 1'b0;  f[0] <= 1'b0;  end
            CC_00HC: begin f[3] <= 1'b0;  f[2] <= 1'b0; f[1] <= nf[1]; f[0] <= nf[0]; end
            CC_Z00C: begin f[3] <= nf[3]; f[2] <= 1'b0; f[1] <= 1'b0;  f[0] <= nf[0]; end
            CC_Z01x: begin f[3] <= nf[3]; f[2] <= 1'b0; f[1] <= 1'b1;                 end
            endcase
        end
    end




    parameter D_0       = 5'h00;
    parameter D_PC      = 5'h01;
    parameter D_UC      = 5'h02;
    parameter D_A       = 5'h03;
    parameter D_B       = 5'h04;
    parameter D_C       = 5'h05;
    parameter D_D       = 5'h06;
    parameter D_E       = 5'h07;
    parameter D_H       = 5'h08;
    parameter D_L       = 5'h09;
    parameter D_AF      = 5'h0a;
    parameter D_BC      = 5'h0b;
    parameter D_DE      = 5'h0c;
    parameter D_HL      = 5'h0d;
    parameter D_SP      = 5'h0e;
    parameter D_IE      = 5'h0f;
    parameter D_IACK    = 5'h10;
    parameter D_TEMP    = 5'h11;
    parameter D_DATA    = 5'h12;

    parameter A_0       = 5'h00;
    parameter A_1       = 5'h01;
    parameter A_8       = 5'h02;
    parameter A_10      = 5'h03;
    parameter A_18      = 5'h04;
    parameter A_20      = 5'h05;
    parameter A_28      = 5'h06;
    parameter A_30      = 5'h07;
    parameter A_38      = 5'h08;
    parameter A_PC      = 5'h09;
    parameter A_UC      = 5'h0a;
    parameter A_D16     = 5'h0b;
    parameter A_D8      = 5'h0c;
    parameter A_A       = 5'h0d;
    parameter A_B       = 5'h0e;
    parameter A_C       = 5'h0f;
    parameter A_D       = 5'h10;
    parameter A_E       = 5'h11;
    parameter A_H       = 5'h12;
    parameter A_L       = 5'h13;
    parameter A_AF      = 5'h14;
    parameter A_BC      = 5'h15;
    parameter A_DE      = 5'h16;
    parameter A_HL      = 5'h17;
    parameter A_SP      = 5'h18;
    parameter A_IADDR   = 5'h19;
    parameter A_TEMP    = 5'h1a;
    parameter A_MASK    = 5'h1b;

    parameter B_0       = 5'h00;
    parameter B_1       = 5'h01;
    parameter B_2       = 5'h02;
    parameter B_4       = 5'h03;
    parameter B_8       = 5'h04;
    parameter B_10      = 5'h05;
    parameter B_20      = 5'h06;
    parameter B_40      = 5'h07;
    parameter B_80      = 5'h08;
    parameter B_fe      = 5'h09;
    parameter B_fd      = 5'h0a;
    parameter B_fb      = 5'h0b;
    parameter B_f7      = 5'h0c;
    parameter B_ef      = 5'h0d;
    parameter B_df      = 5'h0e;
    parameter B_bf      = 5'h0f;
    parameter B_7f      = 5'h10;
    parameter B_D8      = 5'h11;
    parameter B_A       = 5'h12;
    parameter B_F       = 5'h13;
    parameter B_B       = 5'h14;
    parameter B_C       = 5'h15;
    parameter B_D       = 5'h16;
    parameter B_E       = 5'h17;
    parameter B_H       = 5'h18;
    parameter B_L       = 5'h19;
    parameter B_BC      = 5'h1a;
    parameter B_DE      = 5'h1b;
    parameter B_HL      = 5'h1c;
    parameter B_SP      = 5'h1d;
    parameter B_IE      = 5'h1e;

    parameter CC_xxxx   = 5'h00;
    parameter CC_Z0Hx   = 5'h01;
    parameter CC_Z1Hx   = 5'h02;
    parameter CC_000C   = 5'h03;
    parameter CC_x0HC   = 5'h04;
    parameter CC_Zx0C   = 5'h05;
    parameter CC_x11x   = 5'h06;
    parameter CC_x001   = 5'h07;
    parameter CC_Z0HC   = 5'h08;
    parameter CC_x00x   = 5'h09;
    parameter CC_Z1HC   = 5'h0a;
    parameter CC_Z010   = 5'h0b;
    parameter CC_Z000   = 5'h0c;
    parameter CC_00HC   = 5'h0d;
    parameter CC_ZNHC   = 5'h0e;
    parameter CC_Z00C   = 5'h0f;
    parameter CC_Z01x   = 5'h10;

endmodule
