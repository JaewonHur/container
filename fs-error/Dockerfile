FROM debian:stable-slim
RUN apt-get update && \
    apt-get install -y ca-certificates curl gnupg git make && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin && \
    apt-get purge -y gnupg && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*
COPY <<'EOF' /entrypoint.sh
#!/bin/sh
set -e
mkdir -p /sys/fs/cgroup/init.slice
for pid in $(cat /sys/fs/cgroup/cgroup.procs); do
    echo $pid > /sys/fs/cgroup/init.slice/cgroup.procs 2>/dev/null || true
done
echo "+cpu +cpuset +memory" > /sys/fs/cgroup/cgroup.subtree_control

if [ ! -d /opt/opentelemetry-demo ]; then
    git clone --depth 1 https://github.com/open-telemetry/opentelemetry-demo.git /opt/opentelemetry-demo
fi

exec dockerd --iptables=false --ip6tables=false --host=unix:///var/run/docker.sock
EOF

COPY <<'EOF' /start.sh
#!/bin/sh
while ! docker info >/dev/null 2>&1; do sleep 1; done
cd /opt/opentelemetry-demo && make start
EOF

RUN chmod +x /entrypoint.sh /start.sh
ENTRYPOINT ["/entrypoint.sh"]
