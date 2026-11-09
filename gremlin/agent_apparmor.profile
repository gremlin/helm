#include <tunables/global>


profile gremlin-agent flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  # Everything is allowed by default; the deny rules below carve out what the agent must not touch.
  # The /proc and /sys denies follow moby's docker-default profile.
  network,
  file,

  # Container runtime sockets and gremlind's control socket (/var/lib/gremlin/gremlin.sock)
  unix,

  # Process Killer, plus halting/rolling back the agent's own attack processes. Killing a process in
  # another container also needs that container's profile to allow receiving the signal.
  signal,

  # Reading other processes' /proc/<pid>/{fd,exe,ns,root,net} for discovery and container targeting
  ptrace (read),

  capability kill,            # Process Killer, halting attacks
  capability net_admin,       # tc for network attacks and Time Travel NTP blocking
  capability net_raw,         # DNS dependency discovery (packet capture)
  capability sys_boot,        # Shutdown
  capability sys_time,        # Time Travel
  capability sys_resource,    # oom_score_adj for container Memory and Process Exhaustion
  capability sys_admin,       # setns into container namespaces
  capability sys_ptrace,      # reading other processes' /proc entries
  capability dac_read_search, # reading other processes' /proc entries

  deny mount,

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
  deny /usr/** wl,

  deny /dev/{mem,kmem,port} rwklx,

  deny @{PROC}/* w,   # deny write for all files directly in /proc (not in a subdir)
  # deny write to files not in /proc/<number>/** or /proc/sys/**
  deny @{PROC}/{[^1-9/],[^1-9/][^0-9/],[^1-9s/][^0-9y/][^0-9s/],[^1-9/][^0-9/][^0-9/][^0-9/]*}/** w,
  deny @{PROC}/sys/** w,
  deny @{PROC}/sysrq-trigger rwklx,
  deny @{PROC}/mem rwklx,
  deny @{PROC}/kmem rwklx,
  deny @{PROC}/kcore rwklx,

  # Everything in /sys that's not cgroups
  deny /sys/[^f]*/** wklx,
  deny /sys/f[^s]*/** wklx,
  deny /sys/fs/[^c]*/** wklx,
  deny /sys/fs/c[^g]*/** wklx,
  deny /sys/fs/cg[^r]*/** wklx,
  deny /sys/firmware/** rwklx,
  deny /sys/devices/virtual/powercap/** rwklx,
  deny /sys/kernel/security/** rwklx,
}
