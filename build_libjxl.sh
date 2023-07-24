#!/bin/bash

# As of July 2023 the latest libjxl release is v0.8.2.

git clone https://github.com/libjxl/libjxl.git --recursive --branch=v0.8.2
pushd libjxl

mkdir -p build
pushd build


CMAKE_OSX_ARCHITECTURES='x86_64;arm64' cmake -DJPEGXL_STATIC=true -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_OSX_DEPLOYMENT_TARGET='10.15' ..
CMAKE_OSX_ARCHITECTURES='x86_64;arm64' cmake --build . --target jxl-static -- -j
CMAKE_OSX_ARCHITECTURES='x86_64;arm64' cmake --build . --target jxl_threads-static -- -j

popd
popd

mkdir -p jpeg-xl/lib
mkdir -p jpeg-xl/include/jxl
cp -R libjxl/build/lib/libjxl*.a jpeg-xl/lib
cp libjxl/build/third_party/highway/libhwy.a jpeg-xl/lib

# Only need decoder, avoid copying the encoder library.
cp libjxl/build/third_party/brotli/libbrotlicommon-static.a jpeg-xl/lib/libbrotlicommon.a
cp libjxl/build/third_party/brotli/libbrotlidec-static.a jpeg-xl/lib/libbrotlidec.a

cp -R libjxl/build/lib/include/jxl/* jpeg-xl/include/jxl/
cp -R libjxl/lib/include/jxl/* jpeg-xl/include/jxl/
