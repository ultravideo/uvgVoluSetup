# Fuzz-tolerant replacement for the encoder's kvazaar_apply_multilib_patch.cmake.
#
# The multilib.patch shipped in the encoder repo was authored against a newer
# kvazaar than the one pinned by KVAZAAR_REPO_TAGS, so the strict `git apply`
# check fails on minor context drift. This version falls back to GNU patch with
# a fuzz factor, which tolerates small offset differences.
#
# Invoked by the encoder's kvazaar ExternalProject with:
#   -Dsource_dir=<kvazaar checkout> -Dpatch_file=<path to multilib.patch>

if(NOT DEFINED source_dir)
    message(FATAL_ERROR "source_dir is required to apply multilib patch")
endif()
if(NOT DEFINED patch_file)
    message(FATAL_ERROR "patch_file is required to apply multilib patch")
endif()
if(NOT EXISTS "${patch_file}")
    message(FATAL_ERROR "multilib.patch not found at ${patch_file}")
endif()

find_program(GIT_EXECUTABLE git)
find_program(PATCH_EXECUTABLE patch)
if(NOT GIT_EXECUTABLE)
    message(FATAL_ERROR "git not found; required to apply multilib.patch")
endif()

execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${source_dir}" apply --check --recount "${patch_file}"
    RESULT_VARIABLE patch_check_result
)

if(patch_check_result EQUAL 0)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" -C "${source_dir}" apply --whitespace=nowarn --recount "${patch_file}"
        RESULT_VARIABLE patch_apply_result
    )
    if(NOT patch_apply_result EQUAL 0)
        message(FATAL_ERROR "Failed to apply multilib.patch")
    endif()
elseif(PATCH_EXECUTABLE)
    # git apply is strict; fall back to GNU patch with fuzz for minor context drift
    execute_process(
        COMMAND "${PATCH_EXECUTABLE}" -p1 --fuzz=3 --forward --no-backup-if-mismatch -i "${patch_file}"
        WORKING_DIRECTORY "${source_dir}"
        RESULT_VARIABLE patch_fuzz_result
    )
    if(NOT patch_fuzz_result EQUAL 0)
        execute_process(
            COMMAND "${PATCH_EXECUTABLE}" -p1 --reverse --dry-run -i "${patch_file}"
            WORKING_DIRECTORY "${source_dir}"
            RESULT_VARIABLE patch_reverse_result
        )
        if(patch_reverse_result EQUAL 0)
            message(STATUS "multilib.patch already applied; skipping")
        else()
            message(FATAL_ERROR "multilib.patch could not be applied with git apply or patch")
        endif()
    endif()
else()
    message(FATAL_ERROR "multilib.patch cannot be applied cleanly")
endif()