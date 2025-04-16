# axi-lite-slave
Generic AXI-LITE Slave IP

![image](https://github.com/user-attachments/assets/4fb6206b-6c79-4e9e-909d-1fe2b4a56829)
![image](https://github.com/user-attachments/assets/bec7d6e4-49c4-4383-9a43-0a29dfe0c86b)

Simple axi lite slave ip that has a simple memory attached to it.

Files inside of "parallel_r_w" can handle memory read access in parallel with write access. I will be adding a ringbuffer to the write-pipe so that commands/mem-access that take a while will not bog down read access.

Ultimately, the memory should be generalized and made more-simple using system verilog but I wanted to use vivado diagrams for this. So, this is a proof of concept. I'll be furthering this later.
