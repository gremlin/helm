#include <tunables/global>


profile gremlin-agent flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  network,
  file,
  umount,
  mount,

  /entrypoint.sh rix,
  /var/lib/gremlin/** rwix,
  /var/log/gremlin/** rwix,
  /etc/gremlin/** rwix,

  # /dev/null
  /dev rix,
  /dev/null rwlix,

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
  /sys/fs/cgroup/** rw,
  /proc/** rl,
  # In order to join target container network space
  @{PROC}/[0-9]+/ns/net w,
  # In order to assume the root of the target container
  pivot_root,

  # Needed for specific Gremlin Attacks
  capability sys_boot,
  capability sys_time,
  capability sys_admin, # needed for setns
  capability net_admin,
  capability kill,
  capability setfcap,
  capability audit_write,
  capability mknod,

  # Needed to execute attacks
  capability net_bind_service,
  capability setuid,
  capability setgid,
  capability chown,

  # Needed for Gremlin Service Discovery
  capability dac_read_search,
  capability sys_ptrace,

  # General deny
  deny /bin/** wl,
  deny /boot/** wl,
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
  deny /usr/** wl,

  # No write in /dev except /dev/null
  deny /dev/[^n]*/** wl,
  deny /dev/n[^u]*/** wl,
  deny /dev/nu[^l]*/** wl,
  deny /dev/nul[^l]*/** wl,

  deny /usr/bin/top mrwklx,


  deny @{PROC}/* w,   # deny write for all files directly in /proc (not in a subdir)
  # deny write to files not in /proc/<number>/** or /proc/sys/**
  deny @{PROC}/{[^1-9],[^1-9][^0-9],[^1-9s][^0-9y][^0-9s],[^1-9][^0-9][^0-9][^0-9]*}/** w,
  deny @{PROC}/sys/[^k]** w,  # deny /proc/sys except /proc/sys/k* (effectively /proc/sys/kernel)
  deny @{PROC}/sys/kernel/{?,??,[^s][^h][^m]**} w,  # deny everything except shm* in /proc/sys/kernel/
  deny @{PROC}/sysrq-trigger klx,
  deny @{PROC}/mem wklx,
  deny @{PROC}/kmem wklx,
  deny @{PROC}/kcore wklx,

  # Everything in /sys/fs that's not cgroups
  deny /sys/[^f]*/** wklx,
  deny /sys/f[^s]*/** wklx,
  deny /sys/fs/[^c]*/** wklx,
  deny /sys/fs/c[^g]*/** wklx,
  deny /sys/fs/cg[^r]*/** wklx,

  deny /sys/firmware/** wklx,
  deny /sys/kernel/security/** wklx,
}
