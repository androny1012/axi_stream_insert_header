import random
import numpy as np

def random_int_list(start, stop, length):
    start, stop = (int(start), int(stop)) if start <= stop else (int(stop), int(start))
    length = int(abs(length)) if length else 0
    random_list = []
    for i in range(length):
        random_list.append(random.randint(start, stop))
    return random_list

def endian_trans(body_data, byte_lanes):
    length = int(len(body_data)/4)
    body_data = np.array(np.flipud(body_data)).reshape(length,byte_lanes)
    body_data = np.flipud(body_data).reshape(length*byte_lanes)
    return body_data

def genInsertHeaderData(byte_lanes, length, head_bytenum):

    # 先生成随机长度的序列
    gen_random_data = random_int_list(0,255,length)

    #取出随机长度1-4字节的HEAD
    # head_bytenum = random.randint(1, (length-1) if byte_lanes > (length-1) else byte_lanes) # head byte数随机
    head_data = gen_random_data[0:head_bytenum] + [0]*(byte_lanes - head_bytenum)           # align 是COCOTB AXI需求
    head_tkeep = [1]*head_bytenum + [0]*(byte_lanes - head_bytenum)                         # align

    body_bytenum = length - head_bytenum                                          # 除去HEAD，剩下的就是BODY
    add_zeronum = (int((body_bytenum-1)/byte_lanes)+1)*byte_lanes - body_bytenum  # align
    body_data = gen_random_data[head_bytenum:] + [0]*(add_zeronum)
    body_tkeep = [1]*(length - head_bytenum) + [0]*(add_zeronum)

    # head内部转后合并,输出的不转
    # 转换大小端
    head_data_et  = endian_trans(head_data, byte_lanes)
    head_tkeep_nz = endian_trans(head_tkeep, byte_lanes)
    # 排除无效字节
    keep_index    = np.where(head_tkeep_nz==1)
    head_data_nz  = head_data_et[keep_index].tolist()

    # body转完送出,内部不转,定义和head相反
    # 转换大小端
    body_data_et  = endian_trans(body_data, byte_lanes)
    body_data     = endian_trans(body_data_et, byte_lanes)
    body_tkeep_et = endian_trans(body_tkeep, byte_lanes)
    body_tkeep_o  = endian_trans(body_tkeep_et, byte_lanes)
    # 排除无效字节
    keep_index = np.where(body_tkeep_o==1)
    body_data_nz = body_data[keep_index].tolist()

    # 合并得Insert后结果,但需要endian_trans
    ref_data = head_data_nz + body_data_nz

    ref_add_zeronum = (int((len(ref_data)-1)/byte_lanes)+1)*byte_lanes - len(ref_data)
    ref_tkeep = np.asarray(len(ref_data)*[1] + ref_add_zeronum*[0])
    ref_tkeep = endian_trans(ref_tkeep, byte_lanes)

    ref_data = ref_data + ref_add_zeronum*[0]
    ref_data = endian_trans(ref_data, byte_lanes)
    keep_index = np.where(ref_tkeep==1)
    ref_data = ref_data[keep_index].tolist()
    ref_byte = bytearray(ref_data)

    Verbose = False
    if(Verbose):
        print("head_data   :",head_data)
        print("head_tkeep  :",head_tkeep)
        print("head_data_nz:",head_data_nz)
        print("body_data   :",body_data)
        print("body_tkeep  :",body_tkeep)
        print("body_data_nz:",body_data_nz)

    return head_data, head_tkeep, body_data_et.tolist(), body_tkeep_et.tolist(), ref_byte

if __name__ == "__main__":
    random.seed(7)
    byte_lanes = 4
    length = random.randint(2,16) # 必须大于2
    head_bytenum = random.randint(1, (length-1) if byte_lanes > (length-1) else byte_lanes) # head byte数随机
    head_data, head_tkeep, body_data, body_tkeep, ref_byte = genInsertHeaderData(byte_lanes, length, head_bytenum)