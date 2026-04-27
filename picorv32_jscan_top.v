module picorv32_jscan_top (

    // Functional ports (normal operation)
    
    input  wire        clk,
    input  wire        resetn,
    
    // Memory Interface
    output wire        mem_valid,
    output wire        mem_instr,
    input  wire        mem_ready,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [ 3:0] mem_wstrb,
    input  wire [31:0] mem_rdata,
    
    // Status
    output wire        trap,
    

    // Joint-Scan DFT test ports

    // Test control (2-state controller: Qt/Qf)
    input  wire        test_mode,      // 1 = Qt (load), 0 = Qf (capture)
    
    // P-serial (MSS - Multiple Scan Chains) ports
    input  wire        scan_clk,       // Serial scan clock (SCK)
    input  wire [3:0]  scan_in,        // 4 scan-in pins (adjust K as needed)
    output wire        scan_out,       // Scan-out to MISR
    
    // P-random (PRAS - Progressive Random Access Scan) ports
    input  wire [7:0]  col_addr,       // Column address (log2(C) bits)
    inout  wire        scan_io,        // Bidirectional test data
    
    // MISR signature output
    output wire [31:0] misr_signature  // Compacted test response
);

   
    // Parameters for Joint-Scan configuration
    parameter K = 4;          // Number of scan-in pins for P-serial
    parameter MAX_CHAIN = 512; // Max length of each serial scan chain
    parameter C = 256;        // Number of columns in P-random grid
    parameter R = 64;         // Number of rows in P-random grid
    
        // Internal signals
    wire        sse_net;           // Serial Scan Enable (to P-serial FFs)
    wire        row_shift_en;      // Row enable shift register clock
    wire        col_drive_en;      // Column driver enable
    wire [R-1:0] row_enable;       // Row enable lines (one-hot)
    wire [C-1:0] col_select;       // Column select lines (decoded)
    
    // 1. PicoRV32 Core Instance
    picorv32 #(
        // Configure PicoRV32 for Joint-Scan study
        .ENABLE_COUNTERS(1),
        .ENABLE_COUNTERS64(1),
        .ENABLE_REGS_DUALPORT(1),
        .TWO_STAGE_SHIFT(1),
        .BARREL_SHIFTER(1),
        .TWO_CYCLE_COMPARE(0),
        .TWO_CYCLE_ALU(0),
        .COMPRESSED_ISA(1),
        .CATCH_MISALIGN(1),
        .CATCH_ILLINSN(1),
        .ENABLE_MUL(0),          
        .ENABLE_DIV(0),          
        .ENABLE_IRQ(0),
        .ENABLE_IRQ_QREGS(0)
    ) u_core (
        .clk       (clk),
        .resetn    (resetn),
        .trap      (trap),
        .mem_valid (mem_valid),
        .mem_instr (mem_instr),
        .mem_ready (mem_ready),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_rdata (mem_rdata),
        .irq       (32'b0)        // IRQ disabled
    );
    

    // 2. Test Control Logic (TCL) - 2-state FSM

    // Implements the Qt/Qf state machine from the paper
    // Qt (test_mode=1): Load test pattern (P-serial shifts, P-random writes)
    // Qf (test_mode=0): Functional mode, capture response
    
    test_ctrl_2state u_tcl (
        .clk            (clk),
        .rst            (~resetn),
        .test_mode      (test_mode),
        
        // Outputs to P-serial
        .SSE            (sse_net),
        
        // Outputs to P-random
        .row_shift_en   (row_shift_en),
        .col_drive_en   (col_drive_en)
    );
  
    // 3. P-random (PRAS) Subsystem
    // This block will be added AFTER you run your PRAS compiler
    // The PRAS compiler will generate:
    //   - Row enable shift register
    //   - Column address decoder
    //   - PRAS scan cells for R-cluster FFs
    //   - MISR for response compaction
    
    // PLACEHOLDER: Uncomment after PRAS compilation
    /*
    pras_subsystem #(
        .NUM_ROWS(R),
        .NUM_COLS(C)
    ) u_pras (
        .clk          (clk),
        .rst          (~resetn),
        .row_shift_en (row_shift_en),
        .col_addr     (col_addr),
        .col_drive_en (col_drive_en),
        .scan_io      (scan_io),
        .row_enable   (row_enable),
        .col_select   (col_select),
        .misr_out     (misr_signature)
    );
    */
    
    // Temporary tie-off until PRAS subsystem is added
    assign misr_signature = 32'h0;
    
    
    // 4. P-serial scan chains (to be inserted by Modus)
    // Modus will automatically stitch S-cluster FFs into K parallel chains
    // - scan_in[K-1:0] will feed the K chain heads
    // - scan_out will collect from the K chain tails (via OR tree to MISR)
    // - SSE will control shift enable for all P-serial chains
    
    // No explicit instantiation needed here - Modus handles this via:
    //   define_dft scan_chain -sdi scan_in -sdo scan_out -shift_enable SSE
    
    // Test pin count summary
    // Total test pins I = K + log2(C) + 3
    // For K=4, C=256 (8 bits):
    //   4 (scan_in) + 8 (col_addr) + 1 (test_mode) + 1 (scan_clk) + 1 (scan_io)
    //   = 15 test pins total
    //
    // Compare to:
    // - Pure MSS (all FFs in serial chains): ~1500 FFs / 512 = 3 chains
    //   → 3 scan_in + 1 scan_out + 1 SE + 1 clk = 6 pins (but longer test time)
    // - Pure PRAS (all FFs in random grid): ~40×40 grid
    //   → 6 col_addr + 6 row_addr + control pins = 15+ pins (but high routing)
    // 
    // Joint-Scan balances pin count, test time, and routing congestion

endmodule



// Test Control Logic - 2-State FSM (Qt/Qf)
// This is the simple controller from the paper's Fig. 3
// Only 2 states instead of the 4 states needed for separate MSS/PRAS
// Pattern alignment ensures both P-serial and P-random finish together

module test_ctrl_2state (
    input  wire clk,
    input  wire rst,
    input  wire test_mode,      // External test mode pin
    
    // Outputs to P-serial subsystem
    output reg  SSE,            // Serial Scan Enable
    
    // Outputs to P-random subsystem
    output reg  row_shift_en,   // Enable row shift register
    output reg  col_drive_en    // Enable column drivers
);

    // State encoding (only 2 states needed!)
    localparam QT = 1'b1;  // Test mode: load pattern
    localparam QF = 1'b0;  // Functional mode: capture response
    
    reg state;
    
    // State machine
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= QF;  // Start in functional mode
        else
            state <= test_mode ? QT : QF;
    end
    
    // Output logic
    always @(*) begin
        case (state)
            QT: begin
                // Qt state: loading test pattern
                SSE          = 1'b1;  // Enable P-serial shifting
                row_shift_en = 1'b1;  // Enable P-random row shift
                col_drive_en = 1'b1;  // Enable P-random column decode
            end
            
            QF: begin
                // Qf state: functional mode / capture
                SSE          = 1'b0;  // Disable shifting
                row_shift_en = 1'b0;
                col_drive_en = 1'b0;
            end
            
            default: begin
                SSE          = 1'b0;
                row_shift_en = 1'b0;
                col_drive_en = 1'b0;
            end
        endcase
    end

endmodule
