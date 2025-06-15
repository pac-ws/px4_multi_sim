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
Usage:

  create                                 Create a new container
      1. Automatically detects if GPU is available using nvidia-smi
      2. Assumes px4_multi_sim is located at \${PAC_WS}/px4_multi_sim
      3. ROS_DOMAIN_ID is set to 10
      4. Container name defaults to 'px4_sim'
    Use the following options to override defaults:
      --no-gpu                           Disable GPU support
      --ros-domain-id <domain id>        Specify the ROS domain ID
      --mount-dir <mount directory>      Specify the directory to mount

  xrce                                   Start MicroXRCEAgent
  sim                                    Start Gazebo simulator
      --headless                         Run in headless mode (valid only with -s|--sim)
      --world <world name>               Specify the Gazebo world (valid only with -s|--sim)
  robots                                 Launch multiple robots (see robots_execs.sh)
  bash                                   Start an interactive bash shell
  delete <container_name>                Delete the container (default: px4_main)

  -h, help                               Show this help message and exit

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

is_container_running() {
  local cname="${1:-$CONTAINER_NAME}"
  if ! docker ps -q -f name="^${cname}$" | grep -q .; then
      error_exit "Container '${cname}' is not running. Please create the container first."
  fi
}

docker_cmd() {
  if [[ -z "${1:-}" || -z "${2:-}" ]]; then
    error_exit "Missing container name or command. Usage: docker_cmd <container_name> <command>"
  fi
  CONTAINER_NAME="${1}"
  shift
  is_container_running "${CONTAINER_NAME}"
  info_message "Running command '$*' in container '${CONTAINER_NAME}'..."
  docker exec -it "${CONTAINER_NAME}" bash -ci "$*"
}

# Ensure required commands are available
for cmd in docker getopt; do
  if ! command_exists "$cmd"; then
    error_exit "'$cmd' command is not found. Please install it before running this script."
  fi
done

if [[ $# -eq 0 ]]; then
  print_usage
  exit 1
fi

# Initialize variables with default values
CONTAINER_NAME="px4_sim"
WORLD="grid"
# WORLD="simple_baylands"
HEADLESS=""
CONTAINER_OPTIONS=""
PX4_SIM_DIR="${PAC_WS}/px4_multi_sim"
USE_GPU=false
if [ "$(command -v nvidia-smi)" ]; then
  USE_GPU=true
fi

case "$1" in
  -c|create)
    bash ${PX4_SIM_DIR}/create_container.sh -d ${PX4_SIM_DIR} -n ${CONTAINER_NAME} "${@:2}"
    ;;
  -b|bash)
    docker_cmd "${CONTAINER_NAME}" "bash" "${@:2}"
    ;;
  -x|xrce)
    docker_cmd "${CONTAINER_NAME}" MicroXRCEAgent udp4 -p 8888
    ;;
  delete)
    is_container_running "${CONTAINER_NAME}"
    docker stop "${CONTAINER_NAME}"
    ;;
  -r|robots)
    docker_cmd "${CONTAINER_NAME}" "/px4_scripts/robots_execs.sh" "/px4_scripts/robots_poses.sh"
    ;;
  -s|sim)
    xhost +local:docker
    # Check if the remaining arguments contain world or headless options
    while [[ $# -gt 1 ]]; do
      case "$2" in
        --world)
          WORLD="$3"
          shift 2
          ;;
        --headless)
          HEADLESS="--headless"
          shift
          ;;
        *)
          error_exit "Unknown option: $2"
          ;;
      esac
    done
    docker_cmd "${CONTAINER_NAME}" "python \"\${PX4_DIR}/Tools/simulation/gz/simulation-gazebo\" --world \"${WORLD}\" ${HEADLESS}"
    ;;
  -h|help)
    print_usage
    exit 0
    ;;
  *)
    info_message "Internal error: unexpected option '$1'" >&2
    print_usage
    ;;
esac
