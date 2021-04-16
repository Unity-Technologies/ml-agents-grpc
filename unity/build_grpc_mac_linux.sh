#!/bin/bash
# make sure an argument is passed
set -o xtrace

platform=$1
arches=${@:2}

if [ "$platform" != "win" ]; then
    # apply the compiler flag patch to boringssl
    # assume we are in the repository root
    pushd third_party/boringssl/ || exit
    git apply ../../unity/bssl-01.patch
    popd || exit
    
    pushd third_party/protobuf/ || exit
    git apply ../../unity/protobuf.patch
    popd || exit

    for arch in $arches; do
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
        mkdir -p artifacts/native/$platform/grpc_$arch/
        rm artifacts/native/$platform/grpc_$arch/libgrpc_csharp_ext.dylib
        cp cmake/build/libgrpc_csharp_ext.dylib artifacts/native/$platform/grpc_$arch/libgrpc_csharp_ext.dylib
    done
    
    if [ "$platform" == "mac" ]; then
        mkdir -p artifacts/native/$platform/grpc_universal/
        lipo -create -output artifacts/native/$platform/grpc_universal/libgrpc_csharp_ext.dylib \
            artifacts/native/$platform/grpc_x86_64/libgrpc_csharp_ext.dylib artifacts/native/$platform/grpc_arm64/libgrpc_csharp_ext.dylib

        codesign -s - -f artifacts/native/$platform/grpc_universal/libgrpc_csharp_ext.dylib
    fi
fi

dll_out="artifacts/managed/mac_linux/"
configuration="Release"
# Build Linux and Mac DLLs
if [ "$platform" == "win" ]; then
    dll_out="artifacts/dlls/win"
    configuration="Release_Win"
fi

rm -rf $dll_out
mkdir -p $dll_out
pushd src/csharp
dotnet build Grpc.Core/Grpc.Core.csproj --configuration $configuration --output ../../$dll_out
popd

