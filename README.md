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


## 数据流分析

    HEAD两种情况

    HEAD是1111，那么可以直接下一拍就发（m_ready反压），然后后续不用拼接？

    HEAD、DATA同时到，只取HEAD下一拍输出（m_ready反压），DATA进入res_buffer
    下一拍拿到DATA再和res里的拼接，拼接后取高位

    HEAD先到，不用等DATA？然后DATA来了直接透传
    DATA先到，那么一直存在DATA_buffer中，直到HEAD到，然后和同时到达一样


    HEAD非1111

    HEAD、DATA同时到，那么各取一部分下一拍输出（m_ready反压），DATA中的一部分进入res_buffer
    下一拍拿到DATA再和res里的拼接
    HEAD先到，那么要等DATA到，HEAD一直存在HEAD_buffer中，直到DATA到，然后和同时到一样了
    DATA先到，那么一直存在DATA_buffer中，直到HEAD到，然后和同时到一样了

    也就是说先处理好同时到的情况

    根据上面的描述，区分HEAD是否为1111其实很麻烦
    不如添加一个concat_buffer

    HEAD先到，直接下一拍放到concat_buffer里
    同时到，拼接后放到concat_buffer里
    DATA先到，放到DATA_buffer里，等到HEAD来了之后一起放到concat_buffer里(concat_buffer是输出的，处理好了才放进去，data不要提前放进去)
    
    HEAD似乎没有自己的buffer，直接用了concat_buffer

    怎么理解同时？

    反压设计
        HEAD什么时候才能送进来？当我本次传输还没送过HEAD的时候 或 下一个次传输将要开始的时候，m_last之后

        DATA什么时候才能送进来？ 当DATA_buffer为空的时候 或 当前正在输出下一拍数据的时候


    后续只要concat_buffer中前面有4个1，就可以送出去这些数据，

    m_ready反压 会出现什么情况
        本该输出的数据不能输出，那应该先存起来，存在哪？
        第一拍，收到HEAD和DATA，下一拍准备输出，并接收新的DATA，但下一拍反压，

    理论上，如果数据全都是下一拍就用到，是不用buffer的
    但会有两种情况，一是HEAD和DATA并不同时到，因此



    另一个思路，


    head需要buffer么？什么情况需要进入buffer，数据无法被及时消耗掉的时候
    也就是非1111，且data没有到的时候

    如果下一拍就输出，为什么不直接输出

    head在每次传输的开始有且仅有一次，因此只需要记录当前是否是传输的开始

    head不需要buffer？需要，因为head总有无法被及时消耗的情况，

    怎么描述消耗这件事？又没有deq

    用状态记录，发了head相当于消耗

    输出是寄存器

    如果HEAD和DATA同时到，那么两者拼接后寄存器输出

    如果DATA先到，那么DATA放到BUFFER里，等到HEAD后拼接寄存器输出
    如果HEAD先到，那么HEAD放到BUFFER里，等到DATA后拼接寄存器输出