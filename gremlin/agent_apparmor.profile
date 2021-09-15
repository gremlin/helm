#include <tunables/global>


profile gremlin-agent flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  network,
  file,
  umount,

  /entrypoint.sh rix,
  /var/lib/gremlin/** rwix,
  /var/log/gremlin/** rwix,
  /etc/gremlin/** rwix,

  # Container runtime
  /run/docker/runtime-runc/moby rwix,
  /var/run/docker.sock rwix,
  /run/crio/crio.sock rwix,
  /run/runc rwix,
  /run/containers/containers.sock rwix,
  /run/containerd/runc/k8s.io rwix,

  # We need access to Pid 1's real pid to resolve the container driver
  # we're just taking a read perm here to accomlish this
  file r @{PROC}/1/ns/pid,
  ptrace read,


  # Attack capabilities
  /proc/sysrq-trigger w,
  /sys/fs/cgroup r,
  /proc/** rl,

  # Needed For Gremlin Attacks
  capability sys_boot,
  capability sys_time,
  capability net_admin,
  capability kill,
  capability setfcap,
  capability audit_write,
  capability mknod,

  # Needed for Gremlin Service Discovery
  capability dac_read_search,
  capability sys_ptrace,

  # General deny
  deny /proc/** w,

  deny /bin/** wl,
  deny /boot/** wl,
  deny /dev/** wl,
  deny /etc/** wl,
  deny /home/** wl,
  deny /lib/** wl,
  deny /lib64/** wl,
  deny /media/** wl,
  deny /mnt/** wl,
  deny /root/** wl,
  deny /sbin/** wl,
  deny /srv/** wl,
  deny /tmp/** wl,
  deny /sys/** wl,
  deny /usr/** wl,

  audit /** w,

  deny /bin/sh mrwklx,
  deny /usr/bin/top mrwklx,


  deny @{PROC}/* w,   # deny write for all files directly in /proc (not in a subdir)
  # deny write to files not in /proc/<number>/** or /proc/sys/**
  deny @{PROC}/{[^1-9],[^1-9][^0-9],[^1-9s][^0-9y][^0-9s],[^1-9][^0-9][^0-9][^0-9]*}/** w,
  deny @{PROC}/sys/[^k]** w,  # deny /proc/sys except /proc/sys/k* (effectively /proc/sys/kernel)
  deny @{PROC}/sys/kernel/{?,??,[^s][^h][^m]**} w,  # deny everything except shm* in /proc/sys/kernel/
  deny @{PROC}/sysrq-trigger wklx,
  deny @{PROC}/mem wklx,
  deny @{PROC}/kmem wklx,
  deny @{PROC}/kcore wklx,

  deny mount,

  deny /sys/[^f]*/** wklx,
  deny /sys/f[^s]*/** wklx,
  deny /sys/fs/[^c]*/** wklx,
  deny /sys/fs/c[^g]*/** wklx,
  deny /sys/fs/cg[^r]*/** wklx,
  deny /sys/firmware/** wklx,
  deny /sys/kernel/security/** wklx,
}
