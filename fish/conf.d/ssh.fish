set -gx SSH_AUTH_SOCK /run/user/1000/ssh-agent.socket

function load_ssh_key
    set key $argv[1]
    ssh-add -l | grep -q $key
    or ssh-add $key >/dev/null 2>&1
end

load_ssh_key ~/.ssh/basestation_ed25519
load_ssh_key ~/.ssh/github_ed25519
