#!/bin/bash

# exit on failed command and show commands that are executed
set -oe xtrace

undo_patch_before_exit()
{
    WORKING_DIR=$(pwd)
    if [[ "$WORKING_DIR" =~ "ssl" ]]; then
        git checkout .
    elif [[ "$WORKING_DIR" =~ "cmake/build" ]]; then
        cd ../../third_party/boringssl/
        git checkout .
    else
        cd third_party/boringssl
        git checkout .
    fi
}

trap undo_patch_before_exit EXIT

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -d|--delete-artifacts)
    DELETE_ARTIFACTS="true"
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

platform=$1
arches=${@:2}

pushd third_party/boringssl/
git apply ../../unity/bssl-01.patch
popd

if [ "$DELETE_ARTIFACTS" == "true" ]; then
    rm -rf artifacts ||:
fi

file_extension=".dylib"
if [ "$platform" == "linux" ]; then
    file_extension=".so"
fi
built_file="libgrpc_csharp_ext$file_extension"

if [ "$platform" != "win" ]; then
    for arch in $arches; do
        # start building with cmake
        # https://grpc.io/docs/languages/cpp/quickstart/
        rm -rf cmake/build ||:
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
        make grpc_csharp_ext -j8
        popd || exit
        
        # copy the file we want into the artifacts folder
        mkdir -p artifacts/native/$platform/grpc_$arch/
        rm artifacts/native/$platform/grpc_$arch/$built_file ||:
        cp cmake/build/$built_file artifacts/native/$platform/grpc_$arch/$built_file
    done
    
    if [ "$platform" == "mac" ]; then
        mkdir -p artifacts/native/$platform/grpc_universal/
        lipo -create -output artifacts/native/$platform/grpc_universal/$built_file \
            artifacts/native/$platform/grpc_x86_64/$built_file artifacts/native/$platform/grpc_arm64/$built_file

        codesign -s - -f artifacts/native/$platform/grpc_universal/$built_file
    fi
fi

pushd third_party/boringssl/
git checkout .
popd

dll_out="artifacts/managed/mac_linux/"
configuration="Release"
# Build Linux and Mac DLLs
if [ "$platform" == "win" ]; then
    dll_out="artifacts/managed/win"
    configuration="Release_Win"
fi

# the mac and linux platform managed dlls are the same
# and it's not as easy to get dotnet on a linux machine
if [ "$platform" != "linux" ]; then
    rm -rf $dll_out ||:
    mkdir -p $dll_out
    pushd src/csharp
    dotnet --version
    dotnet build Grpc.Core/Grpc.Core.csproj --configuration $configuration --output ../../$dll_out
    popd
fi
