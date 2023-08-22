# axi_stream_insert_header

## TODO:
    初步调通，需要重写tb，目前参考了https://github.com/Leigaadik/axi_stream_insert_header

    0、HEADER没有0000的keep，HEAD和DATA可以先拼接再移位
    1、testbench，输入输出非常积极时能否没有气泡；随机的产生ready、valid，但符合握手，验证是否正确。(先建立握手框架driver)
    2、先用纯组合逻辑实现
    3、添加buffer，有1 cycle delay，2 cycle delay
    4、HEAD和DATA两通道应该是独立的，互不影响的，可以耦合，但反压不应该由另一个通道控制
    5、不凑时序，弄清楚握手

    添加了COCOTB作为tb的框架，但还没实现Keep信号的产生
    生成正确的输出ref - 
    理解send和recv的机制，将要送的一个package数据放在bytearray，再用AxiStreamFrame打包，这样send数据就会将bytearray按照位宽拆分送到axis总线上，自动再最后加上tlast
    而recv也是同理，每次recv会接收直到tlast，一个完整的数据包
    目前已经实现keep全为1的连续测试，需要完善测试样例
    包括keep不完整的情况，握手不连续的情况

    目前是纯组合逻辑的实现

    去掉的状态机的显式实现，给header加入了buffer


    HEAD_KEEP
        1111
        0111
        0011
        0001
    DATA_KEEP(last)
        1111
        1110
        1100
        1000
    
    HEAD_KEEP 1111
    DATA_KEEP 1111 1110

    HEAD_KEEP 0111
    DATA_KEEP 1111 1110   tail

    HEAD_KEEP 0011
    DATA_KEEP 1111 1110   tail

    HEAD_KEEP 0001
    DATA_KEEP 1111 1110 

    控制通路和数据通路分开

    数据流、带点状态机的思想，管理好状态变量
    if else if 条件互斥？

    综合一下三种电路
    加法
    case
    for循环移位
## 仿真
    model中实现了此模块的软件参考模型，将生成的序列进行了参数化，方便输入能够遍历各种情况，实现难度在于需要和AxiStreamFrame所需的格式对齐(补零)，并考虑硬件的对齐情况，需要完成大小端的转换，包括keep信号的生成