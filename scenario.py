"""
    random input data generator:
        - generate random data to be fed to testbench and store it in "scenario.in"
        - store reference data to be compared with testbench output (msg_data, msg_length) in "scenario.ref"
"""

import random
import sys

random.seed(10)

min_msg_length = 8
max_msg_length = 32
max_pkt_length = 1500
max_nb_msg = 40

# generate random of manual data
gen_rand = True
if len(sys.argv) > 1:
    gen_rand = int(sys.argv[1])
if not gen_rand:
    print ("> INFO: generate manual data")
else:
    print ("> INFO: generate random data")
    
# manual stress test
# list of packets and their message lengths
gen_man     = [[8], 
               [8], 
               [8], 
               [16],
               [16],
               [16],
               [32], 
               [32], 
               [32], 
               [8, 8, 8, 8, 8],
               [16, 16, 16, 16, 16], 
               [32, 32, 32, 32, 32],
               [8, 16, 24, 32, 24, 16, 8],
               [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32]]

file_in = open("scenario.in", "w")
file_ref = open("scenario.ref", "w")

"""
    convert integer x into n size hex string 
    example: int_to_str(15, 4) = "000F"
"""
def int_to_str(x, n):
    s = hex(x)[2:]
    d = n - len(s)
    if d > 0:
        return '0'*d + s
    else:
        return s


if gen_rand:
    nb_pkt = 25
else:
    nb_pkt = len(gen_man)

for i in range(0, nb_pkt):

    # packet is emptied  
    data = ""
    
    # random number of messages in packet
    nb_msg = 0
    if gen_rand: 
        nb_msg = random.randint(1, max_nb_msg)
    else:
        nb_msg = len(gen_man[i])
    
    # push msg_count
    data = int_to_str(nb_msg, 4)
    
    # for each message in packet
    for j in range(0, nb_msg):
    
        # message is emptied
        msg = ""
        if gen_rand:
            msg_length = random.randint(min_msg_length, max_msg_length)
        else:
            msg_length = gen_man[i][j]
        
        # push msg_length
        data = int_to_str(msg_length, 4) + data

        # Generate msg_length bytes random data
        for k in range(0, msg_length):
            rand_byte = hex(random.randint(0, 15))[2:] + hex(random.randint(0, 15))[2:]
            
            # push byte per byte
            data = rand_byte + data
            msg = rand_byte + msg
            
        # write message + message size in reference file
        file_ref.write((2*max_msg_length-len(msg))*'0' + msg.upper() + int_to_str(msg_length, 4).upper() + "\n")
            
        # split message into 64 bits words
        while len(data) > 16:
            # write 64 bits word, valid, keep, last info in input file  
            file_in.write("1 0 " + data[-16:] + " " + hex(int('11111111', 2))[2:] + " 0\n")
            
            # pop the written 64 bits from data
            data = data[0: len(data)-16]
            
        # last message of packet: left pad leftover data with zeros and write info in input file
        if (j == nb_msg-1):
            file_in.write("1 1 " + '0'*(16-len(data)) + data + " " + int_to_str(int(int((16-len(data))/2)*'0'+int(len(data)/2)*'1', 2), 2) + " 0\n")
            
file_in.close()
file_ref.close()