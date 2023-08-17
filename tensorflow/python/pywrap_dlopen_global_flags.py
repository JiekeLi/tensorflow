# Copyright 2017 The TensorFlow Authors. All Rights Reserved.
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
# =============================================================================
"""If possible, exports all symbols with RTLD_GLOBAL.

Note that this file is only imported by pywrap_tensorflow.py if this is a static
build (meaning there is no explicit framework cc_binary shared object dependency
of _pywrap_tensorflow_internal.so). For regular (non-static) builds, RTLD_GLOBAL
is not necessary, since the dynamic dependencies of custom/contrib ops are
explicit.
"""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import ctypes
import sys

# On UNIX-based platforms, pywrap_tensorflow is a SWIG-generated python library
# that dynamically loads _pywrap_tensorflow.so. The default mode for loading
# keeps all the symbol private and not visible to other libraries that may be
# loaded. Setting the mode to RTLD_GLOBAL to make the symbols visible, so that
# custom op libraries imported using `tf.load_op_library()` can access symbols
# defined in _pywrap_tensorflow.so.

# 这段注释的意思是，在基于UNIX的平台上，pywrap_tensorflow是一个由SWIG生成的python库，
# 它动态地加载_pywrap_tensorflow.so文件。这个文件是TensorFlow的核心库，
# 它包含了TensorFlow的所有功能和符号。加载这个文件的默认模式是保持所有的符号私有，
# 不对其他可能加载的库可见。这样做的好处是避免符号冲突和污染全局命名空间。
# 但是，这样做也有一个缺点，就是自定义的操作库（custom op library）无法访问_pywrap_tensorflow.so中定义的符号。
# 自定义的操作库是一种扩展TensorFlow功能的方法，它可以用C++或其他语言编写一些特定的操作（op），
# 然后用tf.load_op_library()函数导入到Python中使用。为了解决这个问题，注释中设置了加载模式为RTLD_GLOBAL，
# 这样就可以使得_pywrap_tensorflow.so中的符号对其他库可见，从而让自定义的操作库能够正常工作。

_use_rtld_global = (hasattr(sys, 'getdlopenflags')
                    and hasattr(sys, 'setdlopenflags'))
if _use_rtld_global:
  _default_dlopen_flags = sys.getdlopenflags()


def set_dlopen_flags():
  if _use_rtld_global:
    sys.setdlopenflags(_default_dlopen_flags | ctypes.RTLD_GLOBAL)


def reset_dlopen_flags():
  if _use_rtld_global:
    sys.setdlopenflags(_default_dlopen_flags)
