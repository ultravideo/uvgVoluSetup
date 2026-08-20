# Fix a GCC 13 / libstdc++ portability bug in the visualizer: start_time is
# declared as std::chrono::steady_clock::time_point but assigned from
# std::chrono::high_resolution_clock::now(). On libstdc++ high_resolution_clock
# is system_clock, which is not assignable to a steady_clock time_point.
#
# Invoked by ExternalProject PATCH_COMMAND with:
#   -DCAMERA_H=<path to visualizer/source/elems/camera.h>

file(READ "${CAMERA_H}" _content)
if(NOT _content MATCHES "high_resolution_clock::time_point start_time")
  string(REPLACE
    "std::chrono::steady_clock::time_point start_time"
    "std::chrono::high_resolution_clock::time_point start_time"
    _content "${_content}")
  file(WRITE "${CAMERA_H}" "${_content}")
  message(STATUS "Patched ${CAMERA_H}: start_time now uses high_resolution_clock")
else()
  message(STATUS "Camera header ${CAMERA_H} already patched")
endif()