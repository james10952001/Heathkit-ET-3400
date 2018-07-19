# Heathkit-ET-3400
FPGA implementation of the Heathkit ET-3400 microprocessor trainer released in 1976.

There is a remaining bug that causes occasional glitches when updating the display, this may be related to the fact that the CPU68 core is not cycle accurate, and seems to be roughly twice as fast as a real 6800 at the same clock frequency. Other than that this is working quite well and all of the example programs I've tried do what they're supposed to do. This is set up so that a 3x6 matrix keypad can be connected, or a PS/2 keyboard can be used to interact with the trainer. A small collection of open source VHDL components from elsehwere has been included which can be interfaced to the processor just as if they were placed on the breadboard on the real trainer. 

If you wish to load programs without manually keying them in each time, the data can be placed in a file, converted to .hex format and loaded into the RAM entity in the FPGA IDE. 
