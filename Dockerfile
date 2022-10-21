ARG BASE_IMAGE=xiumaozhi/openvino:first_1
FROM $BASE_IMAGE as base_build

LABEL version="1.0.0"

ARG INSTALL_DIR=/opt/intel/openvino
ARG INSTALL_DIR=/opt/intel/openvino
ARG TEMP_DIR=/tmp/openvino_installer
ARG DL_INSTALL_DIR=/opt/intel/openvino/deployment_tools
ARG DL_DIR=/tmp
ARG JOBS=5
ARG APT_OV_PACKAGE=openvino-2022.1.0

# build_type=[ opt, dbg ]
ARG build_type=dbg
ARG debug_bazel_flags=--strip=never\ --copt="-g"\ -c\ dbg
ARG minitrace_flags
ENV HDDL_INSTALL_DIR=/opt/intel/openvino/deployment_tools/inference_engine/external/hddl
ENV DEBIAN_FRONTEND=noninteractive
ENV TF_SYSTEM_LIBS="curl"
SHELL ["/bin/bash", "-c"]

# Set up Bazel
ENV BAZEL_VERSION 3.7.2


COPY third_party /ovms/third_party/

####### Azure SDK
WORKDIR /azure
RUN apt update && apt-get install -y uuid uuid-dev
RUN git clone https://github.com/Microsoft/cpprestsdk.git && cd cpprestsdk && git checkout tags/v2.10.18 -b v2.10.18 && git submodule update --init

RUN git clone https://github.com/Azure/azure-storage-cpp.git && cd azure-storage-cpp/Microsoft.WindowsAzure.Storage && git checkout tags/v7.5.0 && mkdir build.release

WORKDIR /
RUN cp -rf /ovms/third_party/cpprest/rest_sdk_v2.10.16.patch /azure/cpprestsdk/
RUN cd /azure/cpprestsdk/ && patch -p1 < rest_sdk_v2.10.16.patch
RUN cp -rf /ovms/third_party/azure/azure_sdk.patch /azure/azure-storage-cpp/
RUN cd /azure/azure-storage-cpp/ && patch -p1 < azure_sdk.patch
WORKDIR /azure

RUN cd cpprestsdk && mkdir Release/build.release && cd Release/build.release && cmake .. -DCMAKE_VERBOSE_MAKEFILE=ON -DCMAKE_CXX_FLAGS="-fPIC" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DBoost_USE_STATIC_RUNTIME=ON -DBoost_USE_STATIC_LIBS=ON -DWERROR=OFF -DBUILD_SAMPLES=OFF -DBUILD_TESTS=OFF && make --jobs=$JOBS install
RUN cd azure-storage-cpp/Microsoft.WindowsAzure.Storage/build.release && CASABLANCA_DIR=/azure/cpprestsdk cmake .. -DCMAKE_CXX_FLAGS="-fPIC" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DBoost_USE_STATIC_RUNTIME=ON -DBoost_USE_STATIC_LIBS=ON -DCMAKE_VERBOSE_MAKEFILE=ON && make --jobs=$JOBS && make --jobs=$JOBS install

####### End of Azure SDK

# Build AWS S3 SDK
RUN git clone https://github.com/aws/aws-sdk-cpp.git --branch 1.7.129 --single-branch --depth 1 /awssdk
WORKDIR /awssdk/build
RUN cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_ONLY=s3 -DENABLE_TESTING=OFF -DBUILD_SHARED_LIBS=OFF -DMINIMIZE_SIZE=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DFORCE_SHARED_CRT=OFF -DSIMPLE_INSTALL=OFF -DCMAKE_CXX_FLAGS=" -D_GLIBCXX_USE_CXX11_ABI=1 " ..
RUN make --jobs=$JOBS
#RUN mv .deps/install/lib64 .deps/install/lib

####### End of AWS S3 SDK

####### Build OpenCV
WORKDIR /ovms/third_party/opencv
RUN ./install_opencv.sh
####### End of OpenCV

ARG ov_use_binary=0
ARG DLDT_PACKAGE_URL
ARG OPENVINO_NAME=${DLDT_PACKAGE_URL}
ARG ov_source_branch=master

################### BUILD OPENVINO FROM SOURCE - buildarg ov_use_binary=0  ############################
# Build OpenVINO and nGraph (OV dependency) with D_GLIBCXX_USE_CXX11_ABI=0 or 1
RUN if [ "$ov_use_binary" == "0" ] ; then true ; else exit 0 ; fi ;  git clone https://github.com/openvinotoolkit/openvino /openvino ; cd /openvino ; git checkout $ov_source_branch; git submodule update --init --recursive
WORKDIR /openvino/build
RUN if [ "$ov_use_binary" == "0" ] ; then true ; else exit 0 ; fi ; cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_SAMPLES=0 -DNGRAPH_USE_CXX_ABI=1 -DCMAKE_CXX_FLAGS=" -D_GLIBCXX_USE_CXX11_ABI=1 -Wno-error=parentheses "  ..
