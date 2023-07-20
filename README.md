# GPGPU
## Source Folder
1. 这个文件夹下存放的是GPU下所有Submodule的源文件， GPGPU_Top文件是最终的顶层文件，顶层文件中除了instantiate了GPU的所有submodule外，还放置了一个uart模块，用于FPGA片上测试。
2. 设计整体hierarchy：GPGPU_Top -> Warp_Scheduler、 Fetch、Decode、SIMT、I_Buffer_n_ScoreBoard、RAU、 Operand_Collector、 IU、RF、ALU_n_LdSt、EX_Issue_Unit_2.0。
3. Warp_Scheduler-> Grant2_RotatePoriority_Resolver
4. I_Buffer_n_ScoreBoard-> I_Buffer_Warp、 ScoreBoard_Warp(每个warp拥有一组)
5. SIMT-> SIMT_Warp(每个warp拥有一个)
6. Fetch-> Dual_Port_Bram,作为i_cache的mem部分
7. RF-> Single_Port_Bram、Req_FIFO(每个bank rf由一个single_port_bram组成并搭配一个Request fifo)
## Test Folder
1. IN1文件是warp scheduler中Task ram的初始化文件（十六进制），由于测试文件为在一个16x16的方格中画圆，因此分成256个thread,一个warp分配8个thread,因此总共32个task.因此文件中前32行MSB为1，表示valid task
2. IN2是I_cache初始文件
3. IN3是D_cache初始文件，这三个文件都是通过uart发送至上述module各自的mem中，FPGA运行结束后再将mem中内容发回，因此result_Test3中显示了GPU运行后D_cache中的内容，文件中一行256bit,8个word,16x16画圆因此将result_Test3中每两行重置为1行即可看到画出的圆形，展示在
