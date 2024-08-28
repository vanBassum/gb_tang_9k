
module top (
    //////////// CLOCK //////////
    input            CLOCK_125_p     ,
    input            CLOCK_50_B5B    ,
    input            CLOCK_50_B6A    ,
    input            CLOCK_50_B7A    ,
    input            CLOCK_50_B8A    ,

    //////////// LED //////////
    output   [7:0]   LEDG            ,
    output   [9:0]   LEDR            ,

    //////////// KEY //////////
    input            CPU_RESET_n     ,
    input    [3:0]   KEY             ,

    //////////// SW //////////
    input    [9:0]   SW              ,

    //////////// SEG7 //////////
    output   [6:0]   HEX0            ,
    output   [6:0]   HEX1            ,
    output   [6:0]   HEX2            ,
    output   [6:0]   HEX3            ,

    //////////// HDMI-TX //////////
    output           HDMI_TX_CLK     ,
    output   [23:0]  HDMI_TX_D       ,
    output           HDMI_TX_DE      ,
    output           HDMI_TX_HS      ,
    input            HDMI_TX_INT     ,
    output           HDMI_TX_VS      ,

    //////////// Audio //////////
    input            AUD_ADCDAT      ,
    inout            AUD_ADCLRCK     ,
    inout            AUD_BCLK        ,
    output           AUD_DACDAT      ,
    inout            AUD_DACLRCK     ,
    output           AUD_XCK         ,

    //////////// I2C for Audio/HDMI-TX/Si5338/HSMC //////////
    output           I2C_SCL         ,
    inout            I2C_SDA         ,

    //////////// Uart to USB //////////
    input            UART_RX         ,
    output           UART_TX         ,

    //////////// SRAM //////////
    output   [17:0]  SRAM_A          ,
    output           SRAM_CE_n       ,
    inout    [15:0]  SRAM_D          ,
    output           SRAM_LB_n       ,
    output           SRAM_OE_n       ,
    output           SRAM_UB_n       ,
    output           SRAM_WE_n       
);






// Clocking //
wire clock50mhz = CLOCK_50_B5B;

wire clock25mhz;
wire clock12500khz;
wire clock8mhz;
wire clock4mhz;
wire clock1mhz;
wire clock250khz;
wire clock62500hz;
wire clock115200hz;
wire clock460800hz;

div #(2) div25mhz(clock50mhz, clock25mhz);
div #(4) div12500khz(clock50mhz, clock12500khz);
div #(6) div8mhz(clock50mhz, clock8mhz);
div #(12) div4mhz(clock50mhz, clock4mhz);
div #(434) div115200hz(clock50mhz, clock115200hz); // previously 434
div #(434/4) div460800hz(clock50mhz, clock460800hz);

div #(4) div1mhz(clock4mhz, clock1mhz);
div #(4) div250khz(clock1mhz, clock250khz);
div #(4) div62500hz(clock250khz, clock62500hz);

wire clockgb = SW[8] ? clock8mhz :
               SW[7] ? clock4mhz : 
               SW[6] ? clock1mhz : 
               SW[5] ? clock250khz : 
               SW[4] ? clock62500hz : KEY[3];
            
wire hard_resetn = KEY[1];
wire resetn = KEY[1] & KEY[0];


// Connecting Wires //
reg [15:0] bus_address;
reg [7:0] bus_outdata;
reg bus_load;
reg bus_store;

wire [7:0] bus_data = ppu_data | link_data | timer_data | 
                      joy_data | dma_data | 
                      rom_data | loram_data;
                   
wire [7:0] cpu_data = hiram_data | int_data;


always @(*) begin
    if (!dma_active) begin
        bus_address = cpu_address;
        bus_outdata = cpu_outdata;
        bus_load = cpu_load;
        bus_store = cpu_store;
        
        if (boot_active) begin
            cpu_indata = boot_data;
        end else begin
            cpu_indata = cpu_data | bus_data;
        end
        dma_indata = 0;
    end else begin
        bus_address = dma_address;
        bus_outdata = dma_outdata;
        bus_load = dma_load;
        bus_store = dma_store;
    
        cpu_indata = cpu_data;
        dma_indata = bus_data;
    end
end


assign UART_TX = link_tx & rom_tx & joy_tx;


// Boot ROM //
wire [7:0] boot_data;
wire boot_active;

boot boot(
    clockgb, resetn,
    bus_address, bus_outdata, boot_data, bus_load, bus_store,
    boot_active
);


// APU //
wire [7:0] apu_data;

apu apu(
    clock25mhz, clock12500khz, clockgb, hard_resetn, resetn,
    bus_address, bus_outdata, apu_data, bus_load, bus_store,

    //////////// Audio //////////
	AUD_ADCDAT,
	AUD_ADCLRCK,
	AUD_BCLK,
	AUD_DACDAT,
	AUD_DACLRCK,
	AUD_XCK
);



// PPU //
wire [7:0] ppu_data;
wire vblank_int;
wire lcdc_int;
wire [1:0] dmode;

ppu ppu(
    clock25mhz, clockgb, hard_resetn, resetn, vblank_int, lcdc_int,
    bus_address, bus_outdata, ppu_data, bus_load, bus_store,
    
	//////////// HDMI-TX //////////
	HDMI_TX_CLK,
	HDMI_TX_D,
	HDMI_TX_DE,
	HDMI_TX_HS,
	HDMI_TX_INT,
	HDMI_TX_VS,
    dmode
);


// Link Cable (Primarily for debugging) //
wire [7:0] link_data;
wire link_tx;

link link(
    clock115200hz, clockgb, resetn,
    bus_address, bus_outdata, link_data, bus_load, bus_store,

    //////////// Uart to USB //////////
    UART_RX,
    link_tx
);


// Timer //
wire [7:0] timer_data;
wire timer_int;
wire [7:0] dtimer;

timer timer(
    clockgb, resetn, timer_int,
    bus_address, bus_outdata, timer_data, bus_load, bus_store,
    dtimer
);


// Joypad over UART //
wire [7:0] joy_data;
wire joy_tx;
wire joy_int;

joypad joypad(
    clock460800hz, clockgb, resetn, joy_int,
    bus_address, bus_outdata, joy_data, bus_load, bus_store,
    
    //////////// Uart to USB //////////
    UART_RX,
    joy_tx
);


// DMA //
wire [7:0] dma_data;

wire [15:0] dma_address;
wire [7:0] dma_outdata;
reg [7:0] dma_indata;
wire dma_load;
wire dma_store;
wire dma_active;

dma dma(
    clockgb, resetn,
    bus_address, bus_outdata, dma_data, bus_load, bus_store,
    dma_address, dma_indata, dma_outdata, dma_load, dma_store,
    dma_active
);


// Cartridge ROM //          
wire [7:0] rom_data;
wire rom_tx;

mbc1 mbc1(
    SW[9] ? clock4mhz : clockgb, clock115200hz, clock460800hz, resetn, 
    bus_address, bus_outdata, rom_data, bus_load, bus_store, SW[9],

    //////////// Uart to USB //////////
	UART_RX,
    rom_tx,
    
    //////////// SRAM //////////
	SRAM_A,
	SRAM_CE_n,
	SRAM_D,
	SRAM_LB_n,
	SRAM_OE_n,
	SRAM_UB_n,
	SRAM_WE_n
);


// Low RAM (Large) //
wire [15:0] loram_address;
wire [7:0] loram_indata;
wire [7:0] loram_outdata;
wire [7:0] loram_data;
wire loram_store;

loram loram(
	loram_address[12:0],
	clockgb,
	loram_indata,
	loram_store,
	loram_outdata
);

mmap #(16'hc000, 16'hfdff) loram_mmap(
    clockgb, resetn,
    bus_address, bus_outdata, loram_data, bus_load, bus_store,
    loram_address, loram_indata, loram_outdata,, loram_store
);


// High RAM (Small but faster) //
wire [15:0] hiram_address;
wire [7:0] hiram_indata;
wire [7:0] hiram_outdata;
wire [7:0] hiram_data;
wire hiram_store;

hiram hiram(
    hiram_address,
	clockgb,
	hiram_indata,
	hiram_store,
	hiram_outdata
);

mmap #(16'hff80, 16'hfffe) hiram_mmap(
    clockgb, resetn,
    cpu_address, cpu_outdata, hiram_data, cpu_load, cpu_store,
    hiram_address, hiram_indata, hiram_outdata,, hiram_store
);


// Interrupt Handling //
wire [7:0] int_data;
wire int_req;
wire [15:0] int_address;
wire int_ack;
wire [4:0] dints;

inthandle inth(
    clockgb, resetn,
    cpu_address, cpu_outdata, int_data, cpu_load, cpu_store,
    {joy_int, 1'b0, timer_int, lcdc_int, vblank_int},
    int_req, int_address, int_ack, 
    dints
);

  
// CPU //  
wire [15:0] cpu_address;
wire [7:0] cpu_outdata;
reg [7:0] cpu_indata;
wire cpu_load;
wire cpu_store;

wire [15:0] du;
wire [3:0] df;
wire [15:0] daf;
wire [15:0] dbc;
wire [15:0] dde;
wire [15:0] dhl;
wire [15:0] dsp;
wire [15:0] dpc;

z80 cpu(
    clockgb, resetn, 
    cpu_address, cpu_indata, cpu_outdata, cpu_load, cpu_store, 
    int_req, int_address, int_ack,
    du, df, daf, dbc, dde, dhl, dsp, dpc
);


// Debugging Signals //
assign LEDR[9:5] = dints;
assign LEDR[1:0] = dmode;
assign LEDG[7:4] = df;
assign LEDG[3] = dma_load;
assign LEDG[2] = dma_store;
assign LEDG[1] = cpu_load;
assign LEDG[0] = cpu_store;

reg [15:0] debug;
seg16 segs(debug, {HEX3,HEX2,HEX1,HEX0});

always @(*) begin
    case (SW[3:0])
    4'b1101: debug = dpc;
    4'b1100: debug = dsp;
    4'b1011: debug = dhl;
    4'b1010: debug = dde;
    4'b1001: debug = dbc;
    4'b1000: debug = daf;
    4'b0100: debug = dtimer;
    default: debug = du;
    endcase
end
 
endmodule
