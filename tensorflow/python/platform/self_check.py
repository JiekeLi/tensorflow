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
# ==============================================================================

"""Platform-specific code for checking the integrity of the TensorFlow build.
这三行代码的作用是让Python文件使用一些Python 3的特性,而不是Python 2的默认行为。
from __future__ import absolute_import 是为了避免相对导入和绝对导入的混淆。
from __future__ import division 是为了改变除法运算符的行为。
from __future__ import print_function 是为了让print成为一个函数, 而不是一个语句。
"""
from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import os


try:
  from tensorflow.python.platform import build_info
except ImportError:
  raise ImportError("Could not import tensorflow. Do not import tensorflow "
                    "from its source directory; change directory to outside "
                    "the TensorFlow source tree, and relaunch your Python "
                    "interpreter from there.")


def preload_check():
  """Raises an exception if the environment is not correctly configured.
  
  Raises:
    ImportError: If the check detects that the environment is not correctly
      configured, and attempting to load the TensorFlow runtime will fail.
  """
  if os.name == "nt": # 如果是Windows系统
    # Attempt to load any DLLs that the Python extension depends on before
    # we load the Python extension, so that we can raise an actionable error
    # message if they are not found.
    import ctypes  # pylint: disable=g-import-not-at-top
    if hasattr(build_info, "msvcp_dll_name"):
      try:
        ctypes.WinDLL(build_info.msvcp_dll_name)
      except OSError:
        # Microsoft Visual C++ 2015 Redistributable Update 3是一个库，
        # 它安装了Visual C++库的运行时组件。
        # 这些组件是运行使用Visual Studio 2015 Update 3开发
        # 并动态链接到Visual C++库的C++应用程序所必需的1。
        raise ImportError(
            "Could not find %r. TensorFlow requires that this DLL be "
            "installed in a directory that is named in your %%PATH%% "
            "environment variable. You may install this DLL by downloading "
            "Visual C++ 2015 Redistributable Update 3 from this URL: "
            "https://www.microsoft.com/en-us/download/details.aspx?id=53587"
            % build_info.msvcp_dll_name)
        
  else:
    # TODO(mrry): Consider adding checks for the Linux and Mac OS X builds.
    pass
