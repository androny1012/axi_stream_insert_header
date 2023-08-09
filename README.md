# axi_stream_insert_header

## TODO:
    初步调通，需要重写tb，目前参考了https://github.com/Leigaadik/axi_stream_insert_header

    0、HEADER没有0000的keep，HEAD和DATA可以先拼接再移位
    1、testbench，输入输出非常积极时能否没有气泡；随机的产生ready、valid，但符合握手，验证是否正确。(先建立握手框架driver)
    2、先用纯组合逻辑实现
    3、添加buffer，有1 cycle delay，2 cycle delay
    4、HEAD和DATA两通道应该是独立的，互不影响的，可以耦合，但反压不应该由另一个通道控制
    5、不凑时序，弄清楚握手
