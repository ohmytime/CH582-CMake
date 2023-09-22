#!/bin/sh

if [ -d "build/" ]; then
    echo "Found build/, start building."
    cd build
    cmake -GNinja ..
    ninja
else
    echo "Not Found build/, we will create it."
    mkdir build
    cd build
    cmake -GNinja ..
    ninja
fi
