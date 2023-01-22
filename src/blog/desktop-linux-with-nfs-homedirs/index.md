---
title: Desktop Linux with NFS Home Directories
date: January 19, 2023
subtitle: Something no one does anymore, apparently.
description: Issues you'll face with NFS-mounted homedirs, and some workarounds.
---

I manage multiple [Rocky Linux](https://rockylinux.org/) workstations that automount
users' home directories via kerberized NFS. Unfortunately, I don't think this is a common
setup anymore--I encountered a few bugs and performance issues that needed non-obvious
workarounds.

## Problems

### 1. Things break when you log in from two places at once

If you can somehow restrict your users to a single GNOME session at any given time,
you'll probably be fine. However, as soon as someone leaves his desktop running and
logs into another workstation, strange things begin to happen. Here are some oddities
I've observed:

  - GNOME settings on one machine are clobbered by the other (this may or may not be desirable).

  - Firefox refuses to run, because the profile directory is already in use.

  - `gnome-keyring` freaks out and creates many login keyrings under `~/.local/share/keyrings`,
    losing previously stored secrets in the process!

  - Sound quits working (I suspect this is due to `~/.config/pulse/cookie` being clobbered).

  - Flatpak apps completely blow up (each app stores its state in `~/.var`, and
    [this is nonconfigurable](https://github.com/flatpak/flatpak/issues/1651)). Running
    multiple instances of `signal-dekstop` instantly corrupts the sqlite database.

  - `goa-daemon` generates thousands of syslog messages per minute (I am unsure if this is
    due to `~/.config/goa-1.0/accounts.conf` getting clobbered, or a symptom of
    [this bug](https://gitlab.gnome.org/GNOME/gnome-online-accounts/-/issues/32)).
    I have no idea what `goa-daemon` does, nor do I want to. I have been victimized by
    [the bazaar](http://www.catb.org/~esr/writings/cathedral-bazaar/cathedral-bazaar/)
    enough for one lifetime.

### 2. It's slow

I/O-heavy tasks, like compiling and grepping, will be much slower over NFS than the local
disk. Browser profiles stored on NFS (`~/.mozilla`, `~/.cache/chromium`, etc.) provide
a noticeably poor experience.

File browsing is also painful if you have lots of images or videos. Thumbnails for
files stored on NFS will be cached in `~/.cache/thumbnails`, which is **also** stored
on NFS!

## Solution: Move stuff to local storage

The [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
lets you change the default locations of `~/.cache`, `~/.config`, and the like by setting
some environment variables in the user's session.  We can solve most of these problems
by moving the various XDG directories to the local disk.

### Automatically provision local home directories

First, let's write a script that automatically provisions a _local_ home directory
whenever someone logs in:

````bash
#!/bin/bash

# /usr/local/sbin/create-local-homedir.sh

# Log all output to syslog.
exec 1> >(logger -s -t $(basename "$0")) 2>&1

PAM_UID=$(id -u "${PAM_USER}")

if (( PAM_UID >= 1000 )); then
  install -o "${PAM_USER}" -g "${PAM_USER}" -m 0700 -d "/usr/local/home/${PAM_USER}"
fi
````

Of course, it needs to be executable:

````bash
chmod 755 /usr/local/sbin/create-local-homedir.sh
````

Next, we modify the PAM configuration to execute our script whenever anyone logs in
via GDM or SSH:

````diff
--- /etc/pam.d/gdm-password
+++ /etc/pam.d/gdm-password
@@ -1,5 +1,6 @@
 auth     [success=done ignore=ignore default=bad] pam_selinux_permit.so
 auth        substack      password-auth
+auth        optional      pam_exec.so /usr/local/sbin/create-local-homedir.sh
 auth        optional      pam_gnome_keyring.so
 auth        include       postlogin

--- /etc/pam.d/sshd
+++ /etc/pam.d/sshd
@@ -15,3 +15,4 @@
 session    optional     pam_motd.so
 session    include      password-auth
 session    include      postlogin
+session    optional     pam_exec.so /usr/local/sbin/create-local-homedir.sh
````

<details>
<summary>A note on SELinux</summary>

If you're using SELinux, you'll need a separate copy of the `create-local-homedir` script
for use with GDM, labeled with `xdm_unconfined_exec_t`:

````bash
ln /usr/local/sbin/create-local-homedir{,-gdm}.sh
semanage fcontext -a -t xdm_unconfined_exec_t /usr/local/sbin/create-local-homedir-gdm.sh
restorecon -v /usr/local/sbin/create-local-homedir-gdm.sh
````

Be sure to modify `/etc/pam.d/gdm-password` appropriately.

</details>

### Set XDG Environment Variables

We need to tell the user's applications to use the new local home directory
for storage. We have to do this early in the PAM stack for GDM, because `$XDG_DATA_HOME`
must be set before `gnome-keyring` gets executed.

Edit your PAM files again, adding one more line:

````diff
--- /etc/pam.d/gdm-password
+++ /etc/pam.d/gdm-password
@@ -1,6 +1,7 @@
 auth     [success=done ignore=ignore default=bad] pam_selinux_permit.so
 auth        substack      password-auth
 auth        optional      pam_exec.so /usr/local/sbin/create-local-homedir.sh
+auth        optional      pam_env.so conffile=/etc/security/pam_env_xdg.conf
 auth        optional      pam_gnome_keyring.so
 auth        include       postlogin

--- /etc/pam.d/sshd
+++ /etc/pam.d/sshd
@@ -16,3 +16,4 @@
 session    include      password-auth
 session    include      postlogin
 session    optional     pam_exec.so /usr/local/sbin/create-local-homedir.sh
+session    optional     pam_env.so conffile=/etc/security/pam_env_xdg.conf
````

Then, create the corresponding `pam_env.conf(5)` file:

````default
# /etc/security/pam_env_xdg.conf

XDG_DATA_HOME    DEFAULT=/usr/local/home/@{PAM_USER}/.local/share
XDG_STATE_HOME   DEFAULT=/usr/local/home/@{PAM_USER}/.local/state
XDG_CACHE_HOME   DEFAULT=/usr/local/home/@{PAM_USER}/.cache
XDG_CONFIG_HOME  DEFAULT=/usr/local/home/@{PAM_USER}/.config
````

### Hacks for Non-XDG-Compliant Apps

Unfortunately, since a majority of open source developers follow the
[CADT model](https://www.jwz.org/doc/cadt.html), there are many apps that ignore the
XDG specification. Sometimes these apps have their own environment variables
for specifying their storage locations. Otherwise, symlinks can provide us with an escape
hatch.

Create a script in `/etc/profile.d` for these workarounds. Scripts in this directory
are executed within the context of the user's session, so we can freely write inside
his NFS home directory using his UID (and kerberos ticket, if applicable).

````bash
# /etc/profile.d/local-homedirs.sh

if (( UID >= 1000 )); then
  # Building code is *much* faster on the local disk. Modify as needed:
  export PYTHONUSERBASE="/usr/local/home/${USER}/.local"  # python
  export npm_config_cache="/usr/local/home/${USER}/.npm"  # nodejs
  export CARGO_HOME="/usr/local/home/${USER}/.cargo"      # rust
  export GOPATH="/usr/local/home/${USER}/go"              # golang

  # Firefox doesn't provide an environment variable for setting the default profile
  # path, so we'll just symlink it to /usr/local/home.
  mkdir -p "/usr/local/home/${USER}/.mozilla"
  ln -sfn "/usr/local/home/${USER}/.mozilla" "${HOME}/.mozilla"

  # Flatpak hardcodes ~/.var, so symlink it to /opt/flatpak.
  ln -sfn "/opt/flatpak/${USER}" "${HOME}/.var"
fi
````

If you use any Flatpak apps, each user will need his own local Flatpak directory.
The Flatpak runtime appears to shadow the entire `/usr` using mount namespaces,
so any `/usr/local/home` symlinks will disappear into the abyss. Luckily, `/opt`
appears to be undefiled. Modify your original script like so:

````diff
--- /usr/local/sbin/create-local-homedir.sh
+++ /usr/local/sbin/create-local-homedir.sh
@@ -6,4 +6,5 @@

 if (( PAM_UID >= 1000 )); then
   install -o "${PAM_USER}" -g "${PAM_USER}" -m 0700 -d "/usr/local/home/${PAM_USER}"
+  install -o "${PAM_USER}" -g "${PAM_USER}" -m 0700 -d "/opt/flatpak/${PAM_USER}"
 fi
````

## Closing Thoughts

Most of my users are nontechnical, so I'm pleased that these workarounds do not require
any manual intervention on their part.

I am sad that `$XDG_CONFIG_HOME` can't be shared between multiple workstations reliably.
When I change my desktop background or add a new password to `gnome-keyring`, it only
affects the local machine.

Initially, I tried symlinking various subdirectories of `~/.config` to the local disk
individually as I encountered different bugs (e.g. `~/.config/pulse`). Unfortunately this
proved brittle, as I was constantly playing whack-a-mole with apps that abused `$XDG_CONFIG_HOME`
for storing local state.  In the end, it was less of a headache to just dump the whole thing
onto the local disk.

I suppose if you verified an app behaved properly with multiple simultaneous NFS clients,
you could always symlink `/usr/local/home/$USER/.config/$APP` **back** onto NFS!
