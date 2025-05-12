MAIN_PROG:
#####################################################
######### Set up the Interrupt Environment ##########
#####################################################
#   x4: temporary value
#   x5: temporary value
    addi x4, x0, 0xff0  # Use 4 interrupt sources
    maskirq x5, x4      # Set the interrupt mask
#####################################################
##### Global variable :v (used 3 GP regsiters) ######
#####################################################
    addi x13, x0, 1     # 1-RGB || 0-Gray
    addi x14, x0, 320   # Width of output frame
    addi x15, x0, 240   # Height of output frame
#####################################################
####### Configure the SCCB Master Controller ########
#####################################################
#   x4: temporary value
#   x5: store the CONTROL_BUF address:      0x6000_0010 
#   x6: store the SUB_ADDR_BUF address:     0x6000_0011
#   x7: store the WRITE_DATA_BUF address:   0x6000_0012
# 0. Configure SLV_DVC_ADDR register with value 0x23
    lui x5, 0x60000
    addi x5, x5, 0x00
    addi x4, x0, 0x23
    sb x4, 0(x5)
# 1. Setup address value
    lui x5, 0x60000      
    addi x5, x5, 0x10   # x5: 0x6000_0010 (CONTROL_BUF address)
    addi x6, x5, 0x01   # x6: 0x6000_0011 (SUB_ADDR_BUF address)
    addi x7, x5, 0x02   # x7: 0x6000_0012 (WRITE_DATA_BUF address)
# 2. Soft-reset
    addi x4, x0, 0x12
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x12)
    addi x4, x0, 0b10000000
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x80)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 3. Wait for 1 ms (BOUNDARY = CLK_FREQ/(1/(10^(-3))) / 25)
    lui x8, 0x0010  # 125Mhz: 0x1388 (0d5000)
FLAG0:
    addi x8, x8, -0x01
    bne x8, x0, FLAG0
# 4. COM7 (***Same***)
    addi x4, x0, 0x12
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x12)
    addi x4, x0, 0b00000100
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x04)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 5. CLKRC
    addi x4, x0, 0x11
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x11)
    addi x4, x0, 0b11000000
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0xC0)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 6. COM15 (***Same***)
    addi x4, x0, 0x40
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x40)
    addi x4, x0, 0b11010000
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0xD0)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 7. COM13 (0x3D)
    addi x4, x0, 0x3D
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x3D)
    addi x4, x0, 0x00
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x81)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 7. COM14 (0x3E)
    addi x4, x0, 0x3E
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x3D)
    addi x4, x0, 0x00
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x81)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 8. AWBCTR0 (0x6F)
    addi x4, x0, 0x6F
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x6F)
    addi x4, x0, 0x9F
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x9F)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# # 9. RSVD (0xB0 - 0x84)
#     addi x4, x0, 0xB0
#     sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0xB0)
#     addi x4, x0, 0x84
#     sb x4, 0(x7)        # Add write data of a SCCB transmission (0x84)
#     addi x4, x0, 0b00000111
#     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# # 10. CHLF (0x33 - 0x0B)
#     addi x4, x0, 0x33
#     sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x33)
#     addi x4, x0, 0x0B
#     sb x4, 0(x7)        # Add write data of a SCCB transmission (0x0B)
#     addi x4, x0, 0b00000111
#     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 11. COM8 -> Enable AGC / AEC  --- New config (enable AWB)
    addi x4, x0, 0x13   
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission
    addi x4, x0, 0x00   # Dat change previous e7
    sb x4, 0(x7)        # Add write data of a SCCB transmission
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 12. NALG -> Select Histogram-based AEC algorithm
#    addi x4, x0, 0xAA
#    sb x4, 0(x6)        # Add sub-address of a SCCB transmission
#    addi x4, x0, 0x14
#    sb x4, 0(x7)        # Add write data of a SCCB transmission
#    addi x4, x0, 0b00000111
#    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 13. GAIN -> Set gain reg to 0 for AGC
    addi x4, x0, 0x00
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission
    addi x4, x0, 0x60
    sb x4, 0(x7)        # Add write data of a SCCB transmission
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 14. AECH
    addi x4, x0, 0x10
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission
    addi x4, x0, 0xA0
    sb x4, 0(x7)        # Add write data of a SCCB transmission
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# # 15. Magic configuration (from a recommandation on Github)
#     addi x4, x0, 0x0D
#     sb x4, 0(x6)        # Add sub-address of a SCCB transmission
#     addi x4, x0, 0x40
#     sb x4, 0(x7)        # Add write data of a SCCB transmission
#     addi x4, x0, 0b00000111
#     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 16. COM9 -> 16x gain AEC (New configuration)
    addi x4, x0, 0x14
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission
    addi x4, x0, 0x00
    sb x4, 0(x7)        # Add write data of a SCCB transmission
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# # 17. AECGMAX
#     addi x4, x0, 0xA5
#     sb x4, 0(x6)        # Add sub-address of a SCCB transmission
#     addi x4, x0, 0x05
#     sb x4, 0(x7)        # Add write data of a SCCB transmission
#     addi x4, x0, 0b00000111
#     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# # 18. GFIX
#     addi x4, x0, 0x69
#     sb x4, 0(x6)        # Add sub-address of a SCCB transmission
#     addi x4, x0, 0x06
#     sb x4, 0(x7)        # Add write data of a SCCB transmission
#     addi x4, x0, 0b00000111
#     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# # 19. COM11 -> Set [1] to reduce light effect
#     addi x4, x0, 0x3B
#     sb x4, 0(x6)        # Add sub-address of a SCCB transmission
#     addi x4, x0, 0x00
#     sb x4, 0(x7)        # Add write data of a SCCB transmission
#     addi x4, x0, 0b00000111
#     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 20. COM1 
     addi x4, x0, 0x04
     sb x4, 0(x6)        # Add sub-address of a SCCB transmission
     addi x4, x0, 0x00
     sb x4, 0(x7)        # Add write data of a SCCB transmission
     addi x4, x0, 0b00000111
     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 21. Matrix coef 1
    addi x4, x0, 0x4F
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x12)
    addi x4, x0, 0xB3
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x04)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 22. Matrix coef 2
    addi x4, x0, 0x50
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x12)
    addi x4, x0, 0xB3
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x04)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 23. Matrix coef 3
    addi x4, x0, 0x51
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x12)
    addi x4, x0, 0x00
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x04)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 24. Matrix coef 4
    addi x4, x0, 0x52
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x12)
    addi x4, x0, 0x3D
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x04)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 25. Matrix coef 5
    addi x4, x0, 0x53
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x12)
    addi x4, x0, 0xA7
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x04)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 26. Matrix coef 6
    addi x4, x0, 0x54
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x12)
    addi x4, x0, 0xE4
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x04)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 27. 0x55 -- BRIGHTNESS
    addi x4, x0, 0x55
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x12)
    addi x4, x0, 0x10
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x04)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 27. 0x56 -- CONTRAST
    addi x4, x0, 0x56
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x12)
    addi x4, x0, 0x50
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x04)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 11. Wait for all SCCB transactions to send
FLAG_1:
    lb x4, 0(x5)
    bne x4, x0, FLAG_1

#####################################################
######### Configure the DBI TX Controller ###########
#####################################################
# 0.Change mode of the controller to CONFIG mode
    lui x5, 0x20000
    addi x4, x0, 0x01 
    sb x4, 0(x5)
# Setup address value
    lui x5, 0x20000
    addi x5, x5, 0x10           # x5: 0x2000_0010 (TX_TYPE address)
    addi x6, x5, 0x01           # x6: 0x2000_0011 (TX_COM Address)
    addi x7, x5, 0x02           # x5: 0x2000_0012 (TX_DATA Address)
# 1. HW-RST Command
    addi x4, x0, 0b00000010     # x4: 0x02          (HW_RST) 
    sb x4, 0(x5)                # Add HW-RST Command
# 2. Command: SW-RST
    addi x4, x0, 0b00000000     # x4: 0x02          (W-0DATA) 
    sb x4, 0(x5)                # Add TX_TYPE 
    addi x4, x0, 0x01            
    sb x4, 0(x6)                # Add Soft_RST Command
# 3. Wait for 6ms after Soft-reset transmission has been sent
FLAG_2:
    lb x4, 0(x5)                # x4: contain the number of remaining transmission
    bne x4, x0, FLAG_2          # Wait for Soft-reset transmission to send 
    lui x8, 0x0060              # Wait for 6 ms (BOUNDARY = CLK_FREQ/(1/(10^(-3))) / 25) 
FLAG_3:
    addi x8, x8, -0x01
    bne x8, x0, FLAG_3          # Time-out
# 4. Command: Memory Accress Control
    addi x4, x0, 0b00000100     # x4: 0x04          (W-1DATA) 
    sb x4, 0(x5)                # Add W-1DATA to TX_TYPE
    addi x4, x0, 0x36           # x4: 0x36          (MemAcs Command) 
    sb x4, 0(x6)                # Add MemAcs Command to TX_TYPE
    addi x4, x0, 0x20           # x4: 0x20          (MemAcs Data 1) 
    sb x4, 0(x7)                # Add WrData to TX_DATA
# 5. Command: Interface Pixel Format
    addi x4, x0, 0b00000100     # x4: 0x04          (W-1DATA) 
    sb x4, 0(x5)
    addi x4, x0, 0x3A           # x4: 0x3A          (Command) 
    sb x4, 0(x6)
    addi x4, x0, 0x55           # x4: 0x05          (Data 1: 16bit pxl) 
    sb x4, 0(x7)
# 5. Command: Set Column
    addi x4, x0, 0b00010000    # x4: 0x10          (W-4DATA) 
    sb x4, 0(x5)
    addi x4, x0, 0x2A           # x4: 0x2A          (SetCol Command) 
    sb x4, 0(x6)
    addi x4, x0, 0x00           # x4: 0x00          (SetCol Data 1 - SC[H]) 
    sb x4, 0(x7)
    addi x4, x0, 0x00           # x4: 0x50          (SetCol Data 2 - SC[L]) 
    sb x4, 0(x7)
    addi x4, x0, 0x01           # x4: 0x01          (SetCol Data 3 - EC[H]) 
    sb x4, 0(x7)
    addi x4, x0, 0x3F           # x4: 0x3F          (SetCol Data 4 - EC[L]) 
    sb x4, 0(x7)
# 6. Command: Set Row
    addi x4, x0, 0b00010000    # x4: 0x10          (W-4DATA) 
    sb x4, 0(x5)
    addi x4, x0, 0x2B           # x4: 0x2B          (SetRow Command) 
    sb x4, 0(x6)
    addi x4, x0, 0x00           # x4: 0x00          (SetRow Data 1 - SR[H]) 
    sb x4, 0(x7)
    addi x4, x0, 0x00           # x4: 0x00          (SetRow Data 2 - SR[L]) 
    sb x4, 0(x7)
    addi x4, x0, 0x00           # x4: 0x00          (SetRow Data 3 - ER[H]) 
    sb x4, 0(x7)
    addi x4, x0, 0xEF           # x4: 0xEF          (SetRow Data 4 - ER[L]) 
    sb x4, 0(x7)
# 7. Command: Sleep OUT
    addi x4, x0, 0b00000000    # x4: 0x02          (W-0DATA) 
    sb x4, 0(x5)
    addi x4, x0, 0x11           # x4: 0x11          (SLEEP_OUT Command)
    sb x4, 0(x6)
# 8. Wait for 6ms after Sleep-out transmission has been sent
FLAG_4:
    lb x4, 0(x5)                # x4: contain the number of remaining transmission
    bne x4, x0, FLAG_4          # Wait for Sleep-out transmission to send 
    lui x8, 0x0060              # Wait for 6 ms (BOUNDARY = CLK_FREQ/(1/(10^(-3))) / 25) 
FLAG_5:
    addi x8, x8, -0x01
    bne x8, x0, FLAG_5          # Time-out
# 9. Command: Display ON
    addi x4, x0, 0b00000000     # x4: 0x02          (W-0DATA) 
    sb x4, 0(x5)
    addi x4, x0, 0x29           # x4: 0x29          (DISP_ON Command)
    sb x4, 0(x6)
# DBI_FRAME_WIDTH register
    lui x5, 0x20000     # Base address of DBI TX Controller
    addi x6, x5, 0x02   # DBI_FRAME_WIDTH register address
    add x4, x0, x14     # Width of the display frame (stored in x14)
    sw x4, 0(x6)
# DBI_FRAME_HEIGHT register
    lui x5, 0x20000     # Base address of DBI TX Controller
    addi x6, x5, 0x03   # DBI_FRAME_HEIGHT register address
    add x4, x0, x15     # Height of the display frame (stored in x15)
    sw x4, 0(x6)
# DBI_MEM_COM register
    addi x5, x5, 0x01
    addi x4, x0, 0x2C   # x4: 0x2C - Memory Write command
    sb x4, 0(x5)
# CTRL_MODE register
    lui x5, 0x20000
    addi x4, x0, 0x02   # x4: 0x02 - change to STREAM mode encode
    sb x4, 0(x5)

#####################################################
######### Configure the DVP RX Controller ###########
#####################################################
# x4: Temporary (data)
# x5: DVP RX Controller's base address 
# x6: Temporary (reg address)
# x7: Number of word in a row
# Load DVP RX Controller's base address to register x5
    lui x5, 0x40000
# Calculate the number of word in a row with formula = (x14 * ((x13+1)*8) / 256)
    slli x7, x14, 3 # x7 = x14 * 8
    sll x7, x7, x13 # x7 = (x14 * 8) * (x13 + 1)
    srli x7, x7, 8  # x7 = ((x14 * 8) * (x13 + 1)) / 256
# CAM_RX_EN register
    addi x6, x5, 0x00 # Reg address: 0x4000_0000
    addi x4, x0, 0x01 # Enable the RX Controller
    sw x4, 0(x6)
# CAM_RX_MODE register
    addi x6, x5, 0x02 # Reg address: 0x4000_0002
    addi x4, x0, 0b00000010 # Set to Stream mode
    sw x4, 0(x6)
# IRQ_MASK register
    addi x6, x5, 0x03 # Reg address: 0x4000_0003
    addi x4, x0, 0b00000011 # Enable frame-completed & frame-error interrupt
    sw x4, 0(x6)
# IMG_WIDTH register
    addi x6, x5, 0x04 # Reg address: 0x4000_0004
    addi x4, x0, 640 # Set camera format - image width: 640
    sw x4, 0(x6)
# IMG_HEIGTH register
    addi x6, x5, 0x05 # Reg address: 0x4000_0004
    addi x4, x0, 480 # Set camera format - image column: 480
    sw x4, 0(x6)
# CAM_RX_START register
    addi x6, x5, 0x10 # Reg address: 0x4000_0010
    addi x4, x0, 0x01 # Set to Stream mode
    sw x4, 0(x6)

# Load DVP DMA Controller's base address to register x5
    lui x5, 0x50000
# DMA_CONTROL register
    addi x6, x5, 0x00 # Reg address: 0x5000_0000
    addi x4, x0, 0x01 # Enable the DVP DMA Controller
    sw x4, 0(x6)
# CHN_CONTROL register
    addi x6, x5, 0x01 # Reg address: 0x5000_0001
    addi x4, x0, 0x01 # Enable the Channel
    sw x4, 0(x6)
# CHN_FLAGS register
    addi x6, x5, 0x02 # Reg address: 0x5000_0002
    addi x4, x0, 0b00000011 # Enable 2D transfer & Cyclic transfer mode
    sw x4, 0(x6)
# CHN_IRQ_MASK register
    addi x6, x5, 0x03 # Reg address: 0x5000_0003
    addi x4, x0, 0b00000001 # Enable transfer-completed
    sw x4, 0(x6)
# CHN_ARBIT register
    addi x6, x5, 0x04 # Reg address: 0x5000_0004
    addi x4, x0, 0x01 # Enable the arbitration rate for the DMA (Just another enable register)
    sw x4, 0(x6)
# ATX_ID register
    addi x6, x5, 0x05 # Reg address: 0x5000_0005
    addi x4, x0, 0x01 # Set AxID of AXI Transaction to 0x01
    sw x4, 0(x6)
# ATX_DST_BURST register
    addi x6, x5, 0x07 # Reg address: 0x5000_0007
    addi x4, x0, 0x01 # Set Burst type to INCR mode
    sw x4, 0(x6)
# ATX_WD_PER_BURST  register
    addi x6, x5, 0x08 # Reg address: 0x5000_0008
    addi x4, x0, 15 # Set number of beats per transaction (16)
    sw x4, 0(x6)
# DST_ADDR register
    addi x6, x5, 0x0A # Reg address: 0x5000_000A
    lui x4, 0x00000   # Set destination address to 0x0000_0000
    addi x4, x0, 0x00 
    sw x4, 0(x6)
# TRANSFER_X_LEN register
    addi x6, x5, 0x0B # Reg address: 0x5000_000B
    addi x4, x7, -1   # = row_word_num - 1 
    sw x4, 0(x6)
# TRANSFER_Y_LEN register
    addi x6, x5, 0x0C # Reg address: 0x5000_000C
    addi x4, x15, -1  # = height - 1
    sw x4, 0(x6)
# DST_STRIDE register
    addi x6, x5, 0x0E # Reg address: 0x5000_000E
    add x4, x0, x7    # = row_word_num
    sw x4, 0(x6)
# TRANSFER_SUBMIT register
    lui x6, 0x00001     # RW1S offset: 0x1000
    add x6, x5, x6      # RW1S_base_address = CHN1_base_address + RW1S_offset  
    addi x6, x6, 0x00   # register_address = RW1S_base_address + register_offset 
    addi x4, x0, 0x01    
    sw x4, 0(x6) 

#####################################################
####### Configure Direted-memory-access (DMA) #######
#####################################################
# x4: Temporary (data)
# x5: Temporary (address)
# x6: DMA base address
# x7: Channel 0 base address
# x8: Channel 1 base address
# Load DMA Controller's base address to register x6
    lui x6, 0x80000
# Load offset of channel 0 to x5
    addi x5, x0, 0x00   # For channel 0
    slli x5, x5, 4      # Convert to channel offset (chn_idx << 4)
# Load base address of channel 0 to x7
    add x7, x5, x6      # CHN0_base_address = DMA_base_address + CHN0_offset
# Load offset of channel 1 to x5
    addi x5, x0, 0x01   # For channel 1
    slli x5, x5, 4      # Convert to channel offset (chn_idx << 4)
# Load base address of channel 1 to x8
    add x8, x5, x6      # CHN1_base_address = DMA_base_address + CHN1_offset
# DMA_CONTROL register
    addi x5, x6, 0x00   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 0x01   # Enable the DMA Controller
    sw x4, 0(x5)
# CHN_CONTROL[0] register
    addi x5, x7, 0x01   # register_address = CHN0_base_address + register_offset 
    addi x4, x0, 0x01   # Enable the Channel
    sw x4, 0(x5)
# CHN_FLAGS[0] register
    addi x5, x7, 0x02   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 0x01   # Enable 2D transfer mode
    sw x4, 0(x5)
# CHN_IRQ_MASK[0] register
    addi x5, x7, 0x03   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 0x01   # Enable transfer-completed
    sw x4, 0(x5)
# CHN_ARBIT_RATE[0] register
    addi x5, x7, 0x04   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 3      # Set arbitration rate of channel[0] to 3
    sw x4, 0(x5)
# ATX_ID[0] register
    addi x5, x7, 0x05   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 0x00   # Set ID of transaction's channel 0
    sw x4, 0(x5)
# ATX_SRC_BURST[0] register
    addi x5, x7, 0x06   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 0x01   # Set burst type: INCR
    sw x4, 0(x5)
# ATX_WD_PER_BURST[0] register
    addi x5, x7, 0x08   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 15     # Set number of words per burst: 16 words 
    sw x4, 0(x5)
# SRC_ADDR[0] register
    addi x5, x7, 0x09   # register_address = DMA_base_address + register_offset 
    lui x4, 0x00000     # Set source address IGMEM (Base address: 0x0000_0000)
    addi x4, x0, 0x00    
    sw x4, 0(x5)
# DST_TDEST[0] register
    addi x5, x7, 0x0A   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 0x00   # TDEST_MASK for DBI TX Controller  
    sw x4, 0(x5)
# TRANSFER_X_LEN[0] register
    addi x5, x7, 0x0B   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 9     
    sw x4, 0(x5)
# TRANSFER_Y_LEN[0] register
    addi x5, x7, 0x0C   # register_address = DMA_base_address + register_offset 
    addi x4, x15, -1    
    sw x4, 0(x5)
# SRC_STRIDE[0] register
    addi x5, x7, 0x0D   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 10    
    sw x4, 0(x5) 
# # TRANSFER_SUBMIT[0] register
#     lui x5, 0x00001     # RW1S offset: 0x1000
#     add x5, x5, x7      # RW1S_base_address = CHN0_base_address + RW1S_offset  
#     addi x5, x5, 0x00   # register_address = RW1S_base_address + register_offset 
#     addi x4, x0, 0x01    
#     sw x4, 0(x5) 

    
# CHN_CONTROL[1] register
    addi x5, x8, 0x01   # register_address = CHN1_base_address + register_offset 
    addi x4, x0, 0x01   # Enable the Channel
    sw x4, 0(x5)
# CHN_FLAGS[1] register
    addi x5, x8, 0x02   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 0x01   # Enable 2D transfer mode
    sw x4, 0(x5)
# CHN_IRQ_MASK[1] register
    addi x5, x8, 0x03   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 0x01   # Enable transfer-completed
    sw x4, 0(x5)
# CHN_ARBIT_RATE[1] register
    addi x5, x8, 0x04   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 7      # Set arbitration rate of channel[1] to 3
    sw x4, 0(x5)
# ATX_ID[1] register
    addi x5, x8, 0x05   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 0x01   # Set ID of transaction's channel 1
    sw x4, 0(x5)
# ATX_SRC_BURST[1] register
    addi x5, x8, 0x06   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 0x01   # Set burst type: INCR
    sw x4, 0(x5)
# ATX_WD_PER_BURST[1] register
    addi x5, x8, 0x08   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 15     # Set number of words per burst: 16 words 
    sw x4, 0(x5)
# SRC_ADDR[1] register
    addi x5, x8, 0x09   # register_address = DMA_base_address + register_offset 
    lui x4, 0x00000     # Set source address IGMEM (Base address: 0x0000_0000)
    addi x4, x0, 0x00    
    sw x4, 0(x5)
# DST_TDEST[1] register
    addi x5, x8, 0x0A   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 0x01   # TDEST_MASK for Image Processor  
    sw x4, 0(x5)
# TRANSFER_X_LEN[1] register
    addi x5, x8, 0x0B   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 9     
    sw x4, 0(x5)
# TRANSFER_Y_LEN[1] register
    addi x5, x8, 0x0C   # register_address = DMA_base_address + register_offset 
    addi x4, x15, -1    
    sw x4, 0(x5)
# SRC_STRIDE[1] register
    addi x5, x8, 0x0D   # register_address = DMA_base_address + register_offset 
    addi x4, x0, 10    
    sw x4, 0(x5) 
# # TRANSFER_SUBMIT[1] register
#     lui x5, 0x00001     # RW1S offset: 0x1000
#     add x5, x5, x8      # RW1S_base_address = CHN1_base_address + RW1S_offset  
#     addi x5, x5, 0x00   # register_address = RW1S_base_address + register_offset 
#     addi x4, x0, 0x01    
#     sw x4, 0(x5) 
    


#####################################################
####################### EXIT ########################
#####################################################
EXIT:
    beq x0, x0, EXIT