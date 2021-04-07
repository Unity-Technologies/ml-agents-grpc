#!/bin/bash
# make sure an argument is passed
if [ -z "$1" ]
  then
    echo "No argument supplied.  Expected 'arm64' or 'x86_64'"
    exit 1
fi

set -o xtrace


# apply the compiler flag patch to boringssl
# assume we are in the repository root
pushd third_party/boringssl/
git apply ../../unity/bssl-01.patch
popd

# start building with cmake
# https://grpc.io/docs/languages/cpp/quickstart/
mkdir -p cmake/build
pushd cmake/build
cmake -DgRPC_BUILD_TESTS=off ../..
make -j
popd

# copy the file we want into the artifacts folder
mkdir -p artifacts/grpc_$1/
mv cmake/build/libgrpc_csharp_ext.dylib artifacts/grpc_$1/libgrpc_csharp_ext.dylib

