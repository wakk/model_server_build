ARG BASE_IMAGE=registry.us-west-1.aliyuncs.com/xiumaozhi/github_ovms:2
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


ARG ov_use_binary=0
ARG DLDT_PACKAGE_URL
ARG OPENVINO_NAME=${DLDT_PACKAGE_URL}
ARG ov_source_branch=master

WORKDIR /openvino/build
RUN if [ "$ov_use_binary" == "0" ] ; then true ; else exit 0 ; fi ; make --jobs=$JOBS
RUN if [ "$ov_use_binary" == "0" ] ; then true ; else exit 0 ; fi ; make install
RUN if [ "$ov_use_binary" == "0" ] ; then true ; else exit 0 ; fi ; \
    mkdir -p /opt/intel/openvino/extras && \
    mkdir -p /opt/intel/openvino && \
    ln -s /openvino/inference-engine/temp/opencv_*_ubuntu20/opencv /opt/intel/openvino/extras && \
    ln -s /usr/local/runtime /opt/intel/openvino && \
    ln -s /openvino/scripts/setupvars/setupvars.sh /opt/intel/openvino/setupvars.sh
################## END OF OPENVINO SOURCE BUILD ######################
