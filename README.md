# uvgvpcc demo pipeline setup

Builds a complete video-based point-cloud coding demo pipeline from the five
UltraVideo / uvgvpcc repositories into a single flat `bin/` folder.

## Pipeline

Execution order:

```
visualizer -> decoder -> encoder -> capture_system
```

| Tool | Repository | Role |
|------|------------|------|
| `uvgVoluCap` | `uvgvolucap` | Capture (Azure Kinect / RealSense) -> color+position over ZeroMQ |
| `uvgVPCCenc` | `02-uvgvpccenc` | V-PCC encoder, streams over RTP (`uvgv3crtp`) |
| `uvgVPCCdec` | `uvgvpccdec` | V-PCC decoder, reconstructs frames over RTP |
| `uvgVisualizer` | `visualizer` | Renders decoded point clouds |
| uvgv3crtp examples | `uvgv3crtp` | Standalone V3C-over-RTP send/receive demos |

## Repositories

The URLs are CMake cache variables and can be redefined on the command line
(e.g. to point at a local mirror). Each also has an optional `*_TAG` variable
to pin a branch/tag/commit (empty = default branch).

| Variable | Default |
|----------|---------|
| `UVGVOLUCAP_REPO` | `git@gitlab.tuni.fi:cs/ultravideo/pcc/uvgvolucap.git` |
| `UVGVPCCENC_REPO` | `git@gitlab.tuni.fi:cs/ultravideo/pcc/02-uvgvpccenc.git` |
| `UVGVPCCDEC_REPO` | `git@gitlab.tuni.fi:cs/ultravideo/pcc/uvgvpccdec.git` |
| `VISUALIZER_REPO` | `git@gitlab.tuni.fi:cs/ultravideo/pcc/visualizer.git` |
| `UVGV3CRTP_REPO` | `git@gitlab.tuni.fi:cs/ultravideo/pcc/uvgv3crtp.git` |

## Requirements

- WSL with Ubuntu 24.04 (Windows-only builds are not guaranteed; the capture
  SDKs and OpenGL visualizer target Linux)
- SSH access to `gitlab.tuni.fi` (see below)

```bash
sudo apt install build-essential cmake ninja-build git pkg-config \
     libavcodec-dev libavformat-dev libavutil-dev libzmq3-dev \
     libglu1-mesa-dev libgl1-mesa-dev libegl1-mesa-dev libgles2-mesa-dev \
     libusb-1.0-0-dev libudev-dev libssl-dev
```

`uvgvpccdec` links the distro FFmpeg (`libavcodec/libavformat/libavutil` via
pkg-config) and the distro `cppzmq` package, so no vcpkg builds are needed for
it. `uvgvolucap` and `visualizer` use vcpkg (managed automatically) for the
Azure Kinect / RealSense SDKs, GLFW, GLEW, imgui, etc.

## Build

```bash
cmake --preset wsl-release
cmake --build --preset wsl-release
```

The final tools and shared libraries are assembled into `build/bin/`.

### Pre-populated sources (offline / gitlab-over-WSL limitation)

If the WSL SSH keys are not authorized on gitlab.tuni.fi but the repositories
are already checked out (e.g. cloned on Windows), copy them under
`REPOS_DIR` and skip the network clone:

```bash
cmake --preset wsl-release -DPREPOPULATED_SOURCES=ON \
      -DREPOS_DIR=/path/to/repos   # must contain uvgvolucap, uvgvpccenc,
                                   # uvgvpccdec, visualizer, uvgv3crtp, vcpkg
cmake --build --preset wsl-release
```

## Running

Full capture cannot run without the camera hardware. On the capture setup, the
parametrized scripts in `bin/` drive each stage:

```bash
export LD_LIBRARY_PATH=$PWD/bin
python3 bin/capture_system_script.py run    # capture (last)
python3 bin/encoder_script.py run           # encode + RTP stream
python3 bin/decoder_script.py decode        # decode + forward to visualizer
./bin/uvgVisualizer                          # render (first)
```

## Patches applied by the build

The current `HEAD` of some repos has build regressions; the CMake files patch
them automatically during the build:

- **realsense2 (vcpkg overlay)** — adds `#include <cstdint>` to
  `rsutils/version.h` (fails to compile with GCC 13).
- **uvgvolucap** — `vcpkg.json` omits `realsense2` even though the camera lib
  requires it; the manifest is patched.
- **visualizer** — `camera.h` assigns a `high_resolution_clock` time point to a
  `steady_clock` variable (fails on GCC 13); type is corrected.
- **uvgvpccenc** — embeds the gitlab `uvgv3crtp` (instead of the github
  submodule), uses a fuzz-tolerant apply for the `multilib.patch` (it drifts
  from the pinned kvazaar tag), and fixes the header install path.
- **uvgvpccdec** — embeds `uvgv3crtp` and replaces the duplicated
  `FindDependencies.cmake` (which aborts with "binary directory already used").
