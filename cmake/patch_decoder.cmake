# Prepares the uvgvpccdec source tree for building:
#   1. Embeds the gitlab uvgv3crtp checkout into src/app/dependencies/uvgV3CRTP
#      (see embed_v3crtp.cmake) so the decoder builds against THIS repository
#      instead of the github submodule URL.
#   2. Replaces the buggy duplicated FindDependencies.cmake with a clean copy.
#
# Invoked by the decoder ExternalProject PATCH_COMMAND with:
#   -DV3CRTP_SRC=<path to uvgv3crtp checkout>
#   -DEMBED_DEST=<path to src/app/dependencies/uvgV3CRTP inside the decoder>
#   -DFIXED_FINDDEPS=<path to decoder_FindDependencies_fixed.cmake>

file(REMOVE_RECURSE "${EMBED_DEST}")
file(MAKE_DIRECTORY "${EMBED_DEST}")
file(COPY "${V3CRTP_SRC}/" DESTINATION "${EMBED_DEST}" PATTERN ".git" EXCLUDE)
message(STATUS "Embedded uvgv3crtp into ${EMBED_DEST}")

set(_dec_finddeps "${EMBED_DEST}/../FindDependencies.cmake")
file(REMOVE "${_dec_finddeps}")
file(COPY "${FIXED_FINDDEPS}" DESTINATION "${EMBED_DEST}/..")
file(RENAME "${EMBED_DEST}/../decoder_FindDependencies_fixed.cmake" "${_dec_finddeps}")
message(STATUS "Replaced decoder FindDependencies.cmake with fixed version")