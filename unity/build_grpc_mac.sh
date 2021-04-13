#!/bin/bash
# make sure an argument is passed
set -o xtrace

# apply the compiler flag patch to boringssl
# assume we are in the repository root
pushd third_party/boringssl/
git apply ../../unity/bssl-01.patch
popd

for arch in x86_64 arm64; do
    # start building with cmake
    # https://grpc.io/docs/languages/cpp/quickstart/
    rm -rf cmake/build
    mkdir -p cmake/build
    pushd cmake/build
    cmake -DgRPC_BUILD_TESTS=off -DCMAKE_OSX_ARCHITECTURES=$arch -DCMAKE_CROSSCOMPILING=1 -DRUN_HAVE_STD_REGEX=0 -DRUN_HAVE_POSIX_REGEX=0 ../..
    make -j
    popd
    
    # copy the file we want into the artifacts folder
    mkdir -p artifacts/grpc_$arch/
    mv cmake/build/libgrpc_csharp_ext.dylib artifacts/grpc_$arch/libgrpc_csharp_ext.dylib
done

mkdir -p artifacts/grpc_universal/
lipo -create -output artifacts/grpc_universal/libgrpc_csharp_ext.dylib artifacts/grpc_x86_64/libgrpc_csharp_ext.dylib artifacts/grpc_arm64/libgrpc_csharp_ext.dylib
codesign -s - -f artifacts/grpc_universal/libgrpc_csharp_ext.dylib
