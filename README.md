# buildkite-agent-server-setup
Setup a [buildkite](https://buildkite.com) agent on linux.

## Setup
1. `git clone https://github.com/lukeaus/buildkite-agent-server-setup.git`

2. edit 'VARIABLES' section at top of buildkite-agent-script.sh with your github and buildkite details

3. Create your pipeline on buildkite.
Use BUILDKITE_CLEAN_CHECKOUT=true in the Environment Variables for the job. Docker builds can leave behind files owned by another user. By default, Docker runs every process as root so if you mount the build directory as a Docker volume and generate files in your build they will be owned by root and the agent will be unable to remove them.

4. Login to your new server<br />
`ssh root@<SERVER-IP-ADDRESS>`<br />
Note: ensure you have added your local dev machine ssh key to the server first (usually you do this when creating the server)

5. Copy this script and a few others to server
Open a new shell window and run:<br />
`scp /path/to/setup_server_as_ci_buildkite_agent.sh /path/to/buildkite-agent-hooks/environment /path/to/fix-buildkite-agent-builds-permissions root@<SERVER-IP-ADDRESS>:/root`

6. Run this script with root privileges:<br />
`sudo ./setup_server_as_ci_buildkite_agent.sh`<br />
if any issues - make sure this script and the other scripts are executable<br />
`chmod +x script.sh`

7. Once script is complete go to https://buildkite.com/organizations/myorg/agents and
check that the new agent is present

8. Trigger a build on buildkite to get started.

## Notes
This script can take up to 5 minutes to run, primarily because the docker install
component of this script can be slow at times.

If you are speed testing then you need to run a build twice and take the time
from the second build. The first build will be very slow because you need to pull all the docker
images. The second build should represent a normal speed.
