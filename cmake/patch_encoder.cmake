# Prepares the uvgvpccenc source tree for building:
#   1. Embeds the gitlab uvgv3crtp checkout into src/app/dependencies/uvgV3CRTP
#      (see embed_v3crtp.cmake) so the encoder builds against THIS repository
#      instead of the github submodule URL.
#   2. Replaces the kvazaar multilib patch application script with a fuzz
#      tolerant version (the shipped patch drifts from the pinned kvazaar tag).
#
# Invoked by the encoder ExternalProject PATCH_COMMAND with:
#   -DV3CRTP_SRC=<path to uvgv3crtp checkout>
#   -DEMBED_DEST=<path to src/app/dependencies/uvgV3CRTP inside the encoder>
#   -DENC_SRC=<path to the encoder checkout>
#   -DFUZZ_APPLY_SCRIPT=<path to kvazaar_apply_multilib_patch_fuzz.cmake>

file(REMOVE_RECURSE "${EMBED_DEST}")
file(MAKE_DIRECTORY "${EMBED_DEST}")
file(COPY "${V3CRTP_SRC}/" DESTINATION "${EMBED_DEST}" PATTERN ".git" EXCLUDE)
message(STATUS "Embedded uvgv3crtp into ${EMBED_DEST}")

file(REMOVE "${ENC_SRC}/dependencies/kvazaar/kvazaar_apply_multilib_patch.cmake")
file(COPY "${FUZZ_APPLY_SCRIPT}" DESTINATION "${ENC_SRC}/dependencies/kvazaar/")
file(RENAME
  "${ENC_SRC}/dependencies/kvazaar/kvazaar_apply_multilib_patch_fuzz.cmake"
  "${ENC_SRC}/dependencies/kvazaar/kvazaar_apply_multilib_patch.cmake")
message(STATUS "Replaced kvazaar multilib patch script with fuzz-tolerant version")

# The top-level CMakeLists installs headers from a path that does not exist at
# the current HEAD (src/libuvgvpccenc/include/uvgvpcc vs uvgvpccenc).
set(_enc_cmake "${ENC_SRC}/CMakeLists.txt")
file(READ "${_enc_cmake}" _enc_content)
if(_enc_content MATCHES "include/uvgvpcc DESTINATION")
  string(REPLACE
    "include/uvgvpcc DESTINATION"
    "include/uvgvpccenc DESTINATION"
    _enc_content "${_enc_content}")
  file(WRITE "${_enc_cmake}" "${_enc_content}")
  message(STATUS "Patched encoder CMakeLists.txt header install path")
endif()

# The install rule above expects this directory to exist; create it so the
# install step does not fail on the missing directory.
file(MAKE_DIRECTORY "${ENC_SRC}/src/libuvgvpccenc/include/uvgvpcc")
message(STATUS "Ensured encoder include dir exists")