cmake_minimum_required(VERSION 3.27)
project(uvgvpcc_demo_setup NONE)

include(ExternalProject)
find_package(Git REQUIRED)

# ============================================================================
# Repositories
# ----------------------------------------------------------------------------
# Every repository used by the pipeline is a cache variable so the URLs can be
# redefined on the command line (e.g. to point at mirrors or local clones):
#
#   cmake -DUVGVOLUCAP_REPO=... -DUVGVPCCENC_REPO=... ...
#
# Empty *_TAG means "track the repository default branch".
# ============================================================================
set(UVGVOLUCAP_REPO "git@github.com:ultravideo/uvgVoluCap.git"  CACHE STRING "git URL of the uvgVoluCap capture application")
set(UVGVPCCENC_REPO "git@github.com:ultravideo/uvgVPCCenc.git" CACHE STRING "git URL of the uvgVPCCenc V-PCC encoder")
set(UVGVPCCDEC_REPO "git@github.com:ultravideo/uvgVPCCdec.git"   CACHE STRING "git URL of the uvgVPCCdec V-PCC decoder")
set(VISUALIZER_REPO "git@github.com:ultravideo/uvgVoluPlay.git"   CACHE STRING "git URL of the point-cloud visualizer")
set(UVGV3CRTP_REPO  "git@github.com:ultravideo/uvgV3CRTP.git"    CACHE STRING "git URL of uvgV3CRTP (RTP transport for V3C bitstreams)")

set(UVGVOLUCAP_TAG "" CACHE STRING "Branch/tag/commit for uvgvolucap (empty = default branch)")
set(UVGVPCCENC_TAG "" CACHE STRING "Branch/tag/commit for uvgvpccenc (empty = default branch)")
set(UVGVPCCDEC_TAG "" CACHE STRING "Branch/tag/commit for uvgvpccdec (empty = default branch)")
set(VISUALIZER_TAG "" CACHE STRING "Branch/tag/commit for visualizer (empty = default branch)")
set(UVGV3CRTP_TAG  "" CACHE STRING "Branch/tag/commit for uvgv3crtp (empty = default branch)")

set(VCPKG_REPO  "https://github.com/microsoft/vcpkg.git" CACHE STRING "git URL of vcpkg (dependency manager)")

# ============================================================================
# Layout
# ----------------------------------------------------------------------------
#   <binaryDir>/repos   checked out repositories (ExternalProject SOURCE_DIR)
#   <binaryDir>/bin     FINAL flat output folder with every tool + shared lib
#   <binaryDir>/stage   intermediate installs / staging
# ============================================================================
set(REPOS_DIR "${CMAKE_CURRENT_BINARY_DIR}/repos" CACHE PATH "Directory where all repositories are checked out")
set(BIN_DIR   "${CMAKE_CURRENT_BINARY_DIR}/bin"   CACHE PATH "Final flat bin folder with all tools and libraries")
set(STAGE_DIR "${CMAKE_CURRENT_BINARY_DIR}/stage" CACHE PATH "Staging area for intermediate libraries")

set(VCPKG_ROOT    "${REPOS_DIR}/vcpkg"        CACHE PATH "vcpkg checkout used as CMake toolchain")
set(VCPKG_TRIPLET "x64-linux"                 CACHE STRING "vcpkg target triplet")

set(_vcpkg_toolchain   "${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")

# When PREPOPULATED_SOURCES=ON, the git checkouts are already present under
# REPOS_DIR (including vcpkg). ExternalProject is then told to skip its git
# download step for every repository (otherwise it would try to re-clone over
# the network on the first build). This is useful on machines that can reach
# the repositories through the Windows-side credentials but whose WSL SSH
# cannot authenticate against gitlab directly.
set(PREPOPULATED_SOURCES OFF CACHE BOOL
  "ON when all repo checkouts already exist under REPOS_DIR (skips git clone/update)")

# Git arguments for vcpkg
if(PREPOPULATED_SOURCES)
  set(_vcpkg_git UPDATE_DISCONNECTED ON)
else()
  set(_vcpkg_git GIT_REPOSITORY ${VCPKG_REPO} GIT_TAG master UPDATE_DISCONNECTED ON)
endif()

# Git arguments for uvgv3crtp
if(PREPOPULATED_SOURCES)
  set(_v3crtp_git UPDATE_DISCONNECTED ON)
else()
  set(_v3crtp_git GIT_REPOSITORY ${UVGV3CRTP_REPO} GIT_TAG ${UVGV3CRTP_TAG}
                   GIT_SUBMODULES dependencies/uvgRTP UPDATE_DISCONNECTED ON)
endif()

# Git arguments for uvgvolucap
if(PREPOPULATED_SOURCES)
  set(_volucap_git UPDATE_DISCONNECTED ON)
else()
  set(_volucap_git GIT_REPOSITORY ${UVGVOLUCAP_REPO} GIT_TAG ${UVGVOLUCAP_TAG} UPDATE_DISCONNECTED ON)
endif()

# Git arguments for visualizer
if(PREPOPULATED_SOURCES)
  set(_visualizer_git UPDATE_DISCONNECTED ON)
else()
  set(_visualizer_git GIT_REPOSITORY ${VISUALIZER_REPO} GIT_TAG ${VISUALIZER_TAG} UPDATE_DISCONNECTED ON)
endif()

# Git arguments for uvgvpccenc
if(PREPOPULATED_SOURCES)
  set(_enc_git UPDATE_DISCONNECTED ON)
else()
  set(_enc_git GIT_REPOSITORY ${UVGVPCCENC_REPO} GIT_TAG ${UVGVPCCENC_TAG} UPDATE_DISCONNECTED ON)
endif()

# Git arguments for uvgvpccdec
if(PREPOPULATED_SOURCES)
  set(_dec_git UPDATE_DISCONNECTED ON)
else()
  set(_dec_git GIT_REPOSITORY ${UVGVPCCDEC_REPO} GIT_TAG ${UVGVPCCDEC_TAG} UPDATE_DISCONNECTED ON)
endif()

# ============================================================================
# vcpkg (dependency manager used by uvgvolucap + visualizer)
# ============================================================================
ExternalProject_Add(vcpkg
  ${_vcpkg_git}
  SOURCE_DIR ${VCPKG_ROOT}
  BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/_b/vcpkg
  CONFIGURE_COMMAND ""
  BUILD_COMMAND bash "${VCPKG_ROOT}/bootstrap-vcpkg.sh" -disableMetrics
  INSTALL_COMMAND ""
  BUILD_BYPRODUCTS "${VCPKG_ROOT}/vcpkg"
  LOG_DOWNLOAD ON
  LOG_BUILD ON
  LOG_OUTPUT_ON_FAILURE ON
)

# ============================================================================
# uvgv3crtp (standalone build; library + sender/receiver examples)
# ----------------------------------------------------------------------------
# Also used as the V3C RTP transport inside uvgvpccenc and uvgvpccdec: the
# checked-out tree is copied into their src/app/dependencies/uvgV3CRTP path so
# the encoder/decoder build against THIS repository instead of the github
# submodule URL baked into their .gitmodules.
# ============================================================================
set(_v3crtp_build_dir "${CMAKE_CURRENT_BINARY_DIR}/_b/uvgv3crtp")
ExternalProject_Add(uvgv3crtp
  ${_v3crtp_git}
  SOURCE_DIR ${REPOS_DIR}/uvgv3crtp
  BINARY_DIR ${_v3crtp_build_dir}
  CMAKE_ARGS
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX=${STAGE_DIR}/uvgv3crtp
    -DUVGV3CRTP_DISABLE_EXAMPLES=OFF
    -DUVGV3CRTP_DISABLE_WERROR=ON
    -DUVGRTP_DISABLE_CRYPTO=ON
    -DUVGRTP_DISABLE_TESTS=ON
    -DUVGRTP_DISABLE_EXAMPLES=ON
    -DUVGRTP_DISABLE_WERROR=ON
  BUILD_COMMAND ${CMAKE_COMMAND} --build . --parallel --target uvgv3crtp
                        simple_sender_example simple_receiver_example
                        gof_sender_example gof_receiver_example
                        unit_sender_example unit_receiver_example
                        sdp_sender_example sdp_receiver_example
  INSTALL_COMMAND ${CMAKE_COMMAND} --install .
  LOG_DOWNLOAD ON
  LOG_CONFIGURE ON
  LOG_BUILD ON
  LOG_INSTALL ON
  LOG_OUTPUT_ON_FAILURE ON
)

# ============================================================================
# uvgvolucap (capture system)
# ----------------------------------------------------------------------------
# Built with the vcpkg toolchain (manifest mode reads uvgvolucap/vcpkg.json).
# Its top-level CMakeLists forces CMAKE_INSTALL_PREFIX=<repo>/build/bin, so the
# install step always lands in ${REPOS_DIR}/uvgvolucap/build/bin.
# ============================================================================
set(_volucap_dir "${REPOS_DIR}/uvgvolucap")
ExternalProject_Add(uvgvolucap
  ${_volucap_git}
  SOURCE_DIR ${_volucap_dir}
  BINARY_DIR ${_volucap_dir}/build
  PATCH_COMMAND ${CMAKE_COMMAND}
                  -DMANIFEST=${_volucap_dir}/vcpkg.json
                  -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/patch_volucap_manifest.cmake
  CMAKE_ARGS
    -DCMAKE_TOOLCHAIN_FILE=${_vcpkg_toolchain}
    -DVCPKG_TARGET_TRIPLET=${VCPKG_TRIPLET}
    -DVCPKG_OVERLAY_PORTS=${CMAKE_CURRENT_SOURCE_DIR}/cmake/vcpkg-overlays
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_SHARED_LIBS=ON
  BUILD_COMMAND ${CMAKE_COMMAND} --build . --config Release --parallel --target install
  INSTALL_COMMAND ""
  DEPENDS vcpkg
  LOG_CONFIGURE ON
  LOG_BUILD ON
  LOG_OUTPUT_ON_FAILURE ON
)

# ============================================================================
# visualizer (rendering front-end; no install target)
# ============================================================================
set(_visualizer_dir "${REPOS_DIR}/visualizer")
ExternalProject_Add(visualizer
  ${_visualizer_git}
  SOURCE_DIR ${_visualizer_dir}
  BINARY_DIR ${_visualizer_dir}/build
  PATCH_COMMAND ${CMAKE_COMMAND}
                  -DCAMERA_H=${_visualizer_dir}/source/elems/camera.h
                  -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/patch_visualizer_camera.cmake
  CMAKE_ARGS
    -DCMAKE_TOOLCHAIN_FILE=${_vcpkg_toolchain}
    -DVCPKG_TARGET_TRIPLET=${VCPKG_TRIPLET}
    -DCMAKE_BUILD_TYPE=Release
  BUILD_COMMAND ${CMAKE_COMMAND} --build . --config Release --parallel
  INSTALL_COMMAND ""
  DEPENDS vcpkg
  LOG_CONFIGURE ON
  LOG_BUILD ON
  LOG_OUTPUT_ON_FAILURE ON
)

# ============================================================================
# uvgvpccenc (encoder)
# ----------------------------------------------------------------------------
# ENABLE_V3CRTP=ON + GIT_SUBMODULE=OFF make the app use the uvgv3crtp tree that
# is copied into its dependencies path (see cmake/embed_v3crtp.cmake) instead
# of fetching the github submodule. Installs the executable + shared libraries
# flat into ${BIN_DIR} (RPATH set to ${BIN_DIR} so the binaries find the .so
# files at runtime).
# ============================================================================
set(_enc_dir "${REPOS_DIR}/uvgvpccenc")
ExternalProject_Add(uvgvpccenc
  ${_enc_git}
  SOURCE_DIR ${_enc_dir}
  BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/_b/uvgvpccenc
  PATCH_COMMAND ${CMAKE_COMMAND}
                  -DV3CRTP_SRC=${REPOS_DIR}/uvgv3crtp
                  -DEMBED_DEST=${_enc_dir}/src/app/dependencies/uvgV3CRTP
                  -DENC_SRC=${_enc_dir}
                  -DFUZZ_APPLY_SCRIPT=${CMAKE_CURRENT_SOURCE_DIR}/cmake/kvazaar_apply_multilib_patch_fuzz.cmake
                  -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/patch_encoder.cmake
  CMAKE_ARGS
    -DCMAKE_BUILD_TYPE=Release
    -DENABLE_V3CRTP=ON
    -DGIT_SUBMODULE=OFF
    -DBUILD_SHARED_LIBS=ON
    -DCMAKE_INSTALL_PREFIX=${STAGE_DIR}/uvgvpccenc
    -DCMAKE_INSTALL_BINDIR=bin
    -DCMAKE_INSTALL_LIBDIR=lib
    -DCMAKE_INSTALL_INCLUDEDIR=include
    -DCMAKE_INSTALL_RPATH=${BIN_DIR}
  DEPENDS uvgv3crtp
  LOG_CONFIGURE ON
  LOG_BUILD ON
  LOG_INSTALL ON
  LOG_OUTPUT_ON_FAILURE ON
)

# ============================================================================
# uvgvpccdec (decoder)
# ----------------------------------------------------------------------------
# Same V3CRTP embedding as the encoder. Links system FFmpeg via pkg-config and
# finds cppzmq from the distro package (cmake config is in the default search
# path on Ubuntu; override with -DCMAKE_PREFIX_PATH if needed).
# ============================================================================
set(_dec_dir "${REPOS_DIR}/uvgvpccdec")
ExternalProject_Add(uvgvpccdec
  ${_dec_git}
  SOURCE_DIR ${_dec_dir}
  BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/_b/uvgvpccdec
  PATCH_COMMAND ${CMAKE_COMMAND}
                  -DV3CRTP_SRC=${REPOS_DIR}/uvgv3crtp
                  -DEMBED_DEST=${_dec_dir}/src/app/dependencies/uvgV3CRTP
                  -DFIXED_FINDDEPS=${CMAKE_CURRENT_SOURCE_DIR}/cmake/decoder_FindDependencies_fixed.cmake
                  -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/patch_decoder.cmake
  CMAKE_ARGS
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
    -DENABLE_V3CRTP=ON
    -DGIT_SUBMODULE=OFF
    -DBUILD_SHARED_LIBS=ON
    -DCMAKE_INSTALL_PREFIX=${STAGE_DIR}/uvgvpccdec
    -DCMAKE_INSTALL_BINDIR=bin
    -DCMAKE_INSTALL_LIBDIR=lib
    -DCMAKE_INSTALL_INCLUDEDIR=include
    -DCMAKE_INSTALL_RPATH=${BIN_DIR}
  DEPENDS uvgv3crtp
  LOG_CONFIGURE ON
  LOG_BUILD ON
  LOG_INSTALL ON
  LOG_OUTPUT_ON_FAILURE ON
)

# ============================================================================
# Capture / run scripts
# ----------------------------------------------------------------------------
# Parametrized launcher scripts (paths pointing into the assembled bin/ folder)
# are generated here and dropped into bin/ by the assemble step. Execution
# order: visualizer -> decoder -> encoder -> capture_system
# ============================================================================
configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/templates/capture_system_script.py.in"
  "${CMAKE_CURRENT_BINARY_DIR}/scripts/capture_system_script.py"
  @ONLY
)
configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/templates/encoder_script.py.in"
  "${CMAKE_CURRENT_BINARY_DIR}/scripts/encoder_script.py"
  @ONLY
)
configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/templates/decoder_script.py.in"
  "${CMAKE_CURRENT_BINARY_DIR}/scripts/decoder_script.py"
  @ONLY
)

# ============================================================================
# Assemble: flatten every artifact into ${BIN_DIR}
# ============================================================================
add_custom_target(assemble ALL
  COMMAND ${CMAKE_COMMAND}
    -DBIN_DIR=${BIN_DIR}
    -DSTAGE_DIR=${STAGE_DIR}
    -DVCPKG_TRIPLET=${VCPKG_TRIPLET}
    -DUVGVOLUCAP_BIN_DIR=${_volucap_dir}/build/bin
    -DUVGVOLUCAP_SRC=${_volucap_dir}
    -DUVGVOLUCAP_BUILD_DIR=${_volucap_dir}/build
    -DVISUALIZER_BUILD_DIR=${_visualizer_dir}/build
    -DUVGV3CRTP_BUILD_DIR=${_v3crtp_build_dir}
    -DENCODER_BUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}/_b/uvgvpccenc
    -DGENERATED_SCRIPTS_DIR=${CMAKE_CURRENT_BINARY_DIR}/scripts
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/assemble.cmake
  DEPENDS uvgvolucap visualizer uvgvpccenc uvgvpccdec uvgv3crtp
  USES_TERMINAL
)

message(STATUS "")
message(STATUS "uvgvpcc demo pipeline build")
message(STATUS "  repos : ${REPOS_DIR}")
message(STATUS "  bin   : ${BIN_DIR}")
message(STATUS "  vcpkg : ${VCPKG_ROOT}")
message(STATUS "")