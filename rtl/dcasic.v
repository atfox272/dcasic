// `define IMAGE_PROCESSOR_ENABLE
// `define SILICON_DEBUG
// `define OPENLANE_DEBUG
module dcasic #(
    parameter INTERNAL_CLK      = 50_000_000,
    // DVP Interface
    parameter DVP_DATA_W        = 8,
    // DBI Interface
    parameter DBI_IF_D_W        = 8,
    // Instruction Memory
    parameter BOOT_SIZE         = 32'd64,   // Bootloader program size:         max 32  instructions
    parameter MP_SIZE           = 32'd512,  // Main Program size:               max 512 instructions
    parameter ISR_SIZE          = 32'd32,   // Interrupt Service Routine size:  max 16  instructions   
    parameter BOOTLOADER_FILE   = "../../firmware/bootloader/bootloader.hex", // Bootloader file of the system
    // Image
    // -- Input frame (From the Camera)
    parameter I_FRM_COL_NUM     = 640,  // Input frame from camera: Number of columns
    parameter I_FRM_ROW_NUM     = 480,  // Input frame from camera: Number of rows
    // -- Input pixel
    parameter I_PXL_FORMAT      = "RGB", // "RGB": RGB565 || "GRAY": Grayscale
    // -- Input Scaler -> To reduce the RAM resource in the Frame Memory
    parameter I_IMG_GRAYSCALE   = 0,    
    parameter I_IMG_DOWNSCALE   = 1,
    parameter I_DOWNSCALE_TYPE  = "MAX-POOLING"  // Downscale Type - "AVR-POOLING": Average Pooling || "MAX-POOLING": Max pooling

) (
    input                       sys_clk,
    output                      sys_trap,
    input                       rst_n,
`ifdef IMAGE_PROCESSOR_ENABLE
    input                       iproc_clk,
    output                      iproc_trap,
    input                       iproc_rst_n,
`endif
    // Camera RX Interface
    input   [DVP_DATA_W-1:0]    dvp_d_i,
    input                       dvp_href_i,
    input                       dvp_vsync_i,
    // input                       dvp_hsync_i,
    input                       dvp_pclk_i,
    output                      dvp_xclk_o,
    output                      dvp_pwdn_o,
    // Display TX Interface
    output                      dbi_dcx_o,
    output                      dbi_csx_o,
    output                      dbi_resx_o,
    output                      dbi_rdx_o,
    output                      dbi_wrx_o,
    inout   [DBI_IF_D_W-1:0]    dbi_d_o,
    // Camera Controller Interface
    output                      sio_c,
    inout                       sio_d,
    // UART interface
    output                      tx,
    input                       rx

`ifdef SILICON_DEBUG
    // ,output                     debug_0
    ,output                     dvp_href_2
    ,output                     dvp_vsync_2
    // ,output                     dvp_pclk_2
    // ,output                     dvp_xclk_2
    // ,output                     dvp_d_i_0
    // ,output                     dvp_d_i_1
`endif

);

    // ========================================================================================
    // ================================== Configuration BUS ===================================
    // ========================================================================================
    localparam CBUS_MST_AMT             = 1;    // 1 master - processor
    localparam CBUS_SLV_AMT             = 6;    // 5 slaves: IMEM + DSP + CAM + SCCB + DMA + UART
    localparam CBUS_MST_MAP_W           = $clog2(CBUS_MST_AMT);
    localparam CBUS_SLV_MAP_W           = $clog2(CBUS_SLV_AMT);
    localparam CBUS_DATA_W              = 32;
    localparam CBUS_ADDR_W              = 32;
    localparam CBUS_M_ID_W              = 1;    // 1 masters
    localparam CBUS_S_ID_W              = CBUS_M_ID_W + CBUS_MST_MAP_W;
    localparam CBUS_BURST_W             = 2;    // Width of xBURST 
    localparam CBUS_LEN_W               = 9;
    localparam CBUS_SIZE_W              = 3;
    localparam CBUS_RESP_W              = 2;
    localparam CBUS_OUST_AMT            = 2;    // Number of outstanding transacitons in the BUS
    // -- Instruction Memory
    localparam IMEM_PREFIX_ADDR         = 3'd0;
    localparam IMEM_REGION_NUM          = 3; // Bootloader + Main program + ISR regions
    localparam IMEM_BOOT_OFFSET         = 32'h0000_0000; // Bootloader program offset
    localparam IMEM_MP_OFFSET           = 32'h0001_0000; // Main program offset
    localparam IMEM_ISR_OFFSET          = 32'h0002_0000; // ISR program offset
    localparam IMEM_BASE_ADDR           = {IMEM_PREFIX_ADDR, 29'h0000_0000}; // Base address: 0x0000_0000
    localparam IMEM_BOOT_BASE_ADDR      = IMEM_BASE_ADDR + IMEM_BOOT_OFFSET; // Base address: 0x0000_0000
    localparam IMEM_MP_BASE_ADDR        = IMEM_BASE_ADDR + IMEM_MP_OFFSET;   // Base address: 0x0001_0000
    localparam IMEM_ISR_BASE_ADDR       = IMEM_BASE_ADDR + IMEM_ISR_OFFSET;  // Base address: 0x0002_0000
    // -- Display TX configuration Memory
    localparam DSP_PREFIX_ADDR          = 3'd1;
    localparam DSP_BASE_ADDR            = {DSP_PREFIX_ADDR, 29'h0000_0000};  // Base address: 0x2000_0000
    // -- Camera RX configuration Memory
    localparam CAM_PREFIX_ADDR          = 3'd2;
    localparam CAM_BASE_ADDR            = {CAM_PREFIX_ADDR, 29'h0000_0000};  // Base address: 0x4000_0000
    // -- Camera Control configuration Memory
    localparam CC_PREFIX_ADDR           = 3'd3;
    localparam CC_BASE_ADDR             = {CC_PREFIX_ADDR,  29'h0000_0000};  // Base address: 0x6000_0000
    // -- DMA Configuration interface
    localparam DMA_PREFIX_ADDR          = 3'd4;
    localparam DMA_BASE_ADDR            = {DMA_PREFIX_ADDR, 29'h0000_0000};  // Base address: 0x8000_0000
    // -- UART configuration Memory
    localparam UART_PREFIX_ADDR         = 3'd5;
    localparam UART_BASE_ADDR           = {UART_PREFIX_ADDR, 29'h0000_0000}; // Base address: 0xA000_0000

    // ========================================================================================
    // ====================================== Image BUS =======================================
    // ========================================================================================
    localparam IBUS_ID_W                = CBUS_S_ID_W;
    localparam IBUS_DATA_W              = 256;
    localparam IBUS_ADDR_W              = 32;
    localparam IBUS_LEN_W               = 8;
    localparam IBUS_SIZE_W              = 8;
    localparam IBUS_RESP_W              = 2;

    // ========================================================================================
    // ===================================== Display BUS ======================================
    // ========================================================================================
    localparam DBUS_MST_AMT             = 1; // DMA
    localparam DBUS_SLV_AMT             = 2; // Display Controller(1) + Image Processor(1)
    localparam DBUS_TID_W               = 1;
    localparam DBUS_TDEST_W             = $clog2(DBUS_SLV_AMT);
    localparam DBUS_TDATA_W             = IBUS_DATA_W;
    localparam DBUS_TKEEP_W             = DBUS_TDATA_W/8;
    localparam DBUS_TSTRB_W             = DBUS_TDATA_W/8;
    // -- Display TX Controller streaming Memory
    localparam DSP_TDEST_MSK            = 1'd0;
    localparam DSP_TREADY_IDX           = 1'd0;
    // -- Image Processor streaming Memory
    localparam IP_TDEST_MSK             = 1'd1;
    localparam IP_TREADY_IDX            = 1'd1;


    // ========================================================================================
    // ============================= Image Structure configuration ============================
    // ========================================================================================
    localparam RGB_PXL_W                = 16; // RGB565 pixel
    localparam GRAY_PXL_W               = 8;  // Gray pixel 
    // Input Image
    localparam I_FRM_SIZE               = I_FRM_COL_NUM * I_FRM_ROW_NUM; // Input frame size
    localparam I_PXL_W                  = (I_PXL_FORMAT == "RGB") ? RGB_PXL_W : GRAY_PXL_W;
    // Processed Image
    localparam P_FRM_COL_NUM            = I_IMG_DOWNSCALE ? I_FRM_COL_NUM/2 : I_FRM_COL_NUM;
    localparam P_FRM_ROW_NUM            = I_IMG_DOWNSCALE ? I_FRM_ROW_NUM/2 : I_FRM_ROW_NUM;
    localparam P_FRM_SIZE               = P_FRM_COL_NUM * P_FRM_ROW_NUM; // Processed frame size
    localparam P_PXL_FORMAT             = I_IMG_GRAYSCALE ? "GRAY" : I_PXL_FORMAT;
    localparam P_PXL_W                  = I_IMG_GRAYSCALE ? GRAY_PXL_W : I_PXL_W;
    // Image Memory
    localparam IGMEM_BASE_ADDR          = 32'h0000_0000;
    localparam IGMEM_WORD_W             = IBUS_DATA_W;  // Word width
    localparam integer IGMEM_SIZE       = P_FRM_SIZE * P_PXL_W / IGMEM_WORD_W; // Memory size

    // Configuration BUS
    wire    [CBUS_M_ID_W*CBUS_MST_AMT-1:0]          cbus_m_awid_flat;
    wire    [CBUS_ADDR_W*CBUS_MST_AMT-1:0]          cbus_m_awaddr_flat;
    wire    [CBUS_BURST_W*CBUS_MST_AMT-1:0]         cbus_m_awburst_flat;
    wire    [CBUS_LEN_W*CBUS_MST_AMT-1:0]           cbus_m_awlen_flat;
    wire    [CBUS_SIZE_W*CBUS_MST_AMT-1:0]          cbus_m_awsize_flat;
    wire    [CBUS_MST_AMT-1:0]                      cbus_m_awvalid_flat;
    wire    [CBUS_DATA_W*CBUS_MST_AMT-1:0]          cbus_m_wdata_flat;
    wire    [CBUS_MST_AMT-1:0]                      cbus_m_wlast_flat;
    wire    [CBUS_MST_AMT-1:0]                      cbus_m_wvalid_flat;
    wire    [CBUS_MST_AMT-1:0]                      cbus_m_bready_flat;
    wire    [CBUS_M_ID_W*CBUS_MST_AMT-1:0]          cbus_m_arid_flat;
    wire    [CBUS_ADDR_W*CBUS_MST_AMT-1:0]          cbus_m_araddr_flat;
    wire    [CBUS_BURST_W*CBUS_MST_AMT-1:0]         cbus_m_arburst_flat;
    wire    [CBUS_LEN_W*CBUS_MST_AMT-1:0]           cbus_m_arlen_flat;
    wire    [CBUS_SIZE_W*CBUS_MST_AMT-1:0]          cbus_m_arsize_flat;
    wire    [CBUS_MST_AMT-1:0]                      cbus_m_arvalid_flat;
    wire    [CBUS_MST_AMT-1:0]                      cbus_m_rready_flat;
    wire    [CBUS_SLV_AMT-1:0]                      cbus_s_awready_flat;
    wire    [CBUS_SLV_AMT-1:0]                      cbus_s_wready_flat;
    wire    [CBUS_S_ID_W*CBUS_SLV_AMT-1:0]          cbus_s_bid_flat;
    wire    [CBUS_RESP_W*CBUS_SLV_AMT-1:0]          cbus_s_bresp_flat;
    wire    [CBUS_SLV_AMT-1:0]                      cbus_s_bvalid_flat;
    wire    [CBUS_SLV_AMT-1:0]                      cbus_s_arready_flat;
    wire    [CBUS_S_ID_W*CBUS_SLV_AMT-1:0]          cbus_s_rid_flat;
    wire    [CBUS_DATA_W*CBUS_SLV_AMT-1:0]          cbus_s_rdata_flat;
    wire    [CBUS_RESP_W*CBUS_SLV_AMT-1:0]          cbus_s_rresp_flat;
    wire    [CBUS_SLV_AMT-1:0]                      cbus_s_rlast_flat;
    wire    [CBUS_SLV_AMT-1:0]                      cbus_s_rvalid_flat;
    wire    [CBUS_MST_AMT-1:0]                      cbus_m_awready_flat;
    wire    [CBUS_MST_AMT-1:0]                      cbus_m_wready_flat;
    wire    [CBUS_M_ID_W*CBUS_MST_AMT-1:0]          cbus_m_bid_flat;
    wire    [CBUS_RESP_W*CBUS_MST_AMT-1:0]          cbus_m_bresp_flat;
    wire    [CBUS_MST_AMT-1:0]                      cbus_m_bvalid_flat;
    wire    [CBUS_MST_AMT-1:0]                      cbus_m_arready_flat;
    wire    [CBUS_M_ID_W*CBUS_MST_AMT-1:0]          cbus_m_rid_flat;
    wire    [CBUS_DATA_W*CBUS_MST_AMT-1:0]          cbus_m_rdata_flat;
    wire    [CBUS_RESP_W*CBUS_MST_AMT-1:0]          cbus_m_rresp_flat;
    wire    [CBUS_MST_AMT-1:0]                      cbus_m_rlast_flat;
    wire    [CBUS_MST_AMT-1:0]                      cbus_m_rvalid_flat;
    wire    [CBUS_S_ID_W*CBUS_SLV_AMT-1:0]          cbus_s_awid_flat;
    wire    [CBUS_ADDR_W*CBUS_SLV_AMT-1:0]          cbus_s_awaddr_flat;
    wire    [CBUS_BURST_W*CBUS_SLV_AMT-1:0]         cbus_s_awburst_flat;
    wire    [CBUS_LEN_W*CBUS_SLV_AMT-1:0]           cbus_s_awlen_flat;
    wire    [CBUS_SIZE_W*CBUS_SLV_AMT-1:0]          cbus_s_awsize_flat;
    wire    [CBUS_SLV_AMT-1:0]                      cbus_s_awvalid_flat;
    wire    [CBUS_DATA_W*CBUS_SLV_AMT-1:0]          cbus_s_wdata_flat;
    wire    [CBUS_SLV_AMT-1:0]                      cbus_s_wlast_flat;
    wire    [CBUS_SLV_AMT-1:0]                      cbus_s_wvalid_flat;
    wire    [CBUS_SLV_AMT-1:0]                      cbus_s_bready_flat;
    wire    [CBUS_S_ID_W*CBUS_SLV_AMT-1:0]          cbus_s_arid_flat;
    wire    [CBUS_ADDR_W*CBUS_SLV_AMT-1:0]          cbus_s_araddr_flat;
    wire    [CBUS_BURST_W*CBUS_SLV_AMT-1:0]         cbus_s_arburst_flat;
    wire    [CBUS_LEN_W*CBUS_SLV_AMT-1:0]           cbus_s_arlen_flat;
    wire    [CBUS_SIZE_W*CBUS_SLV_AMT-1:0]          cbus_s_arsize_flat;
    wire    [CBUS_SLV_AMT-1:0]                      cbus_s_arvalid_flat;
    wire    [CBUS_SLV_AMT-1:0]                      cbus_s_rready_flat;
    wire    [CBUS_M_ID_W-1:0]                       cbus_m_awid         [0:CBUS_MST_AMT-1];
    wire    [CBUS_ADDR_W-1:0]                       cbus_m_awaddr       [0:CBUS_MST_AMT-1];
    wire    [CBUS_BURST_W-1:0]                      cbus_m_awburst      [0:CBUS_MST_AMT-1];
    wire    [CBUS_LEN_W-1:0]                        cbus_m_awlen        [0:CBUS_MST_AMT-1];
    wire    [CBUS_SIZE_W-1:0]                       cbus_m_awsize       [0:CBUS_MST_AMT-1];
    wire                                            cbus_m_awvalid      [0:CBUS_MST_AMT-1];
    wire    [CBUS_DATA_W-1:0]                       cbus_m_wdata        [0:CBUS_MST_AMT-1];
    wire                                            cbus_m_wlast        [0:CBUS_MST_AMT-1];
    wire                                            cbus_m_wvalid       [0:CBUS_MST_AMT-1];
    wire                                            cbus_m_bready       [0:CBUS_MST_AMT-1];
    wire    [CBUS_M_ID_W-1:0]                       cbus_m_arid         [0:CBUS_MST_AMT-1];
    wire    [CBUS_ADDR_W-1:0]                       cbus_m_araddr       [0:CBUS_MST_AMT-1];
    wire    [CBUS_BURST_W-1:0]                      cbus_m_arburst      [0:CBUS_MST_AMT-1];
    wire    [CBUS_LEN_W-1:0]                        cbus_m_arlen        [0:CBUS_MST_AMT-1];
    wire    [CBUS_SIZE_W-1:0]                       cbus_m_arsize       [0:CBUS_MST_AMT-1];
    wire                                            cbus_m_arvalid      [0:CBUS_MST_AMT-1];
    wire                                            cbus_m_rready       [0:CBUS_MST_AMT-1];
    wire                                            cbus_m_awready      [0:CBUS_MST_AMT-1];
    wire                                            cbus_m_wready       [0:CBUS_MST_AMT-1];
    wire    [CBUS_M_ID_W-1:0]                       cbus_m_bid          [0:CBUS_MST_AMT-1];
    wire    [CBUS_RESP_W-1:0]                       cbus_m_bresp        [0:CBUS_MST_AMT-1];
    wire                                            cbus_m_bvalid       [0:CBUS_MST_AMT-1];
    wire                                            cbus_m_arready      [0:CBUS_MST_AMT-1];
    wire    [CBUS_M_ID_W-1:0]                       cbus_m_rid          [0:CBUS_MST_AMT-1];
    wire    [CBUS_DATA_W-1:0]                       cbus_m_rdata        [0:CBUS_MST_AMT-1];
    wire    [CBUS_RESP_W-1:0]                       cbus_m_rresp        [0:CBUS_MST_AMT-1];
    wire                                            cbus_m_rlast        [0:CBUS_MST_AMT-1];
    wire                                            cbus_m_rvalid       [0:CBUS_MST_AMT-1];
    wire                                            cbus_s_awready      [0:CBUS_SLV_AMT-1];
    wire                                            cbus_s_wready       [0:CBUS_SLV_AMT-1];
    wire    [CBUS_S_ID_W-1:0]                       cbus_s_bid          [0:CBUS_SLV_AMT-1];
    wire    [CBUS_RESP_W-1:0]                       cbus_s_bresp        [0:CBUS_SLV_AMT-1];
    wire                                            cbus_s_bvalid       [0:CBUS_SLV_AMT-1];
    wire                                            cbus_s_arready      [0:CBUS_SLV_AMT-1];
    wire    [CBUS_S_ID_W-1:0]                       cbus_s_rid          [0:CBUS_SLV_AMT-1];
    wire    [CBUS_DATA_W-1:0]                       cbus_s_rdata        [0:CBUS_SLV_AMT-1];
    wire    [CBUS_RESP_W-1:0]                       cbus_s_rresp        [0:CBUS_SLV_AMT-1];
    wire                                            cbus_s_rlast        [0:CBUS_SLV_AMT-1];
    wire                                            cbus_s_rvalid       [0:CBUS_SLV_AMT-1];
    wire    [CBUS_S_ID_W-1:0]                       cbus_s_awid         [0:CBUS_SLV_AMT-1];
    wire    [CBUS_ADDR_W-1:0]                       cbus_s_awaddr       [0:CBUS_SLV_AMT-1];
    wire    [CBUS_BURST_W-1:0]                      cbus_s_awburst      [0:CBUS_SLV_AMT-1];
    wire    [CBUS_LEN_W-1:0]                        cbus_s_awlen        [0:CBUS_SLV_AMT-1];
    wire    [CBUS_SIZE_W-1:0]                       cbus_s_awsize       [0:CBUS_SLV_AMT-1];
    wire                                            cbus_s_awvalid      [0:CBUS_SLV_AMT-1];
    wire    [CBUS_DATA_W-1:0]                       cbus_s_wdata        [0:CBUS_SLV_AMT-1];
    wire                                            cbus_s_wlast        [0:CBUS_SLV_AMT-1];
    wire                                            cbus_s_wvalid       [0:CBUS_SLV_AMT-1];
    wire                                            cbus_s_bready       [0:CBUS_SLV_AMT-1];
    wire    [CBUS_S_ID_W-1:0]                       cbus_s_arid         [0:CBUS_SLV_AMT-1];
    wire    [CBUS_ADDR_W-1:0]                       cbus_s_araddr       [0:CBUS_SLV_AMT-1];
    wire    [CBUS_BURST_W-1:0]                      cbus_s_arburst      [0:CBUS_SLV_AMT-1];
    wire    [CBUS_LEN_W-1:0]                        cbus_s_arlen        [0:CBUS_SLV_AMT-1];
    wire    [CBUS_SIZE_W-1:0]                       cbus_s_arsize       [0:CBUS_SLV_AMT-1];
    wire                                            cbus_s_arvalid      [0:CBUS_SLV_AMT-1];
    wire                                            cbus_s_rready       [0:CBUS_SLV_AMT-1];   

    // Image BUS
    wire    [IBUS_ID_W-1:0]                         ibus_awid;
    wire    [IBUS_ADDR_W-1:0]                       ibus_awaddr;
    wire    [1:0]                                   ibus_awburst;        
    wire    [IBUS_LEN_W-1:0]                        ibus_awlen;
    wire                                            ibus_awvalid;
    wire                                            ibus_awready;
    wire    [IBUS_DATA_W-1:0]                       ibus_wdata;
    wire                                            ibus_wlast;
    wire                                            ibus_wvalid;
    wire                                            ibus_wready;
    wire    [IBUS_ID_W-1:0]                         ibus_bid;
    wire    [IBUS_RESP_W-1:0]                       ibus_bresp;
    wire                                            ibus_bvalid;
    wire                                            ibus_bready;
    wire    [IBUS_ID_W-1:0]                         ibus_arid;
    wire    [IBUS_ADDR_W-1:0]                       ibus_araddr;
    wire    [1:0]                                   ibus_arburst;
    wire    [IBUS_LEN_W-1:0]                        ibus_arlen;
    wire                                            ibus_arvalid;
    wire                                            ibus_arready;
    wire    [IBUS_ID_W-1:0]                         ibus_rid;
    wire    [IBUS_DATA_W-1:0]                       ibus_rdata;
    wire    [IBUS_RESP_W-1:0]                       ibus_rresp;
    wire                                            ibus_rlast;
    wire                                            ibus_rvalid;
    wire                                            ibus_rready;

    // Display BUS
    wire    [DBUS_TDEST_W-1:0]                      dbus_tdest;
    wire    [DBUS_TDATA_W-1:0]                      dbus_tdata;
    wire    [DBUS_TKEEP_W-1:0]                      dbus_tkeep;
    wire    [DBUS_TSTRB_W-1:0]                      dbus_tstrb;
    wire                                            dbus_tlast;
    wire                                            dbus_tvalid;
    wire                                            dbus_tready;
    wire    [DBUS_SLV_AMT-1:0]                      dbus_tready_slv;
    
    // Interrupt signals
    wire    [1:0]                                   dma_irq;    // Display DMA interrupt    [0]: TXN_DSP_COMPLETE irq   ||  [1]: TXN_IP_COMPLETED irq
    wire    [1:0]                                   cam_irq;    // Camera IF interrupt:     [0]: FRAME_CAPTURED irq     ||  [1]: FRAME_STORED irq    

    // IP instantiation
    // -- Processor
    picorv32_axi #(
        .ENABLE_COUNTERS        (0),
        .ENABLE_COUNTERS64      (0),
        .ENABLE_REGS_16_31      (0),
        .ENABLE_REGS_DUALPORT   (0),
        .TWO_STAGE_SHIFT        (0),
        .BARREL_SHIFTER         (0),
        .TWO_CYCLE_COMPARE      (0),
        .TWO_CYCLE_ALU          (0),
        .COMPRESSED_ISA         (0),
        .CATCH_MISALIGN         (0),
        .CATCH_ILLINSN          (0),
        .ENABLE_PCPI            (0),
        .ENABLE_MUL             (0),
        .ENABLE_FAST_MUL        (0),
        .ENABLE_DIV             (0),
        .ENABLE_IRQ             (1),
        .ENABLE_IRQ_QREGS       (1),
        .ENABLE_IRQ_TIMER       (1),
        .ENABLE_TRACE           (0),
        .REGS_INIT_ZERO         (0),
        .MASKED_IRQ             (32'hffff_fff0), // Use 4 interrupt sources
        .LATCHED_IRQ            (),
        .PROGADDR_RESET         (IMEM_BOOT_BASE_ADDR),
        .PROGADDR_IRQ           (IMEM_ISR_BASE_ADDR),
        .STACKADDR              ()
    ) proc (
        .clk                    (sys_clk),
        .resetn                 (rst_n),
        .trap                   (sys_trap),
        .mem_axi_awvalid        (cbus_m_awvalid[0]),
        .mem_axi_awready        (cbus_m_awready[0]),
        .mem_axi_awaddr         (cbus_m_awaddr[0]),
        .mem_axi_awprot         (),
        .mem_axi_wvalid         (cbus_m_wvalid[0]),
        .mem_axi_wready         (cbus_m_wready[0]),
        .mem_axi_wdata          (cbus_m_wdata[0]),
        .mem_axi_wstrb          (),
        .mem_axi_bvalid         (cbus_m_bvalid[0]),
        .mem_axi_bready         (cbus_m_bready[0]),        
        .mem_axi_arvalid        (cbus_m_arvalid[0]),
        .mem_axi_arready        (cbus_m_arready[0]),
        .mem_axi_araddr         (cbus_m_araddr[0]),
        .mem_axi_arprot         (),
        .mem_axi_rvalid         (cbus_m_rvalid[0]),
        .mem_axi_rready         (cbus_m_rready[0]),
        .mem_axi_rdata          (cbus_m_rdata[0]),
        // N/C
        .pcpi_valid             (),
        .pcpi_insn              (),
        .pcpi_rs1               (),
        .pcpi_rs2               (),
        .pcpi_wr                (),
        .pcpi_rd                (),
        .pcpi_wait              (),
        .pcpi_ready             (),
        .irq                    ({28'h00, dma_irq, cam_irq}),
        .eoi                    (),
        .trace_valid            (),
        .trace_data             ()
    );

    // -- Configuration BUS
    axi_interconnect #(
        .MST_AMT                (CBUS_MST_AMT),
        .SLV_AMT                (CBUS_SLV_AMT),
        .OUTSTANDING_AMT        (CBUS_OUST_AMT),
        .MST_WEIGHT             (1),
        .MST_ID_W               (),
        .SLV_ID_W               (),
        .DATA_WIDTH             (CBUS_DATA_W),
        .ADDR_WIDTH             (CBUS_ADDR_W),
        .TRANS_MST_ID_W         (CBUS_M_ID_W),
        .TRANS_SLV_ID_W         (CBUS_S_ID_W),
        .TRANS_BURST_W          (CBUS_BURST_W),
        .TRANS_DATA_LEN_W       (CBUS_LEN_W),
        .TRANS_DATA_SIZE_W      (CBUS_SIZE_W),
        .TRANS_WR_RESP_W        (CBUS_RESP_W),
        .SLV_ID_MSB_IDX         (CBUS_ADDR_W - 1),
        .SLV_ID_LSB_IDX         (CBUS_ADDR_W - CBUS_SLV_MAP_W),
        .DSP_RDATA_DEPTH        ()
    ) cb (
        .ACLK_i                 (sys_clk),
        .ARESETn_i              (rst_n),
        .m_AWID_i               (cbus_m_awid_flat),
        .m_AWADDR_i             (cbus_m_awaddr_flat),
        .m_AWBURST_i            (cbus_m_awburst_flat),
        .m_AWLEN_i              (cbus_m_awlen_flat),
        .m_AWSIZE_i             (cbus_m_awsize_flat),
        .m_AWVALID_i            (cbus_m_awvalid_flat),
        .m_WDATA_i              (cbus_m_wdata_flat),
        .m_WLAST_i              (cbus_m_wlast_flat),
        .m_WVALID_i             (cbus_m_wvalid_flat),
        .m_BREADY_i             (cbus_m_bready_flat),
        .m_ARID_i               (cbus_m_arid_flat),
        .m_ARADDR_i             (cbus_m_araddr_flat),
        .m_ARBURST_i            (cbus_m_arburst_flat),
        .m_ARLEN_i              (cbus_m_arlen_flat),
        .m_ARSIZE_i             (cbus_m_arsize_flat),
        .m_ARVALID_i            (cbus_m_arvalid_flat),
        .m_RREADY_i             (cbus_m_rready_flat),
        .s_AWREADY_i            (cbus_s_awready_flat),
        .s_WREADY_i             (cbus_s_wready_flat),
        .s_BID_i                (cbus_s_bid_flat),
        .s_BRESP_i              (cbus_s_bresp_flat),
        .s_BVALID_i             (cbus_s_bvalid_flat),
        .s_ARREADY_i            (cbus_s_arready_flat),
        .s_RID_i                (cbus_s_rid_flat),
        .s_RDATA_i              (cbus_s_rdata_flat),
        .s_RRESP_i              (cbus_s_rresp_flat),
        .s_RLAST_i              (cbus_s_rlast_flat),
        .s_RVALID_i             (cbus_s_rvalid_flat),
        .m_AWREADY_o            (cbus_m_awready_flat),
        .m_WREADY_o             (cbus_m_wready_flat),
        .m_BID_o                (cbus_m_bid_flat),
        .m_BRESP_o              (cbus_m_bresp_flat),
        .m_BVALID_o             (cbus_m_bvalid_flat),
        .m_ARREADY_o            (cbus_m_arready_flat),
        .m_RID_o                (cbus_m_rid_flat),
        .m_RDATA_o              (cbus_m_rdata_flat),
        .m_RRESP_o              (cbus_m_rresp_flat),
        .m_RLAST_o              (cbus_m_rlast_flat),
        .m_RVALID_o             (cbus_m_rvalid_flat),
        .s_AWID_o               (cbus_s_awid_flat),
        .s_AWADDR_o             (cbus_s_awaddr_flat),
        .s_AWBURST_o            (cbus_s_awburst_flat),
        .s_AWLEN_o              (cbus_s_awlen_flat),
        .s_AWSIZE_o             (cbus_s_awsize_flat),
        .s_AWVALID_o            (cbus_s_awvalid_flat),
        .s_WDATA_o              (cbus_s_wdata_flat),
        .s_WLAST_o              (cbus_s_wlast_flat),
        .s_WVALID_o             (cbus_s_wvalid_flat),
        .s_BREADY_o             (cbus_s_bready_flat),
        .s_ARID_o               (cbus_s_arid_flat),
        .s_ARADDR_o             (cbus_s_araddr_flat),
        .s_ARBURST_o            (cbus_s_arburst_flat),
        .s_ARLEN_o              (cbus_s_arlen_flat),
        .s_ARSIZE_o             (cbus_s_arsize_flat),
        .s_ARVALID_o            (cbus_s_arvalid_flat),
        .s_RREADY_o             (cbus_s_rready_flat)
    );

    // -- Instruction Memory
    axi4_mem #(
        .ATX_DATA_W             (CBUS_DATA_W),
        .ATX_ADDR_W             (CBUS_ADDR_W),
        .ATX_ID_W               (CBUS_S_ID_W),
        .ATX_LEN_W              (CBUS_LEN_W),
        .ATX_SIZE_W             (CBUS_SIZE_W),
        .ATX_RESP_W             (CBUS_RESP_W),
        .ATX_OUSTD_NUM          (2),        
        .MEM_BASE_ADDR          (IMEM_BASE_ADDR),
        .MEM_OFFSET             (1),
        .MEM_DATA_W             (CBUS_DATA_W),
        .MEM_ADDR_W             (CBUS_ADDR_W), // 32bit x (2^10)
        .MEM_LATENCY            (1),
        .MEM_INIT_FILE          (BOOTLOADER_FILE),
        .NUM_REGION             (IMEM_REGION_NUM),
        .REGION_BASE_ADDR       ({{2'b00, IMEM_ISR_BASE_ADDR[31:2]},    {2'b00, IMEM_MP_BASE_ADDR[31:2]},   {2'b00, IMEM_BOOT_BASE_ADDR[31:2]}}), // Align to word-access
        .REGION_SIZE            ({ISR_SIZE,                             MP_SIZE,                            BOOT_SIZE})
    ) im (
        .clk                    (sys_clk),
        .rst_n                  (rst_n),
        .s_awid_i               (cbus_s_awid[IMEM_PREFIX_ADDR]),
        .s_awaddr_i             (cbus_s_awaddr[IMEM_PREFIX_ADDR]>>2),    // Memory: word-access && Processor: byte-access
        .s_awburst_i            (cbus_s_awburst[IMEM_PREFIX_ADDR]),
        .s_awlen_i              (cbus_s_awlen[IMEM_PREFIX_ADDR]),
        .s_awvalid_i            (cbus_s_awvalid[IMEM_PREFIX_ADDR]),
        .s_wdata_i              (cbus_s_wdata[IMEM_PREFIX_ADDR]),
        .s_wlast_i              (cbus_s_wlast[IMEM_PREFIX_ADDR]),
        .s_wvalid_i             (cbus_s_wvalid[IMEM_PREFIX_ADDR]),
        .s_bready_i             (cbus_s_bready[IMEM_PREFIX_ADDR]),
        .s_arid_i               (cbus_s_arid[IMEM_PREFIX_ADDR]),
        .s_araddr_i             (cbus_s_araddr[IMEM_PREFIX_ADDR]>>2),    // Memory: word-access && Processor: byte-access
        .s_arburst_i            (cbus_s_arburst[IMEM_PREFIX_ADDR]),
        .s_arlen_i              (cbus_s_arlen[IMEM_PREFIX_ADDR]),
        .s_arvalid_i            (cbus_s_arvalid[IMEM_PREFIX_ADDR]),
        .s_rready_i             (cbus_s_rready[IMEM_PREFIX_ADDR]),
        .s_awready_o            (cbus_s_awready[IMEM_PREFIX_ADDR]),
        .s_wready_o             (cbus_s_wready[IMEM_PREFIX_ADDR]),
        .s_bid_o                (cbus_s_bid[IMEM_PREFIX_ADDR]),
        .s_bresp_o              (cbus_s_bresp[IMEM_PREFIX_ADDR]),
        .s_bvalid_o             (cbus_s_bvalid[IMEM_PREFIX_ADDR]),
        .s_arready_o            (cbus_s_arready[IMEM_PREFIX_ADDR]),
        .s_rid_o                (cbus_s_rid[IMEM_PREFIX_ADDR]),
        .s_rdata_o              (cbus_s_rdata[IMEM_PREFIX_ADDR]),
        .s_rresp_o              (cbus_s_rresp[IMEM_PREFIX_ADDR]),
        .s_rlast_o              (cbus_s_rlast[IMEM_PREFIX_ADDR]),
        .s_rvalid_o             (cbus_s_rvalid[IMEM_PREFIX_ADDR])
    );

    // -- Display TX controller
    dbi_tx_controller #(
        .INTERNAL_CLK           (INTERNAL_CLK),
        .DBI_IF_D_W             (DBI_IF_D_W),
        .TID_W                  (DBUS_TID_W),
        .TDEST_W                (DBUS_TDEST_W),
        .TDATA_W                (DBUS_TDATA_W),
        .TKEEP_W                (DBUS_TKEEP_W),
        .TSTRB_W                (DBUS_TSTRB_W),
        .AXIS_FIFO_D            (4), // TODO: Throughput check
        .ATX_BASE_ADDR          (DSP_BASE_ADDR),
        .ATX_ID_W               (CBUS_S_ID_W),
        .ATX_ADDR_W             (CBUS_ADDR_W),
        .ATX_DATA_W             (CBUS_DATA_W),
        .ATX_LEN_W              (CBUS_LEN_W),
        .ATX_SIZE_W             (CBUS_SIZE_W),
        .ATX_RESP_W             (CBUS_RESP_W),
        .TDEST_MASK             (DSP_TDEST_MSK),
        .IN_PXL_TYPE            (P_PXL_FORMAT),
        .FRM_COL_NUM            (P_FRM_COL_NUM),
        .FRM_ROW_NUM            (P_FRM_ROW_NUM)
    ) dsp (
        .clk                    (sys_clk),
        .rst_n                  (rst_n),
        // -- DBI Interface
        .dbi_dcx_o              (dbi_dcx_o),
        .dbi_csx_o              (dbi_csx_o),
        .dbi_resx_o             (dbi_resx_o),
        .dbi_rdx_o              (dbi_rdx_o),
        .dbi_wrx_o              (dbi_wrx_o),
        .dbi_d_o                (dbi_d_o),
        // -- Configuration Interface
        .s_awid_i               (cbus_s_awid[DSP_PREFIX_ADDR] ),
        .s_awaddr_i             (cbus_s_awaddr[DSP_PREFIX_ADDR]),
        .s_awlen_i              (cbus_s_awlen[DSP_PREFIX_ADDR]),
        .s_awburst_i            (cbus_s_awburst[DSP_PREFIX_ADDR]),
        .s_awvalid_i            (cbus_s_awvalid[DSP_PREFIX_ADDR]),
        .s_awready_o            (cbus_s_awready[DSP_PREFIX_ADDR]),
        .s_wdata_i              (cbus_s_wdata[DSP_PREFIX_ADDR]),
        .s_wlast_i              (cbus_s_wlast[DSP_PREFIX_ADDR]),
        .s_wvalid_i             (cbus_s_wvalid[DSP_PREFIX_ADDR]),
        .s_wready_o             (cbus_s_wready[DSP_PREFIX_ADDR]),
        .s_bid_o                (cbus_s_bid[DSP_PREFIX_ADDR]),
        .s_bresp_o              (cbus_s_bresp[DSP_PREFIX_ADDR]),
        .s_bvalid_o             (cbus_s_bvalid[DSP_PREFIX_ADDR]),
        .s_bready_i             (cbus_s_bready[DSP_PREFIX_ADDR]),
        .s_arid_i               (cbus_s_arid[DSP_PREFIX_ADDR]),
        .s_araddr_i             (cbus_s_araddr[DSP_PREFIX_ADDR]),
        .s_arburst_i            (cbus_s_arburst[DSP_PREFIX_ADDR]),
        .s_arlen_i              (cbus_s_arlen[DSP_PREFIX_ADDR]),
        .s_arvalid_i            (cbus_s_arvalid[DSP_PREFIX_ADDR]),
        .s_arready_o            (cbus_s_arready[DSP_PREFIX_ADDR]),
        .s_rid_o                (cbus_s_rid[DSP_PREFIX_ADDR]),
        .s_rdata_o              (cbus_s_rdata[DSP_PREFIX_ADDR]),
        .s_rlast_o              (cbus_s_rlast[DSP_PREFIX_ADDR]),
        .s_rresp_o              (cbus_s_rresp[DSP_PREFIX_ADDR]),
        .s_rvalid_o             (cbus_s_rvalid[DSP_PREFIX_ADDR]),
        .s_rready_i             (cbus_s_rready[DSP_PREFIX_ADDR]),
        // -- Streaming Interface
        .s_tid_i                (),
        .s_tdest_i              (dbus_tdest),
        .s_tdata_i              (dbus_tdata),
        .s_tkeep_i              (dbus_tkeep),
        .s_tstrb_i              (dbus_tstrb),
        .s_tlast_i              (dbus_tlast),
        .s_tvalid_i             (dbus_tvalid),
        .s_tready_o             (dbus_tready_slv[DSP_TREADY_IDX])
    );

    // -- Camera RX Controller
    dvp_rx_controller #(
        .INTERNAL_CLK           (INTERNAL_CLK),
        .DRC_BASE_ADDR          (CAM_BASE_ADDR),
        .DMA_SEL_BIT            (28),
        .DMA_DATA_W             (IBUS_DATA_W),
        .DMA_ADDR_W             (IBUS_ADDR_W),
        .S_DATA_W               (CBUS_DATA_W),
        .S_ADDR_W               (CBUS_ADDR_W),
        .MST_ID_W               (CBUS_S_ID_W),
        .ATX_LEN_W              (CBUS_LEN_W),
        .ATX_SIZE_W             (CBUS_SIZE_W),
        .ATX_RESP_W             (CBUS_RESP_W),
        .DVP_DATA_W             (DVP_DATA_W),
        .DVP_FIFO_D             (8),
        .DVP_CAPTURE_TYPE       ("PCLK_EDGE"), // For lower speed, but higher stability
        .PXL_GRAYSCALE          (I_IMG_GRAYSCALE),
        .FRM_DOWNSCALE          (I_IMG_DOWNSCALE),
        .FRM_COL_NUM            (I_FRM_COL_NUM),
        .FRM_ROW_NUM            (I_FRM_ROW_NUM),
        .DOWNSCALE_TYPE         (I_DOWNSCALE_TYPE)
    ) cam (
        .clk                    (sys_clk),
        .rst_n                  (rst_n),
        // -- DVP Interface
        .dvp_d_i                (dvp_d_i),
        .dvp_href_i             (dvp_href_i),
        .dvp_vsync_i            (dvp_vsync_i),
        .dvp_hsync_i            (dvp_href_i), // HREF and HSYNC share same pin
        .dvp_pclk_i             (dvp_pclk_i),
        .dvp_xclk_o             (dvp_xclk_o),
        .dvp_pwdn_o             (dvp_pwdn_o),
        // -- Master Configuration
        .s_awid_i               (cbus_s_awid[CAM_PREFIX_ADDR]),
        .s_awaddr_i             (cbus_s_awaddr[CAM_PREFIX_ADDR]),
        .s_awburst_i            (cbus_s_awburst[CAM_PREFIX_ADDR]),
        .s_awlen_i              (cbus_s_awlen[CAM_PREFIX_ADDR]),
        .s_awvalid_i            (cbus_s_awvalid[CAM_PREFIX_ADDR]),
        .s_awready_o            (cbus_s_awready[CAM_PREFIX_ADDR]),
        .s_wdata_i              (cbus_s_wdata[CAM_PREFIX_ADDR]),
        .s_wlast_i              (cbus_s_wlast[CAM_PREFIX_ADDR]),
        .s_wvalid_i             (cbus_s_wvalid[CAM_PREFIX_ADDR]),
        .s_wready_o             (cbus_s_wready[CAM_PREFIX_ADDR]),
        .s_bid_o                (cbus_s_bid[CAM_PREFIX_ADDR]),
        .s_bresp_o              (cbus_s_bresp[CAM_PREFIX_ADDR]),
        .s_bvalid_o             (cbus_s_bvalid[CAM_PREFIX_ADDR]),
        .s_bready_i             (cbus_s_bready[CAM_PREFIX_ADDR]),
        .s_arid_i               (cbus_s_arid[CAM_PREFIX_ADDR]),
        .s_araddr_i             (cbus_s_araddr[CAM_PREFIX_ADDR]),
        .s_arburst_i            (cbus_s_arburst[CAM_PREFIX_ADDR]),
        .s_arlen_i              (cbus_s_arlen[CAM_PREFIX_ADDR]),
        .s_arvalid_i            (cbus_s_arvalid[CAM_PREFIX_ADDR]),
        .s_arready_o            (cbus_s_arready[CAM_PREFIX_ADDR]),
        .s_rid_o                (cbus_s_rid[CAM_PREFIX_ADDR]),
        .s_rdata_o              (cbus_s_rdata[CAM_PREFIX_ADDR]),
        .s_rresp_o              (cbus_s_rresp[CAM_PREFIX_ADDR]),
        .s_rlast_o              (cbus_s_rlast[CAM_PREFIX_ADDR]),
        .s_rvalid_o             (cbus_s_rvalid[CAM_PREFIX_ADDR]),
        .s_rready_i             (cbus_s_rready[CAM_PREFIX_ADDR]),
        .m_awid_o               (ibus_awid),
        .m_awaddr_o             (ibus_awaddr),
        .m_awburst_o            (ibus_awburst),
        .m_awlen_o              (ibus_awlen),
        .m_awvalid_o            (ibus_awvalid),
        .m_awready_i            (ibus_awready),
        .m_wdata_o              (ibus_wdata),
        .m_wlast_o              (ibus_wlast),
        .m_wvalid_o             (ibus_wvalid),
        .m_wready_i             (ibus_wready),
        .m_bid_i                (ibus_bid),
        .m_bresp_i              (ibus_bresp),
        .m_bvalid_i             (ibus_bvalid),
        .m_bready_o             (ibus_bready),

        .drc_irq                (cam_irq[0]), // FRAME_CAPTURED interrupt
        .drc_trap               (),
        .dma_irq                (cam_irq[1]), // FRAME_STORED interrupt
        .dma_trap               ()
    );

    // -- Camera Controller
    sccb_master_controller #(
        .ATX_BASE_ADDR          (CC_BASE_ADDR),
        .ATX_DATA_W             (8),
        .ATX_ADDR_W             (CBUS_ADDR_W),
        .ATX_ID_W               (CBUS_S_ID_W),
        .ATX_LEN_W              (CBUS_LEN_W),
        .ATX_SIZE_W             (CBUS_SIZE_W),
        .ATX_RESP_W             (CBUS_RESP_W),
        .INTERNAL_CLK_FREQ      (INTERNAL_CLK),
        .MAX_SCCB_FREQ          ()
    ) cc (
        .clk                    (sys_clk),
        .rst_n                  (rst_n),
        .s_awid_i               (cbus_s_awid[CC_PREFIX_ADDR]),
        .s_awaddr_i             (cbus_s_awaddr[CC_PREFIX_ADDR]),
        .s_awburst_i            (cbus_s_awburst[CC_PREFIX_ADDR]),
        .s_awlen_i              (cbus_s_awlen[CC_PREFIX_ADDR]),
        .s_awvalid_i            (cbus_s_awvalid[CC_PREFIX_ADDR]),
        .s_wdata_i              (cbus_s_wdata[CC_PREFIX_ADDR][7:0]),
        .s_wlast_i              (cbus_s_wlast[CC_PREFIX_ADDR]),
        .s_wvalid_i             (cbus_s_wvalid[CC_PREFIX_ADDR]),
        .s_bready_i             (cbus_s_bready[CC_PREFIX_ADDR]),
        .s_arid_i               (cbus_s_arid[CC_PREFIX_ADDR]),
        .s_araddr_i             (cbus_s_araddr[CC_PREFIX_ADDR]),
        .s_arburst_i            (cbus_s_arburst[CC_PREFIX_ADDR]),
        .s_arlen_i              (cbus_s_arlen[CC_PREFIX_ADDR]),
        .s_arvalid_i            (cbus_s_arvalid[CC_PREFIX_ADDR]),
        .s_rready_i             (cbus_s_rready[CC_PREFIX_ADDR]),
        .s_awready_o            (cbus_s_awready[CC_PREFIX_ADDR]),
        .s_wready_o             (cbus_s_wready[CC_PREFIX_ADDR]),
        .s_bid_o                (cbus_s_bid[CC_PREFIX_ADDR]),
        .s_bresp_o              (cbus_s_bresp[CC_PREFIX_ADDR]),
        .s_bvalid_o             (cbus_s_bvalid[CC_PREFIX_ADDR]),
        .s_arready_o            (cbus_s_arready[CC_PREFIX_ADDR]),
        .s_rid_o                (cbus_s_rid[CC_PREFIX_ADDR]),
        .s_rdata_o              (cbus_s_rdata[CC_PREFIX_ADDR][7:0]),
        .s_rresp_o              (cbus_s_rresp[CC_PREFIX_ADDR]),
        .s_rlast_o              (cbus_s_rlast[CC_PREFIX_ADDR]),
        .s_rvalid_o             (cbus_s_rvalid[CC_PREFIX_ADDR]),
        .sio_c                  (sio_c),
        .sio_d                  (sio_d)
    );
    // -- UART
    uart_ctrl #(
        .INTERNAL_CLOCK         (INTERNAL_CLK),
        .ATX_BASE_ADDR          (UART_BASE_ADDR),
        .ATX_DATA_W             (8),
        .ATX_ADDR_W             (CBUS_ADDR_W),
        .ATX_ID_W               (CBUS_S_ID_W),
        .ATX_LEN_W              (CBUS_LEN_W),
        .ATX_SIZE_W             (CBUS_SIZE_W),
        .ATX_RESP_W             (CBUS_RESP_W)
    ) uart (
        .clk                    (sys_clk),
        .rst_n                  (rst_n),
        .RX                     (rx),
        .TX                     (tx),
        .s_awid_i               (cbus_s_awid[UART_PREFIX_ADDR]),
        .s_awaddr_i             (cbus_s_awaddr[UART_PREFIX_ADDR]),
        .s_awburst_i            (cbus_s_awburst[UART_PREFIX_ADDR]),
        .s_awlen_i              (cbus_s_awlen[UART_PREFIX_ADDR]),
        .s_awvalid_i            (cbus_s_awvalid[UART_PREFIX_ADDR]),
        .s_awready_o            (cbus_s_awready[UART_PREFIX_ADDR]),
        .s_wdata_i              (cbus_s_wdata[UART_PREFIX_ADDR][7:0]),
        .s_wlast_i              (cbus_s_wlast[UART_PREFIX_ADDR]),
        .s_wvalid_i             (cbus_s_wvalid[UART_PREFIX_ADDR]),
        .s_wready_o             (cbus_s_wready[UART_PREFIX_ADDR]),
        .s_bid_o                (cbus_s_bid[UART_PREFIX_ADDR]),
        .s_bresp_o              (cbus_s_bresp[UART_PREFIX_ADDR]),
        .s_bvalid_o             (cbus_s_bvalid[UART_PREFIX_ADDR]),
        .s_bready_i             (cbus_s_bready[UART_PREFIX_ADDR]),
        .s_arid_i               (cbus_s_arid[UART_PREFIX_ADDR]),
        .s_araddr_i             (cbus_s_araddr[UART_PREFIX_ADDR]),
        .s_arburst_i            (cbus_s_arburst[UART_PREFIX_ADDR]),
        .s_arlen_i              (cbus_s_arlen[UART_PREFIX_ADDR]),
        .s_arvalid_i            (cbus_s_arvalid[UART_PREFIX_ADDR]),
        .s_arready_o            (cbus_s_arready[UART_PREFIX_ADDR]),
        .s_rid_o                (cbus_s_rid[UART_PREFIX_ADDR]),
        .s_rdata_o              (cbus_s_rdata[UART_PREFIX_ADDR][7:0]),
        .s_rresp_o              (cbus_s_rresp[UART_PREFIX_ADDR]),
        .s_rlast_o              (cbus_s_rlast[UART_PREFIX_ADDR]),
        .s_rvalid_o             (cbus_s_rvalid[UART_PREFIX_ADDR]),
        .s_rready_i             (cbus_s_rready[UART_PREFIX_ADDR])
    );

    // -- DMA
    axi_dma #(
        .DMA_BASE_ADDR          (DMA_BASE_ADDR),
        .DMA_CHN_NUM            (2),   // Display TX Controller + Image Processor
        .DMA_LENGTH_W           (CBUS_LEN_W),
        .DMA_DESC_DEPTH         (2),   // Each channel uses 1 descriptor only
        .DMA_CHN_ARB_W          (3),
        .ROB_EN                 (0),
        .DESC_QUEUE_TYPE        (),
        .SRC_IF_TYPE            ("AXI4"),
        .SRC_ADDR_W             (IBUS_ADDR_W),
        .SRC_TDEST_W            (),   
        .ATX_SRC_DATA_W         (IBUS_DATA_W),
        .DST_IF_TYPE            ("AXIS"),
        .DST_ADDR_W             (),
        .DST_TDEST_W            (DBUS_TDEST_W),
        .ATX_DST_DATA_W         (IBUS_DATA_W),
        .S_DATA_W               (CBUS_DATA_W),
        .S_ADDR_W               (CBUS_ADDR_W),
        .MST_ID_W               (CBUS_S_ID_W),
        .ATX_LEN_W              (CBUS_LEN_W),
        .ATX_SIZE_W             (CBUS_SIZE_W),
        .ATX_RESP_W             (CBUS_RESP_W),
        .ATX_SRC_BYTE_AMT       (),
        .ATX_DST_BYTE_AMT       (),
        .ATX_NUM_OSTD           (),
        .ATX_INTL_DEPTH         (2)
    ) dma (
        .aclk                   (sys_clk),
        .aresetn                (rst_n),
        .s_awid_i               (cbus_s_awid[DMA_PREFIX_ADDR]),
        .s_awaddr_i             (cbus_s_awaddr[DMA_PREFIX_ADDR]),
        .s_awburst_i            (cbus_s_awburst[DMA_PREFIX_ADDR]),
        .s_awlen_i              (cbus_s_awlen[DMA_PREFIX_ADDR]),
        .s_awvalid_i            (cbus_s_awvalid[DMA_PREFIX_ADDR]),
        .s_awready_o            (cbus_s_awready[DMA_PREFIX_ADDR]),
        .s_wdata_i              (cbus_s_wdata[DMA_PREFIX_ADDR]),
        .s_wlast_i              (cbus_s_wlast[DMA_PREFIX_ADDR]),
        .s_wvalid_i             (cbus_s_wvalid[DMA_PREFIX_ADDR]),
        .s_wready_o             (cbus_s_wready[DMA_PREFIX_ADDR]),
        .s_bid_o                (cbus_s_bid[DMA_PREFIX_ADDR]),
        .s_bresp_o              (cbus_s_bresp[DMA_PREFIX_ADDR]),
        .s_bvalid_o             (cbus_s_bvalid[DMA_PREFIX_ADDR]),
        .s_bready_i             (cbus_s_bready[DMA_PREFIX_ADDR]),
        .s_arid_i               (cbus_s_arid[DMA_PREFIX_ADDR]),
        .s_araddr_i             (cbus_s_araddr[DMA_PREFIX_ADDR]),
        .s_arburst_i            (cbus_s_arburst[DMA_PREFIX_ADDR]),
        .s_arlen_i              (cbus_s_arlen[DMA_PREFIX_ADDR]),
        .s_arvalid_i            (cbus_s_arvalid[DMA_PREFIX_ADDR]),
        .s_arready_o            (cbus_s_arready[DMA_PREFIX_ADDR]),
        .s_rid_o                (cbus_s_rid[DMA_PREFIX_ADDR]),
        .s_rdata_o              (cbus_s_rdata[DMA_PREFIX_ADDR]),
        .s_rresp_o              (cbus_s_rresp[DMA_PREFIX_ADDR]),
        .s_rlast_o              (cbus_s_rlast[DMA_PREFIX_ADDR]),
        .s_rvalid_o             (cbus_s_rvalid[DMA_PREFIX_ADDR]),
        .s_rready_i             (cbus_s_rready[DMA_PREFIX_ADDR]),
        .m_arid_o               (ibus_arid),
        .m_araddr_o             (ibus_araddr),
        .m_arburst_o            (ibus_arburst),
        .m_arlen_o              (ibus_arlen),
        .m_arvalid_o            (ibus_arvalid),
        .m_arready_i            (ibus_arready),
        .m_rid_i                (ibus_rid),
        .m_rdata_i              (ibus_rdata),
        .m_rresp_i              (ibus_rresp),
        .m_rlast_i              (ibus_rlast),
        .m_rvalid_i             (ibus_rvalid),
        .m_rready_o             (ibus_rready),
        .m_awid_o               (),
        .m_awaddr_o             (),
        .m_awlen_o              (),
        .m_awburst_o            (),
        .m_awvalid_o            (),
        .m_awready_i            (),
        .m_wdata_o              (),
        .m_wlast_o              (),
        .m_wvalid_o             (),
        .m_wready_i             (),
        .m_bid_i                (),
        .m_bresp_i              (),
        .m_bvalid_i             (),
        .m_bready_o             (),
        .s_tid_i                (),
        .s_tdest_i              (),
        .s_tdata_i              (),
        .s_tkeep_i              (),
        .s_tstrb_i              (),
        .s_tlast_i              (),
        .s_tvalid_i             (),
        .s_tready_o             (),
        .m_tid_o                (),
        .m_tdest_o              (dbus_tdest),
        .m_tdata_o              (dbus_tdata),
        .m_tkeep_o              (dbus_tkeep),
        .m_tstrb_o              (dbus_tstrb),
        .m_tlast_o              (dbus_tlast),
        .m_tvalid_o             (dbus_tvalid),
        .m_tready_i             (dbus_tready),
        .irq                    (dma_irq),
        .trap                   ()
    );
    // -- Image Memory
    axi4_mem #(
        .ATX_DATA_W             (IBUS_DATA_W),
        .ATX_ADDR_W             (IBUS_ADDR_W),
        .ATX_ID_W               (IBUS_ID_W),
        .ATX_LEN_W              (IBUS_LEN_W),
        .ATX_SIZE_W             (IBUS_SIZE_W),
        .ATX_RESP_W             (IBUS_RESP_W),
        .MEM_BASE_ADDR          (IGMEM_BASE_ADDR),
        .MEM_OFFSET             (1),
        .MEM_DATA_W             (IBUS_DATA_W),
        .MEM_ADDR_W             ($clog2(IGMEM_SIZE)),       // 32bit x (2^10)
        .MEM_LATENCY            (1),
        .MEM_INIT_FILE          (),
        .NUM_REGION             (1),
        .REGION_BASE_ADDR       (IGMEM_BASE_ADDR),
        .REGION_SIZE            (IGMEM_SIZE)
    ) igm (
        .clk                    (sys_clk),
        .rst_n                  (rst_n),
        .s_awid_i               (ibus_awid),
        .s_awaddr_i             (ibus_awaddr),
        .s_awburst_i            (ibus_awburst),        
        .s_awlen_i              (ibus_awlen),
        .s_awvalid_i            (ibus_awvalid),
        .s_awready_o            (ibus_awready),
        .s_wdata_i              (ibus_wdata),
        .s_wlast_i              (ibus_wlast),
        .s_wvalid_i             (ibus_wvalid),
        .s_wready_o             (ibus_wready),
        .s_bid_o                (ibus_bid),
        .s_bresp_o              (ibus_bresp),
        .s_bvalid_o             (ibus_bvalid),
        .s_bready_i             (ibus_bready),
        .s_arid_i               (ibus_arid),
        .s_araddr_i             (ibus_araddr),
        .s_arburst_i            (ibus_arburst),
        .s_arlen_i              (ibus_arlen),
        .s_arvalid_i            (ibus_arvalid),
        .s_arready_o            (ibus_arready),
        .s_rid_o                (ibus_rid),
        .s_rdata_o              (ibus_rdata),
        .s_rresp_o              (ibus_rresp),
        .s_rlast_o              (ibus_rlast),
        .s_rvalid_o             (ibus_rvalid),
        .s_rready_i             (ibus_rready)
    );

`ifdef IMAGE_PROCESSOR_ENABLE
    image_processor #(

    ) ip (
        .clk                    (iproc_clk),
        .trap                   (iproc_trap),
        .rst_n                  (iproc_rst_n)
    );
`else
    assign dbus_tready_slv[IP_TREADY_IDX] = ~|(dbus_tdest^IP_TDEST_MSK); // Ready is asserted when the IP is mapped
`endif

    // Connection
    genvar mst_idx;
    genvar slv_idx;
    assign cbus_m_awid[0]      = {CBUS_M_ID_W{1'b0}};
    assign cbus_m_awburst[0]   = 2'b01; // Always increment
    assign cbus_m_awlen[0]     = {CBUS_LEN_W{1'b0}};
    assign cbus_m_wlast[0]     = 1'b1;
    assign cbus_m_arid[0]      = {CBUS_M_ID_W{1'b0}};
    assign cbus_m_arburst[0]   = 2'b01; // Always increment
    assign cbus_m_arlen[0]     = {CBUS_LEN_W{1'b0}};
    assign dbus_tready         = |dbus_tready_slv;
`ifdef OPENLANE_DEBUG
    assign cbus_s_rdata[UART_PREFIX_ADDR][31:8] = {3{cbus_s_rdata[UART_PREFIX_ADDR][7:0]}};
`endif
    generate
        for(mst_idx = 0; mst_idx < CBUS_MST_AMT; mst_idx = mst_idx + 1) begin   : AXI4_MST
            assign cbus_m_awid_flat[CBUS_M_ID_W*(mst_idx+1)-1-:CBUS_M_ID_W]         = cbus_m_awid[mst_idx];
            assign cbus_m_awaddr_flat[CBUS_ADDR_W*(mst_idx+1)-1-:CBUS_ADDR_W]       = cbus_m_awaddr[mst_idx];
            assign cbus_m_awburst_flat[CBUS_BURST_W*(mst_idx+1)-1-:CBUS_BURST_W]    = cbus_m_awburst[mst_idx];
            assign cbus_m_awlen_flat[CBUS_LEN_W*(mst_idx+1)-1-:CBUS_LEN_W]          = cbus_m_awlen[mst_idx];
            assign cbus_m_awsize_flat[CBUS_SIZE_W*(mst_idx+1)-1-:CBUS_SIZE_W]       = cbus_m_awsize[mst_idx];
            assign cbus_m_awvalid_flat[mst_idx]                                     = cbus_m_awvalid[mst_idx];
            assign cbus_m_wdata_flat[CBUS_DATA_W*(mst_idx+1)-1-:CBUS_DATA_W]        = cbus_m_wdata[mst_idx];
            assign cbus_m_wlast_flat[mst_idx]                                       = cbus_m_wlast[mst_idx];
            assign cbus_m_wvalid_flat[mst_idx]                                      = cbus_m_wvalid[mst_idx];
            assign cbus_m_bready_flat[mst_idx]                                      = cbus_m_bready[mst_idx];
            assign cbus_m_arid_flat[CBUS_M_ID_W*(mst_idx+1)-1-:CBUS_M_ID_W]         = cbus_m_arid[mst_idx];
            assign cbus_m_araddr_flat[CBUS_ADDR_W*(mst_idx+1)-1-:CBUS_ADDR_W]       = cbus_m_araddr[mst_idx];
            assign cbus_m_arburst_flat[CBUS_BURST_W*(mst_idx+1)-1-:CBUS_BURST_W]    = cbus_m_arburst[mst_idx];
            assign cbus_m_arlen_flat[CBUS_LEN_W*(mst_idx+1)-1-:CBUS_LEN_W]          = cbus_m_arlen[mst_idx];
            assign cbus_m_arsize_flat[CBUS_SIZE_W*(mst_idx+1)-1-:CBUS_SIZE_W]       = cbus_m_arsize[mst_idx];
            assign cbus_m_arvalid_flat[mst_idx]                                     = cbus_m_arvalid[mst_idx];
            assign cbus_m_rready_flat[mst_idx]                                      = cbus_m_rready[mst_idx];
            assign cbus_m_awready[mst_idx]                                          = cbus_m_awready_flat[mst_idx];
            assign cbus_m_wready[mst_idx]                                           = cbus_m_wready_flat[mst_idx];
            assign cbus_m_bid[mst_idx]                                              = cbus_m_bid_flat[CBUS_M_ID_W*(mst_idx+1)-1-:CBUS_M_ID_W];   
            assign cbus_m_bresp[mst_idx]                                            = cbus_m_bresp_flat[CBUS_RESP_W*(mst_idx+1)-1-:CBUS_RESP_W]; 
            assign cbus_m_bvalid[mst_idx]                                           = cbus_m_bvalid_flat[mst_idx];
            assign cbus_m_arready[mst_idx]                                          = cbus_m_arready_flat[mst_idx];
            assign cbus_m_rid[mst_idx]                                              = cbus_m_rid_flat[CBUS_M_ID_W*(mst_idx+1)-1-:CBUS_M_ID_W];   
            assign cbus_m_rdata[mst_idx]                                            = cbus_m_rdata_flat[CBUS_DATA_W*(mst_idx+1)-1-:CBUS_DATA_W]; 
            assign cbus_m_rresp[mst_idx]                                            = cbus_m_rresp_flat[CBUS_RESP_W*(mst_idx+1)-1-:CBUS_RESP_W]; 
            assign cbus_m_rlast[mst_idx]                                            = cbus_m_rlast_flat[mst_idx]; 
            assign cbus_m_rvalid[mst_idx]                                           = cbus_m_rvalid_flat[mst_idx];
        end
        for(slv_idx = 0; slv_idx < CBUS_SLV_AMT; slv_idx = slv_idx + 1) begin   : AXI4_SLV
            assign cbus_s_awready_flat[slv_idx]                                     = cbus_s_awready[slv_idx];
            assign cbus_s_wready_flat[slv_idx]                                      = cbus_s_wready[slv_idx];
            assign cbus_s_bid_flat[CBUS_S_ID_W*(slv_idx+1)-1-:CBUS_S_ID_W]          = cbus_s_bid[slv_idx];
            assign cbus_s_bresp_flat[CBUS_RESP_W*(slv_idx+1)-1-:CBUS_RESP_W]        = cbus_s_bresp[slv_idx];
            assign cbus_s_bvalid_flat[slv_idx]                                      = cbus_s_bvalid[slv_idx];
            assign cbus_s_arready_flat[slv_idx]                                     = cbus_s_arready[slv_idx];
            assign cbus_s_rid_flat[CBUS_S_ID_W*(slv_idx+1)-1-:CBUS_S_ID_W]          = cbus_s_rid[slv_idx];
            assign cbus_s_rdata_flat[CBUS_DATA_W*(slv_idx+1)-1-:CBUS_DATA_W]        = cbus_s_rdata[slv_idx];
            assign cbus_s_rresp_flat[CBUS_RESP_W*(slv_idx+1)-1-:CBUS_RESP_W]        = cbus_s_rresp[slv_idx];
            assign cbus_s_rlast_flat[slv_idx]                                       = cbus_s_rlast[slv_idx];
            assign cbus_s_rvalid_flat[slv_idx]                                      = cbus_s_rvalid[slv_idx];
            assign cbus_s_awid[slv_idx]                                             = cbus_s_awid_flat[CBUS_S_ID_W*(slv_idx+1)-1-:CBUS_S_ID_W];
            assign cbus_s_awaddr[slv_idx]                                           = cbus_s_awaddr_flat[CBUS_ADDR_W*(slv_idx+1)-1-:CBUS_ADDR_W];
            assign cbus_s_awburst[slv_idx]                                          = cbus_s_awburst_flat[CBUS_BURST_W*(slv_idx+1)-1-:CBUS_BURST_W];
            assign cbus_s_awlen[slv_idx]                                            = cbus_s_awlen_flat[CBUS_LEN_W*(slv_idx+1)-1-:CBUS_LEN_W];
            assign cbus_s_awsize[slv_idx]                                           = cbus_s_awsize_flat[CBUS_SIZE_W*(slv_idx+1)-1-:CBUS_SIZE_W];
            assign cbus_s_awvalid[slv_idx]                                          = cbus_s_awvalid_flat[slv_idx];
            assign cbus_s_wdata[slv_idx]                                            = cbus_s_wdata_flat[CBUS_DATA_W*(slv_idx+1)-1-:CBUS_DATA_W];
            assign cbus_s_wlast[slv_idx]                                            = cbus_s_wlast_flat[slv_idx];
            assign cbus_s_wvalid[slv_idx]                                           = cbus_s_wvalid_flat[slv_idx];
            assign cbus_s_bready[slv_idx]                                           = cbus_s_bready_flat[slv_idx];
            assign cbus_s_arid[slv_idx]                                             = cbus_s_arid_flat[CBUS_S_ID_W*(slv_idx+1)-1-:CBUS_S_ID_W];
            assign cbus_s_araddr[slv_idx]                                           = cbus_s_araddr_flat[CBUS_ADDR_W*(slv_idx+1)-1-:CBUS_ADDR_W];
            assign cbus_s_arburst[slv_idx]                                          = cbus_s_arburst_flat[CBUS_BURST_W*(slv_idx+1)-1-:CBUS_BURST_W];
            assign cbus_s_arlen[slv_idx]                                            = cbus_s_arlen_flat[CBUS_LEN_W*(slv_idx+1)-1-:CBUS_LEN_W];
            assign cbus_s_arsize[slv_idx]                                           = cbus_s_arsize_flat[CBUS_SIZE_W*(slv_idx+1)-1-:CBUS_SIZE_W];
            assign cbus_s_arvalid[slv_idx]                                          = cbus_s_arvalid_flat[slv_idx];
            assign cbus_s_rready[slv_idx]                                           = cbus_s_rready_flat[slv_idx];
        end
    endgenerate
`ifdef SILICON_DEBUG
    // assign debug_0 = 1'b1;
    assign dvp_href_2   = rx;
    // assign dvp_vsync_2  = tx;
    assign dvp_vsync_2  = tx;
    // assign dvp_pclk_2   = dvp_pclk_i;
    // assign dvp_xclk_2   = dvp_xclk_o;
    // assign dvp_d_i_0    = dvp_d_i[0];
    // assign dvp_d_i_1    = dvp_d_i[1];
`endif
endmodule