#!/bin/bash
sudo sh -c 'docker run --rm -i --device=/dev/ttyACM1:/dev/ttyUSB0 --user $(id -u):$(id -g) -t -v $PWD:/home/gforth microcore/gforth_062:latest'
