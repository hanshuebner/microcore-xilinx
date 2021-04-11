# microcore-xilinx

This directory contains an adaption of the microCore CPU for Xilinx
FPGAs.  microCore has been developed by Klaus Schleisiek, please see
his [repository](https://github.com/microCore-VHDL/microCore) for
documentation and license information.

At this point, this repository a version of the core for the ancient
Spartan-3A Evaluation Kit from Digilent and one for the Papilio Pro
Spartan-6 board.

To build the core, you need a Linux system with an installation of ISE
14.7 WebPack.  You'll need to have the ISE command line utilities in
your path.  If your ISE installation is in a non-standard location,
please adapt the XILINX variable in the Makefile.

To build the core, type

    make

To upload the bit file to the FPGA, use

    make prog

You will need to have the programming utility (i.e. avs3a or
papilio-prog) in your path for the `prog` step to work.

When the bit file has been uploaded to the FPGA, the LED or LEDs will
blink in a distinctive pattern.  You can then start by testing the
core.  For that, you'll need to have a
[Docker](https://docs.docker.com/engine/install/) installation in
order to be able to run the cross compiler, which depends on a
slightly outdated version of Gforth.

When you have installed Docker, pull the gforth 0.6.2 image that is
required to host the cross compiler:

    docker pull microcore/gforth_062

With the Docker image downloaded, you can run the
[./gforth062.sh](./gforth062.sh) script.  The path to the umbilical
serial port of the microcore can be provided as the argument.  For the
Spartan-3A evaluation kit, this will be /dev/ttyACM1, which is the
default.

Gforth will start in with the working directory set to
[software/](./software/).  At the prompt, type

    include load_core.fs

to load and cross compile the testing firmware.  Then, type

    run

to connect to microcore.  If all goes well, the `uCore>` prompt will
be shown, indicating that you're talking to the forth interpreter
running on the FPGA.


Enter

    coretest

This will execute the core test. If all goes well, 0 will be
displayed. Any other number is an error code, which can be searched
for in [coretest.fs](./software/coretest.fs).
