# uvgvolucap's vcpkg.json omits realsense2 even though src/lib/camera requires
# find_package(realsense2 CONFIG). Add it to the manifest so vcpkg builds it.
#
# Invoked by ExternalProject PATCH_COMMAND with:
#   -DMANIFEST=<path to uvgvolucap/vcpkg.json>

file(READ "${MANIFEST}" _content)
if(NOT _content MATCHES "realsense2")
  string(REPLACE
    "\"azure-kinect-sensor-sdk\","
    "\"azure-kinect-sensor-sdk\",\n    \"realsense2\","
    _content "${_content}")
  file(WRITE "${MANIFEST}" "${_content}")
  message(STATUS "Patched ${MANIFEST}: added realsense2 dependency")
else()
  message(STATUS "Manifest ${MANIFEST} already contains realsense2")
endif()