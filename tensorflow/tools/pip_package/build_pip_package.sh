#!/usr/bin/env bash
# Copyright 2015 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

# 设置Shell脚本执行失败时立即退出
set -e

# 判断路径是否为绝对路径
function is_absolute {
  [[ "$1" = /* ]] || [[ "$1" =~ ^[a-zA-Z]:[/\\].* ]]
}

# 获取路径的真实路径(转换相对路径为绝对路径)
function real_path() {
  is_absolute "$1" && echo "$1" || echo "$PWD/${1#./}"
}

# 复制外部依赖文件
# src_dir: tensorflow/bazel-bin/tensorflow/tools/pip_package/build_pip_package.runfiles/org_tensorflow/external/
# dest_dir: ${TMPDIR}/tensorflow/include/external
function cp_external() {
  local src_dir=$1
  local dest_dir=$2

  pushd .
  cd "$src_dir"
  # 遍历源目录,复制文件到目标目录,保持目录结构
  for f in `find . ! -type d ! -name '*.py' ! -path '*local_config_cuda*' ! -path '*local_config_tensorrt*' ! -path '*local_config_syslibs*' ! -path '*org_tensorflow*'`; do
    mkdir -p "${dest_dir}/$(dirname ${f})"
    cp "${f}" "${dest_dir}/$(dirname ${f})/"
  done
  popd

  # 复制cuda的依赖库
  mkdir -p "${dest_dir}/local_config_cuda/cuda/cuda/"
  cp "${src_dir}/local_config_cuda/cuda/cuda/cuda_config.h" "${dest_dir}/local_config_cuda/cuda/cuda/"
}

# 判断当前平台
PLATFORM="$(uname -s | tr 'A-Z' 'a-z')"
# 判断是否为Windows平台
function is_windows() {
  if [[ "${PLATFORM}" =~ (cygwin|mingw32|mingw64|msys)_nt* ]]; then
    true
  else
    false
  fi
}

# 准备源码
function prepare_src() {
  if [ $# -lt 1 ] ; then
    echo "No destination dir provided"
    exit 1
  fi

  TMPDIR="$1"
  mkdir -p "$TMPDIR"
  EXTERNAL_INCLUDES="${TMPDIR}/tensorflow/include/external"

  # 外部依赖的头文件路径 
  echo $(date) : "=== Preparing sources in dir: ${TMPDIR}"

  if [ ! -d bazel-bin/tensorflow ]; then
    echo "Could not find bazel-bin.  Did you run from the root of the build tree?"
    exit 1
  fi

  if is_windows; then
    # Windows平台,解压二进制文件得到运行文件树
    rm -rf ./bazel-bin/tensorflow/tools/pip_package/simple_console_for_window_unzip
    mkdir -p ./bazel-bin/tensorflow/tools/pip_package/simple_console_for_window_unzip
    echo "Unzipping simple_console_for_windows.zip to create runfiles tree..."
    unzip -o -q ./bazel-bin/tensorflow/tools/pip_package/simple_console_for_windows.zip -d ./bazel-bin/tensorflow/tools/pip_package/simple_console_for_window_unzip
    echo "Unzip finished."
    # runfiles structure after unzip the python binary
    # 复制文件
    cp -R \
      bazel-bin/tensorflow/tools/pip_package/simple_console_for_window_unzip/runfiles/org_tensorflow/tensorflow \
      "${TMPDIR}"
    cp_external \
      bazel-bin/tensorflow/tools/pip_package/simple_console_for_window_unzip/runfiles \
      "${EXTERNAL_INCLUDES}/"
    RUNFILES=bazel-bin/tensorflow/tools/pip_package/simple_console_for_window_unzip/runfiles/org_tensorflow
  else
     # 非Windows平台
    RUNFILES=bazel-bin/tensorflow/tools/pip_package/build_pip_package.runfiles/org_tensorflow
    if [ -d bazel-bin/tensorflow/tools/pip_package/build_pip_package.runfiles/org_tensorflow/external ]; then
      # Old-style runfiles structure (--legacy_external_runfiles).
      # 老式运行文件结构,外部依赖在external目录

      # 将tensorflow相关代码复制到TMPDIR
      cp -R \
        bazel-bin/tensorflow/tools/pip_package/build_pip_package.runfiles/org_tensorflow/tensorflow \
        "${TMPDIR}"

      # 将外部依赖文件复制到TMPDIR
      cp_external \
        bazel-bin/tensorflow/tools/pip_package/build_pip_package.runfiles/org_tensorflow/external \
        "${EXTERNAL_INCLUDES}"
      
      # Copy MKL libs over so they can be loaded at runtime
      # 复制MKL库以便运行时加载
      so_lib_dir=$(ls $RUNFILES | grep solib) || true
      if [ -n "${so_lib_dir}" ]; then
        mkl_so_dir=$(ls ${RUNFILES}/${so_lib_dir} | grep mkl) || true
        if [ -n "${mkl_so_dir}" ]; then
          mkdir "${TMPDIR}/${so_lib_dir}"
          cp -R ${RUNFILES}/${so_lib_dir}/${mkl_so_dir} "${TMPDIR}/${so_lib_dir}"
        fi
      fi
    else
      # New-style runfiles structure (--nolegacy_external_runfiles).
      # 新式运行文件结构,外部依赖与源码在同一级目录  
      cp -R \
        bazel-bin/tensorflow/tools/pip_package/build_pip_package.runfiles/org_tensorflow/tensorflow \
        "${TMPDIR}"
      cp_external \
        bazel-bin/tensorflow/tools/pip_package/build_pip_package.runfiles \
        "${EXTERNAL_INCLUDES}"
      # Copy MKL libs over so they can be loaded at runtime
      # 复制MKL库以便运行时加载  
      so_lib_dir=$(ls $RUNFILES | grep solib) || true
      if [ -n "${so_lib_dir}" ]; then
        mkl_so_dir=$(ls ${RUNFILES}/${so_lib_dir} | grep mkl) || true
        if [ -n "${mkl_so_dir}" ]; then
          mkdir "${TMPDIR}/${so_lib_dir}"
          cp -R ${RUNFILES}/${so_lib_dir}/${mkl_so_dir} "${TMPDIR}/${so_lib_dir}"
        fi
      fi
    fi
    
    mkdir "${TMPDIR}/tensorflow/aux-bin"
    # Install toco as a binary in aux-bin.
    # 复制toco转换工具
    cp bazel-bin/tensorflow/contrib/lite/python/tflite_convert ${TMPDIR}/tensorflow/aux-bin/
  fi

  # protobuf pip package doesn't ship with header files. Copy the headers
  # over so user defined ops can be compiled.
  # 复制protobuf头文件
  mkdir -p ${TMPDIR}/google
  mkdir -p ${TMPDIR}/third_party
  pushd ${RUNFILES%org_tensorflow} > /dev/null
  # 遍历protobuf头文件并复制
  for header in $(find protobuf_archive -name \*.h); do
    mkdir -p "${TMPDIR}/google/$(dirname ${header})"
    cp "$header" "${TMPDIR}/google/$(dirname ${header})/"
  done
  popd > /dev/null
  cp -R $RUNFILES/third_party/eigen3 ${TMPDIR}/third_party

  # 复制构建配置文件
  cp tensorflow/tools/pip_package/MANIFEST.in ${TMPDIR}
  cp tensorflow/tools/pip_package/README ${TMPDIR}
  cp tensorflow/tools/pip_package/setup.py ${TMPDIR}
}

# 构建wheel包
function build_wheel() {
  if [ $# -lt 2 ] ; then
    echo "No src and dest dir provided"
    exit 1
  fi

  TMPDIR="$1"
  DEST="$2"
  PKG_NAME_FLAG="$3"

  # Before we leave the top-level directory, make sure we know how to
  # call python.
  # 设置python命令
  if [[ -e tools/python_bin_path.sh ]]; then
    source tools/python_bin_path.sh
  fi

  pushd ${TMPDIR} > /dev/null
  rm -f MANIFEST
  echo $(date) : "=== Building wheel"
  "${PYTHON_BIN_PATH:-python}" setup.py bdist_wheel ${PKG_NAME_FLAG} >/dev/null
  mkdir -p ${DEST}
  cp dist/* ${DEST}
  popd > /dev/null
  echo $(date) : "=== Output wheel file is in: ${DEST}"
}

function usage() {
  echo "Usage:"
  echo "$0 [--src srcdir] [--dst dstdir] [options]"
  echo "$0 dstdir [options]"
  echo ""
  echo "    --src                 prepare sources in srcdir"
  echo "                              will use temporary dir if not specified"
  echo ""
  echo "    --dst                 build wheel in dstdir"
  echo "                              if dstdir is not set do not build, only prepare sources"
  echo ""
  echo "  Options:"
  echo "    --project_name <name> set project name to name"
  echo "    --gpu                 build tensorflow_gpu"
  echo "    --gpudirect           build tensorflow_gpudirect"
  echo "    --nightly_flag        build tensorflow nightly"
  echo ""
  exit 1
}

function main() {
  PKG_NAME_FLAG=""
  PROJECT_NAME=""
  GPU_BUILD=0
  NIGHTLY_BUILD=0
  SRCDIR=""
  DSTDIR=""
  CLEANSRC=1
  # 解析参数
  while true; do
    if [[ "$1" == "--help" ]]; then
      usage
      exit 1
    elif [[ "$1" == "--nightly_flag" ]]; then
      NIGHTLY_BUILD=1
    elif [[ "$1" == "--gpu" ]]; then
      GPU_BUILD=1
    elif [[ "$1" == "--gpudirect" ]]; then
      PKG_NAME_FLAG="--project_name tensorflow_gpudirect"
    elif [[ "$1" == "--project_name" ]]; then
      shift
      if [[ -z "$1" ]]; then
        break
      fi
      PROJECT_NAME="$1"
    elif [[ "$1" == "--src" ]]; then
      shift
      SRCDIR="$(real_path $1)"
      CLEANSRC=0
    elif [[ "$1" == "--dst" ]]; then
      shift
      DSTDIR="$(real_path $1)"
    else
      DSTDIR="$(real_path $1)"
    fi
    shift

    if [[ -z "$1" ]]; then
      break
    fi
  done

  # 构建wheel
  if [[ -z "$DSTDIR" ]] && [[ -z "$SRCDIR" ]]; then
    echo "No destination dir provided"
    usage
    exit 1
  fi

  
  if [[ -z "$SRCDIR" ]]; then
    # make temp srcdir if none set
    SRCDIR="$(mktemp -d -t tmp.XXXXXXXXXX)"
  fi

  prepare_src "$SRCDIR"

  if [[ -z "$DSTDIR" ]]; then
      # only want to prepare sources
      exit
  fi

  if [[ -n ${PROJECT_NAME} ]]; then
    PKG_NAME_FLAG="--project_name ${PROJECT_NAME}"
  elif [[ ${NIGHTLY_BUILD} == "1" && ${GPU_BUILD} == "1" ]]; then
    PKG_NAME_FLAG="--project_name tf_nightly_gpu"
  elif [[ ${NIGHTLY_BUILD} == "1" ]]; then
    PKG_NAME_FLAG="--project_name tf_nightly"
  elif [[ ${GPU_BUILD} == "1" ]]; then
    PKG_NAME_FLAG="--project_name tensorflow_gpu"
  fi

  build_wheel "$SRCDIR" "$DSTDIR" "$PKG_NAME_FLAG"

  # 删除临时源目录
  if [[ $CLEANSRC -ne 0 ]]; then
    rm -rf "${TMPDIR}"
  fi
}

main "$@"
