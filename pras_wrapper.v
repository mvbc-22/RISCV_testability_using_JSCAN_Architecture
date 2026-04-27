
// PRAS Wrapper for PicoRV32


module pras_wrapper (
    // PRAS Control Signals
    input  wire [5:0]  col_addr,        // Column address (0-53)
    input  wire        pras_data_in,    // Serial data input
    output wire        pras_data_out,   // Serial data output
    input  wire        pras_enable,     // PRAS mode enable
    input  wire        pras_clk,        // PRAS shift clock
    input  wire        capture_enable,  // Capture functional data
    
    // Original PicoRV32 Functional Signals
    input  wire        clk,
    input  wire        resetn,
    output wire        trap,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [ 3:0] mem_wstrb,
    input  wire [31:0] mem_rdata,
    output wire        mem_valid,
    input  wire        mem_ready,
    
    // IRQ signals
    input  wire [31:0] irq,
    output wire [31:0] eoi,
    
    // Trace signals
    output wire        trace_valid,
    output wire [35:0] trace_data,
    
    // Memory look-ahead interface
    output wire        mem_la_read,
    output wire        mem_la_write,
    output wire [31:0] mem_la_addr,
    output wire [31:0] mem_la_wdata,
    output wire [ 3:0] mem_la_wstrb,
    
    // PCpi interface
    output wire        pcpi_valid,
    output wire [31:0] pcpi_insn,
    output wire [31:0] pcpi_rs1,
    output wire [31:0] pcpi_rs2,
    input  wire        pcpi_wr,
    input  wire [31:0] pcpi_rd,
    input  wire        pcpi_wait,
    input  wire        pcpi_ready
);

// Instantiate Original PicoRV32 Core


picorv32 #(
    .ENABLE_COUNTERS(1),
    .ENABLE_COUNTERS64(1),
    .ENABLE_REGS_16_31(1),
    .ENABLE_REGS_DUALPORT(1),
    .LATCHED_MEM_RDATA(0),
    .TWO_STAGE_SHIFT(1),
    .BARREL_SHIFTER(0),
    .TWO_CYCLE_COMPARE(0),
    .TWO_CYCLE_ALU(0),
    .COMPRESSED_ISA(0),
    .CATCH_MISALIGN(1),
    .CATCH_ILLINSN(1),
    .ENABLE_PCPI(0),
    .ENABLE_MUL(0),
    .ENABLE_FAST_MUL(0),
    .ENABLE_DIV(0),
    .ENABLE_IRQ(0),
    .ENABLE_IRQ_QREGS(1),
    .ENABLE_IRQ_TIMER(1),
    .ENABLE_TRACE(0),
    .REGS_INIT_ZERO(0),
    .MASKED_IRQ(32'h00000000),
    .LATCHED_IRQ(32'hffffffff),
    .PROGADDR_RESET(32'h00000000),
    .PROGADDR_IRQ(32'h00000010),
    .STACKADDR(32'hffffffff)
) picorv32_core (
    .clk(clk),
    .resetn(resetn),
    .trap(trap),
    .mem_valid(mem_valid),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_wstrb(mem_wstrb),
    .mem_rdata(mem_rdata),
    .mem_ready(mem_ready),
    .mem_la_read(mem_la_read),
    .mem_la_write(mem_la_write),
    .mem_la_addr(mem_la_addr),
    .mem_la_wdata(mem_la_wdata),
    .mem_la_wstrb(mem_la_wstrb),
    .pcpi_valid(pcpi_valid),
    .pcpi_insn(pcpi_insn),
    .pcpi_rs1(pcpi_rs1),
    .pcpi_rs2(pcpi_rs2),
    .pcpi_wr(pcpi_wr),
    .pcpi_rd(pcpi_rd),
    .pcpi_wait(pcpi_wait),
    .pcpi_ready(pcpi_ready),
    .irq(irq),
    .eoi(eoi),
    .trace_valid(trace_valid),
    .trace_data(trace_data)
);
// PRAS Grid Organization
// 
// We'll intercept all flip-flops in the design and organize them into
// a 38×54 grid structure for random access.
//
// Note: This is a conceptual structure. In actual implementation, the
// PRAS logic would be inserted during synthesis by:
// 1. Identifying all flip-flops (using get_cells in synthesis)
// 2. Replacing them with PRAS-enabled scan flip-flops
// 3. Connecting them according to row/column organization
// PRAS Address Decoder


wire [53:0] col_select;  // One-hot column select (54 columns)

pras_decoder #(
    .ADDR_WIDTH(6),
    .NUM_COLS(54)
) decoder (
    .addr(col_addr),
    .enable(pras_enable),
    .col_select(col_select)
);


// PRAS Column Multiplexer


// These signals will connect to actual scan flip-flops after synthesis
wire [37:0] col_scan_out [0:53];  // Scan output from each column
reg  [37:0] col_scan_in  [0:53];  // Scan input to each column

// Column multiplexer for scan output
wire [37:0] selected_col_out;
assign selected_col_out = col_scan_out[col_addr];

// Scan chain within selected column (38 FFs)
assign pras_data_out = selected_col_out[37];  // MSB of selected column

// Distribute scan input to selected column
integer i;
always @(*) begin
    for (i = 0; i < 54; i = i + 1) begin
        if (col_select[i]) begin
            col_scan_in[i] = {selected_col_out[36:0], pras_data_in};
        end else begin
            col_scan_in[i] = col_scan_out[i];  // Hold current value
        end
    end
end


endmodule


// PRAS Address Decoder Module


module pras_decoder #(
    parameter ADDR_WIDTH = 6,
    parameter NUM_COLS = 54
) (
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire                  enable,
    output wire [NUM_COLS-1:0]   col_select
);

// One-hot decode
wire [63:0] decode_full;

genvar i;
generate
    for (i = 0; i < 64; i = i + 1) begin : decoder_gen
        assign decode_full[i] = enable && (addr == i);
    end
endgenerate

// Only use first NUM_COLS outputs
assign col_select = decode_full[NUM_COLS-1:0];

endmodule





module pras_scan_ff (
    input  wire clk,           // Functional clock
    input  wire pras_clk,      // PRAS shift clock
    input  wire resetn,        // Reset
    input  wire d,             // Functional data input
    input  wire si,            // Scan data input
    input  wire pras_enable,   // PRAS mode enable
    input  wire col_select,    // Column select
    input  wire capture_en,    // Capture enable
    output reg  q,             // Functional data output
    output wire so             // Scan data output
);

// Scan output is just the FF output
assign so = q;

// FF behavior
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        q <= 1'b0;
    end else begin
        if (pras_enable && col_select) begin
            // PRAS mode: shift on pras_clk when column is selected
            q <= si;
        end else if (!pras_enable && capture_en) begin
            // Functional mode: capture normal data
            q <= d;
        end
        // else: hold current value
    end
end

endmodule
