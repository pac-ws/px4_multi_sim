#!/bin/bash

# Exit immediately if a command exits with a non-zero status,
# treat unset variables as errors, and ensure pipelines fail correctly.
set -euo pipefail

RED='\033[0;31m'    # Red
GREEN='\033[0;32m'  # Green
YELLOW='\033[0;33m' # Yellow
NC='\033[0m'        # No Color

print_usage() {
  cat <<EOF
Usage: bash $(basename "$0") [OPTIONS]

Options:
  --no-gpu                               Disable GPU support
  -d, --dir <directory>                  Specify the directory to px4_multi_sim
  --ros-domain-id <domain id>            Specify the ROS domain ID
  --mount-dir <mount directory>          Specify the directory to mount
  -n, --name <container name>            Specify the name of the container (default: px4_sim)

  -h, --help                             Show this help message and exit.

EOF
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to handle errors with colored output
error_exit() {
  echo -e "${RED}Error: $1${NC}" >&2
  exit 1
}

# Function to display informational messages
info_message() {
  echo -e "${GREEN}$1${NC}"
}

# Function to display warnings
warning_message() {
  echo -e "${YELLOW}Warning: $1${NC}"
}

for cmd in docker getopt; do
  if ! command_exists "$cmd"; then
    error_exit "'$cmd' command is not found. Please install it before running this script."
  fi
done

# Define short and long options
SHORT_OPTS="d:n:h"
LONG_OPTS="dir:,name:,no-gpu,ros-domain-id:,mount-dir:,help"

# Parse options using getopt
PARSED_PARAMS=$(getopt -o "$SHORT_OPTS" -l "$LONG_OPTS" -n "$(basename "$0")" -- "$@") || {
  error_exit "Failed to parse arguments."
}

# Evaluate the parsed options
eval set -- "$PARSED_PARAMS"

# Initialize variables with default values
# Ensure required commands are available
for cmd in docker getopt; do
  if ! command_exists "$cmd"; then
    error_exit "'$cmd' command is not found. Please install it before running this script."
  fi
done

ROS_DOMAIN_ID=10
CONTAINER_NAME="px4_sim"
MOUNT_DIR=""
CONTAINER_OPTIONS=""
PX4_SIM_DIR="${PAC_WS}/px4_multi_sim"
USE_GPU=false
if [ "$(command -v nvidia-smi)" ]; then
  USE_GPU=true
fi

# Process parsed options
while true; do
  case "$1" in
    --no-gpu)
      USE_GPU=false
      shift
      ;;
    -n|--name)
      if [[ -n "${2:-}" && "$2" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        CONTAINER_NAME="$2"
        shift 2
      else
        error_exit "Invalid container name. It must be alphanumeric and can include underscores and hyphens."
      fi
      ;;
    -d|--dir)
      if [[ -n "${2:-}" && -d "$2" ]]; then
        PX4_SIM_DIR="$2"
        shift 2
      else
        error_exit "Invalid directory: $2"
      fi
      ;;
    --ros-domain-id)
      if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
        ROS_DOMAIN_ID="$2"
        shift 2
      else
        error_exit "Invalid ROS domain ID. It must be a number."
      fi
      ;;
    --mount-dir)
      if [[ -n "${2:-}" && -d "$2" ]]; then
        MOUNT_DIR="$2"
        shift 2
      else
        error_exit "Invalid mount directory. It must be a valid directory path."
      fi
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      error_exit "Unknown option: $1"
      ;;
  esac
done

IMAGE_NAME="agarwalsaurav/px4-dev-ros2-humble:latest"
# if [[ "$USE_GPU" == true ]]; then
#   IMAGE_NAME="agarwalsaurav/px4-dev-ros2-humble:cuda"
# fi
PX4_DIR="/opt/px4_ws/src/PX4-Autopilot"
ROBOTS_EXECS_PATH="${PX4_SIM_DIR}/robots_execs.sh"
ROBOTS_POSES_PATH="${PX4_SIM_DIR}/robots_poses.sh"

check_robots_execs() {
  if [[ ! -x "${ROBOTS_EXECS_PATH}" ]]; then
    if [[ -f "${ROBOTS_EXECS_PATH}" ]]; then
      chmod +x "${ROBOTS_EXECS_PATH}"
    else
      warning_message "'robots_execs.sh' not found. Some functions may not work properly."
    fi
  fi
  if [[ ! -f "${ROBOTS_POSES_PATH}" ]]; then
    error_exit "${ROBOTS_POSES_PATH} not found. Please create the file with robot poses."
  fi
}

# Pull the Docker image
info_message "Pulling Docker image: ${IMAGE_NAME}"
if ! docker pull "${IMAGE_NAME}"; then
  error_exit "Failed to pull Docker image: ${IMAGE_NAME}"
fi

if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
  error_exit "Container '${CONTAINER_NAME}' is already running. Please stop it before creating a new one."
fi
check_robots_execs

# Set volume option if MOUNT_DIR is provided
if [[ -n "$MOUNT_DIR" ]]; then
  VOLUME_OPTION="-v ${MOUNT_DIR}:/workspace:rw"
else
  VOLUME_OPTION=""
fi

# Add gpu support
if [[ "$USE_GPU" == true ]]; then
  info_message "Enabling GPU support..."
  CONTAINER_OPTIONS="--gpus all"
  CONTAINER_OPTIONS="${CONTAINER_OPTIONS} --env NVIDIA_VISIBLE_DEVICES=all"
  CONTAINER_OPTIONS="${CONTAINER_OPTIONS} --env NVIDIA_DRIVER_CAPABILITIES=all"
  # Get group id of video group
  VIDEO_GID=$(getent group video | cut -d: -f3)
  RENDER_GID=$(getent group render | cut -d: -f3)
  CONTAINER_OPTIONS="${CONTAINER_OPTIONS} --env VIDEO_GID=${VIDEO_GID}"
  CONTAINER_OPTIONS="${CONTAINER_OPTIONS} --env RENDER_GID=${RENDER_GID}"
fi
info_message "Creating Docker container '${CONTAINER_NAME}'..."
docker run -d -it --rm --init --privileged \
  --env LOCAL_USER_ID="$(id -u)" \
  --env ROS_DOMAIN_ID="${ROS_DOMAIN_ID}" \
  --env PX4_DIR="${PX4_DIR}" \
  --env PX4_GZ_STANDALONE=1 \
  --env PX4_SYS_AUTOSTART=4001 \
  --env PX4_GZ_MODEL=x500 \
  --env DISPLAY="${DISPLAY:-:0}" \
  --net=host \
  --ipc=host \
  --pid=host \
  -v "${PX4_SIM_DIR}":/px4_scripts:rw \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  ${CONTAINER_OPTIONS} \
  ${VOLUME_OPTION} \
  --name="${CONTAINER_NAME}" "${IMAGE_NAME}" bash
