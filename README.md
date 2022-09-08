# Msg-Extractor

The diagram below shows the architecture of the message extractor.

![alt text](https://github.com/anaslartiste94/Msg-Extractor/blob/main/design_diagram.png)

The latency of the design is 2 cycles, and need to stall the ready one cycle between two messages of the same packet.

The design will work fine with min=8B ; max=256B. Only the ressources will increase in this case, since we will need bigger registers to store input words.

However the design can't work for min=1B. We only drop the ready one cycle because we assume a word can never contain more than one message. It is not the case anymore when min=1B. 

The path that may limit frequency can be the calculation of leftover_bytes, since there is an addition, a comparison and some "if" nested conditions.

