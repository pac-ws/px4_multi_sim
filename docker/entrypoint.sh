#!/bin/bash

# Start virtual X server in the background
# - DISPLAY default is :99, set in dockerfile
# - Users can override with `-e DISPLAY=` in `docker run` command to avoid
#   running Xvfb and attach their screen
if [[ -x "$(command -v Xvfb)" && "$DISPLAY" == ":99" ]]; then
	echo "Starting Xvfb"
	Xvfb :99 -screen 0 1600x1200x24+32 &
fi

# Check if the ROS_DISTRO is passed and use it
# to source the ROS environment
if [ -n "${ROS_DISTRO}" ]; then
	source "/opt/ros/$ROS_DISTRO/setup.bash"
fi

if [ -n "${LOCAL_USER_ID}" ]; then
	echo "Starting with UID : $LOCAL_USER_ID"
	# modify existing user's id
	usermod -u $LOCAL_USER_ID user
  usermod -aG sudo user
  usermod -aG video user
  usermod -aG render user
  usermod -aG wheel user
  echo "user:user" | chpasswd
  chown -R user /home/user
  chown -R user /opt
  gosu user /bin/bash -c "git config --global init.defaultBranch main"
	# run as user
  gosu user rosdep update
	exec gosu user "$@"
else
	exec "$@"
fi
