# PX4 Multi-Vehicle Simulation using Docker containers

### Setup

```bash
# Change ROS_DOMAIN_ID in px4_main.sh
# Default is 10
# Edit ids and poses of robots: robots_poses.sh
```

```bash
# Create a container
bash px4_main.sh -c
```
**Note:** You can add `-d <dir>` to specify the directory to mount in the container

```bash
# Launch xrce_agent
bash px4_main.sh -x
```

```bash
# Launch gazebo_sim on a new terminal
bash px4_main.sh -s
# bash px4_main.sh -s --headless # for no GUI
```

```bash
# Launch multiple robots
bash px4_main.sh -r
```

```bash
# Launch a bash shell to check ros messages
bash px4_main.sh -b
```

### Notes and links

https://docs.px4.io/main/en/sim_gazebo_gz/worlds.html
https://docs.px4.io/main/en/sim_gazebo_gz/#specify-world


https://docs.px4.io/main/en/sim_gazebo_gz/#headless-mode

##### simulation-gazebo args
https://github.com/PX4/PX4-gazebo-models/blob/main/simulation-gazebo
```python
    parser.add_argument('--world', help='World to run in Gazebo', required=False, default="default")
    parser.add_argument('--gz_partition', help='Gazebo partition to run in', required=False)
    parser.add_argument('--gz_ip', help='Outgoing network interface to use for traffic',required=False)
    parser.add_argument('--interactive',help='Run in interactive mode', required=False, default=False, action='store_true')
    parser.add_argument('--model_download_source', help='Path to directory containing model files', required=False, default=DEFAULT_DOWNLOAD_DIR)
    parser.add_argument('--model_store', help='Path to model storage directory', required=False, default="~/.simulation-gazebo")
    parser.add_argument('--overwrite', help='Overwrite existing model directories', required=False, default=False, action='store_true')
    parser.add_argument('--dryrun', help='Test in dryrun. Do not launch gazebo', required=False, default=False, action='store_true')
    parser.add_argument('--headless', help='Run Gazebo without GUI', required=False, default=False, action='store_true')
```

https://docs.px4.io/main/en/test_and_ci/docker.html#qgroundcontrol
