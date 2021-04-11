#!/bin/bash

DEVICE=${1:-/dev/ttyACM1}
sudo sh -c 'docker run --rm -i --device='$DEVICE':/dev/ttyUSB0 --user $(id -u):$(id -g) -t -v $PWD:/home/gforth microcore/gforth_062:latest'
