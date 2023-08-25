# axi_stream_insert_header

## 思路
    有几个关键的状态需要用reg保存
    1、本次传输是否已经发了header，否则是无法开始传输的
       也就是说如果data先到，可以先进buffer，但也得等到header有效才能输出

    2、是否已经收到了tlast? 指示这本次传输将要结束
       可以用于区分两次传输之间的状态，在收到tlast之后收到的data，在本次传输结束前不能输出
    
    3、输出是否有尾巴？
       这个状态用于判断在已经收到header和tlast的时候，在输出时判断concat_data中是否还有剩余的数据，如果没有就输出tlast，如果有则在下一拍输出时才输出tlast

    header和data输入握手时都会进入buffer

    根据前后关系，会有三种情况
    HEAD先到，可以直接放到concat_buffer里的高位
    HEAD和DATA同时到，拼接后放到concat_buffer里
    DATA先到，放到DATA_buffer里，等到HEAD来了之后一起放到concat_buffer里(concat_buffer是直接关系到输出的，处理好了才放进去，data不能提前放进去)

    放完concat_buffer后
    常规的情况是HEAD和DATA拼接起来足够输出的位数，那么就会输出concat_buffer的高位
    如果输出握手了，那么res_buffer就会取出concat_buffer的地位

    如此之后，HEAD已经发过，因此拼接时就是拼接res_buffer和新来的数据

    如此往复，直到收到DATA的tlast信号
    当最后一拍DATA放入concat_buffer时，需要判断一下是否有小尾巴

    无则直接输出tlast，有则等到下一次输出


    反压设计
        HEAD什么时候才能送进来？当我本次传输还没送过HEAD的时候 或 下一个次传输将要开始的时候，或者buffer为空的时候

        DATA什么时候才能送进来？ 当DATA_buffer为空的时候 或 当前正在输出下一拍数据的时候，并且这下一拍不能是下次传输的数据，


## 仿真

    添加了COCOTB作为tb的框架
    生成正确的输出ref
    理解send和recv的机制，将要送的一个package数据放在bytearray，再用AxiStreamFrame打包，这样send数据就会将bytearray按照位宽拆分送到axis总线上，自动再最后加上tlast
    而recv也是同理，每次recv会接收直到tlast，一个完整的数据包
    目前已经实现keep全为1的连续测试，需要完善测试样例
    包括keep不完整的情况，握手不连续的情况

    model中实现了此模块的软件参考模型，将生成的序列进行了参数化，方便输入能够遍历各种情况，实现难度在于需要和AxiStreamFrame所需的格式对齐(补零)，并考虑硬件的对齐情况，需要完成大小端的转换，包括keep信号的生成

    加入了consistent连续性的测试，数据只要有就会送进来

