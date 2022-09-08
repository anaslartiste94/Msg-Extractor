
.
├── README.txt
├── msg_parser.sv         # parser interface
├── msg_parser.vhd        # VHDL message parser
├── scenario.py           # random/stress scenario generator 
├── scenarios
│   ├── random_test
│   │   ├── scenario.in   # random generated scenario
│   │   └── scenario.ref  # reference to compare with simulation output
│   ├── scenario.out      # simulation output of the given sample scenario
│   └── stress_test
│       ├── scenario.in   # stress test generated from scenario.py
│       └── scenario.ref  # reference to compare with simulation output
└── testbench.vhd         # VHDL testbench
