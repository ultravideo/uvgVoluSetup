# Assemble the flat bin/ folder for the V-PCC demo pipeline.
#
# Invoked by the top-level "assemble" target with -D arguments for every path.

file(MAKE_DIRECTORY "${BIN_DIR}")

# ---------------------------------------------------------------------------
# 1. uvgvolucap: executable + shared library (its install lands in
#    <repo>/build/bin because the project FORCEs its install prefix)
# ---------------------------------------------------------------------------
file(GLOB _volucap_bins "${UVGVOLUCAP_BIN_DIR}/uvgVoluCap")
file(GLOB _volucap_so "${UVGVOLUCAP_BIN_DIR}/lib*.so*")
if(_volucap_bins OR _volucap_so)
  file(COPY ${_volucap_bins} ${_volucap_so} DESTINATION "${BIN_DIR}")
endif()

# camera config + asset folder
file(COPY "${UVGVOLUCAP_SRC}/cameraconfig.json" DESTINATION "${BIN_DIR}")
file(COPY "${UVGVOLUCAP_SRC}/asset" DESTINATION "${BIN_DIR}")

# runtime dependencies installed by vcpkg (k4a, realsense2, cppzmq, ...)
file(GLOB _volucap_libs "${UVGVOLUCAP_BUILD_DIR}/vcpkg_installed/${VCPKG_TRIPLET}/lib/*.so*")
if(_volucap_libs)
  file(COPY ${_volucap_libs} DESTINATION "${BIN_DIR}")
endif()

# ---------------------------------------------------------------------------
# 2. visualizer: binary + shaders + vcpkg runtime libs
# ---------------------------------------------------------------------------
file(COPY "${VISUALIZER_BUILD_DIR}/uvgVisualizer" DESTINATION "${BIN_DIR}")
file(COPY "${VISUALIZER_BUILD_DIR}/shaders" DESTINATION "${BIN_DIR}")
file(GLOB _visualizer_libs "${VISUALIZER_BUILD_DIR}/vcpkg_installed/${VCPKG_TRIPLET}/lib/*.so*")
if(_visualizer_libs)
  file(COPY ${_visualizer_libs} DESTINATION "${BIN_DIR}")
endif()

# ---------------------------------------------------------------------------
# 3. encoder + decoder: executables + shared libraries are installed into the
#    staging dirs (${STAGE_DIR}/uvgvpccenc|uvgvpccdec/{bin,lib}) with RPATH
#    pointing at ${BIN_DIR}; copy them into the flat bin folder
# ---------------------------------------------------------------------------
foreach(_comp IN ITEMS uvgvpccenc uvgvpccdec)
  file(GLOB _bin_files "${STAGE_DIR}/${_comp}/bin/*")
  if(_bin_files)
    file(COPY ${_bin_files} DESTINATION "${BIN_DIR}")
  endif()
  file(GLOB _lib_files "${STAGE_DIR}/${_comp}/lib/*.so*")
  if(_lib_files)
    file(COPY ${_lib_files} DESTINATION "${BIN_DIR}")
  endif()
endforeach()
file(REMOVE_RECURSE "${BIN_DIR}/bin")

# The encoder only installs its own library and app; its helper shared
# libraries (libuvgformat, libuvgutils) are left in the build tree. Copy them
# into the flat bin folder as well.
file(GLOB _enc_extra_libs "${ENCODER_BUILD_DIR}/src/libuvgformat/libuvgformat.so*"
                          "${ENCODER_BUILD_DIR}/src/libuvgutils/libuvgutils.so*")
if(_enc_extra_libs)
  file(COPY ${_enc_extra_libs} DESTINATION "${BIN_DIR}")
endif()

# ---------------------------------------------------------------------------
# 4. uvgv3crtp standalone example binaries (statically linked)
# ---------------------------------------------------------------------------
file(GLOB _v3crtp_examples "${UVGV3CRTP_BUILD_DIR}/examples/*_example*")
if(_v3crtp_examples)
  file(COPY ${_v3crtp_examples} DESTINATION "${BIN_DIR}")
endif()

# ---------------------------------------------------------------------------
# 5. generated (parametrized) capture/run scripts
# ---------------------------------------------------------------------------
file(GLOB _generated_scripts "${GENERATED_SCRIPTS_DIR}/*.py")
if(_generated_scripts)
  file(COPY ${_generated_scripts} DESTINATION "${BIN_DIR}")
endif()

# ---------------------------------------------------------------------------
# 6. make the main tools executable
# ---------------------------------------------------------------------------
set(_bin_executables
  "${BIN_DIR}/uvgVoluCap"
  "${BIN_DIR}/uvgVisualizer"
  "${BIN_DIR}/uvgVPCCenc"
  "${BIN_DIR}/uvgVPCCdec"
)
if(_v3crtp_examples)
  list(APPEND _bin_executables ${_v3crtp_examples})
endif()
execute_process(COMMAND chmod +x ${_bin_executables})

message(STATUS "Assembled V-PCC demo pipeline into ${BIN_DIR}")
file(GLOB _result "${BIN_DIR}/*")
foreach(_f IN LISTS _result)
  get_filename_component(_fname "${_f}" NAME)
  message(STATUS "  bin/ ${_fname}")
endforeach()