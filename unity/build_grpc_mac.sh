#!/bin/bash
# make sure an argument is passed
set -o xtrace

# apply the compiler flag patch to boringssl
# assume we are in the repository root
pushd third_party/boringssl/ || exit
git apply ../../unity/bssl-01.patch
popd || exit

pushd third_party/protobuf/ || exit
git apply ../../unity/protobuf.patch
popd || exit

for arch in arm64 x86_64; do
    # start building with cmake
    # https://grpc.io/docs/languages/cpp/quickstart/
    rm -rf cmake/build
    mkdir -p cmake/build
    pushd cmake/build || exit
    cmake -DgRPC_BUILD_TESTS=1 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=$arch \
    -DCMAKE_CROSSCOMPILING=1 \
    -DRUN_HAVE_STD_REGEX=0 \
    -DRUN_HAVE_POSIX_REGEX=1 \
    -DRUN_HAVE_STEADY_CLOCK=0 \
    ../..
    make -j8
    popd || exit
    
    # copy the file we want into the artifacts folder
    mkdir -p artifacts/grpc_$arch/
    rm artifacts/grpc_$arch/libgrpc_csharp_ext.dylib
    cp cmake/build/libgrpc_csharp_ext.dylib artifacts/grpc_$arch/libgrpc_csharp_ext.dylib
done

mkdir -p artifacts/grpc_universal/
lipo -create -output artifacts/grpc_universal/libgrpc_csharp_ext.dylib artifacts/grpc_x86_64/libgrpc_csharp_ext.dylib artifacts/grpc_arm64/libgrpc_csharp_ext.dylib
codesign -s - -f artifacts/grpc_universal/libgrpc_csharp_ext.dylib
