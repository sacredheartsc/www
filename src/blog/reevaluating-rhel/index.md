---
title: Re-evaluating RHEL
date: June 25, 2023
description: Responding to RedHat's latest rug-pull.
---

Last Wednesday, I woke up to news that IBM's RedHat was [ceasing public releases
of source code for RedHat Enterprise Linux](https://www.redhat.com/en/blog/furthering-evolution-centos-stream).
Going forward, "[CentOS Stream](https://www.centos.org/centos-stream/) will now
be the sole repository for public RHEL-related source code releases."

Prior to last week, all the source RPMs for each RHEL release were published on
[git.centos.org](https://git.centos.org/). When RedHat abruptly killed CentOS as
we knew it in 2019 (*requiescat in pace*), the availability of these sources allowed
fledgeling distros like [Rocky](https://rockylinux.org/) and [Alma](https://almalinux.org/)
Linux to quickly take its place.

Presumably, the bean-counters at RedHat were none too pleased with the proles'
clever workaround, and have decided to take their toys and go home. (I'm sure
[Rocky's recent NASA contract](https://twitter.com/rocky_linux/status/1668781190520918019)
didn't help either.)

Much pontification has taken place on Twitter and the Fediverse regarding
the ethical and legal implications of this move. I'm not going to rehash them,
as I honestly find such things tedious and boring. The Software Freedom Conservancy
has written a detailed analysis of the situation [here](https://sfconservancy.org/blog/2023/jun/23/rhel-gpl-analysis/).

To summarize: RedHat almost certainly has the right to do this, even if it is
against the spirit of most free software licenses and unprecedented in the FOSS
community until now. At the moment, I'm more concerned about how this will affect
my own projects.

## I'm heavily invested in Rocky Linux.

I self-host my entire digital footprint on Rocky Linux. Email, XMPP, Matrix, VOIP,
Mastodon, git repositories, network storage, web servers, desktops...everything
runs on Rocky virtual machines.

I've spent the last year or so building out an [Ansible framework](https://github.com/sacredheartsc/selfhosted)
to manage it all. Just as I was getting everything dialed in and perfected,
RedHat pulled the rug yet again.

Switching to another Linux flavor is not trivial, since my entire infrastructure
depends on [FreeIPA](https://freeipa.org/) for identity management. User accounts,
groups, internal DNS records, sudo rules, and access control are all handled by FreeIPA.
My Ansible framework is tightly coupled to the FreeIPA [Ansible modules](https://github.com/freeipa/ansible-freeipa).

FreeIPA is developed and tested on RedHat-based distributions: Fedora, CentOS,
and RHEL. While packages do exist for other distros, they're definitely second-class
citizens. I'd rather not depend on them for production use.

## So what's next?

With nearly all of my digital life dependent on a RHEL derivative, it's time to
re-evaluate my choice of operating system. Some options:

### Stick with Rocky Linux?

This is definitely the easiest course of action, since it requires no additional
work on my part. After all, Rocky and Alma have
[both](https://rockylinux.org/news/brave-new-world-path-forward/)
[assured](https://almalinux.org/blog/impact-of-rhel-changes/)
us that updates will keep coming as usual, that this is a minor setback, and that
everything will be fine. But realistically, what else *could* they say at this point?

It seems like both distros have currently found a way to keep pushing updates, but
I haven't seen any public statements about how exactly they're accomplishing this (perhaps
a strategic omission?).

To me, there's three major downsides to sticking with a RHEL-derivative:

- What's stopping RedHat from doing another rug-pull that thwarts whatever
  future workarounds that Rocky, Alma, *et al.* are using to grab the source RPMs?

- This may be the final straw that causes various FOSS projects to drop RHEL
  support altogether ([Exhibit A](https://www.jeffgeerling.com/blog/2023/removing-official-support-red-hat-enterprise-linux)). 

- By sticking with a RHEL-based distro, I'm giving my implicit support to RedHat's
  mistreatment of the wider FOSS community. Feels gross--maybe it's just time to
  move on?

First, **immediately after** everyone got done migrating the CentOS 8, RedHat
pulled the plug on CentOS.

Then, **immediately after** the CentOS replacements gained critical mass, RedHat
pulled the rug on public source code!

*Fool me once, shame on you. Fool me twice, shame on me.*

All that being said, I'd really like to stick with Rocky if possible. It's an
incredible distro and really hits a sweet spot for professional features (SELinux,
FreeIPA, RPM packaging), stability, active community, and long support cycles.

### RHEL Developer Program?

Won't work for me. I currently have no fewer than 37 Rocky Linux installs (mostly KVM
virtual machines), but RedHat's [free tier](https://developers.redhat.com/articles/faqs-no-cost-red-hat-enterprise-linux)
only gives you a license for 16 hosts.

### Ubuntu LTS?

Hard pass. `/dev/null` will soon be provided by a Snap package at the rate things are going.

### Switch to Debian?

If Rocky disappears, Debian is probably the most logical choice. It's been around
forever with no corporate ties, and has near-universal package availability. In addition,
I already run a Debian-based hypervisor ([Proxmox](https://www.proxmox.com/)).

There are some downsides though:

- Debian Stable is only supported for 5 years, compared to RHEL's 10 years (this
  doesn't actually bother me *that* much).

- `apt` is annoying compared to `dnf`...but this is a minor complaint.

- Janky FreeIPA support. I'm sure you can `apt-get install freeipa-server` and
  have things *mostly* work, but roughly no one runs a FreeIPA domain on Debian. I'd
  definitely be off the beaten path.

Maybe I'm exaggerating the issues with Debian-based FreeIPA, but I haven't had good
experiences with it in the past. I've also run Samba 4 in [domain controller mode](https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller)...don't
think I can go through that again.

Another option would be to roll a poor-man's FreeIPA with
[OpenLDAP](https://www.openldap.org/),
[BIND](https://www.isc.org/bind/),
a [Kerberos KDC](https://web.mit.edu/kerberos/),
and
[nslcd](https://github.com/arthurdejong/nss-pam-ldapd). This seems like a lot
of work, but maybe it would pay off in the long run to be totally decoupled from RHEL?

### FreeBSD? Illumos?!

A move to [FreeBSD](https://www.freebsd.org/) or an Illumos-based distro like
[OmniOS](https://omnios.org/) does have a certain Unix nostalgia appeal.

FreeBSD has [jails](https://docs.freebsd.org/en/books/handbook/jails/), and each release
is supported for 5 years. OmniOS has Solaris [zones](https://docs.oracle.com/cd/E19455-01/817-1592/zones.intro-1/index.html),
which are amazing, but the LTS release only has a 3-year support window.

I would honestly prefer to use a real Unix, since Linux has run on the [CADT model](https://www.jwz.org/doc/cadt.html)
since the 2000s. Unfortunately, since we live in a Linux monoculture, using anything
not-Linux means you must also become a package maintainer, and spend your days
filing issue reports for your bespoke hipster Unix in various bug trackers.

I actually used to run my entire infrastructure on [SmartOS](https://www.tritondatacenter.com/smartos),
but it feels like betting on a losing horse at this point. Debian will almost certainly be
around 10 years from now. *Illumos*...?

## I'm mostly just annoyed.

The classic CentOS model was stable, reliable, and boring: the perfect platform
for my self-hosted fiefdom. I have a regular `$DAYJOB` and a growing family--three
small kids and counting! I need a low-maintenance distro that
stays out of my way for long periods of time. So far, Rocky Linux has provided
exactly that.

In the short term, I'll keep my eyes on the RHEL situation and continue maintaining
[sacredheart-selfhosted](https://github.com/sacredheartsc/selfhosted) as a
Rocky Linux-based framework.

I don't really care about bug-for-bug compatibility with RHEL. If Rocky or Alma
manages to emerge as some kind of de-facto "almost-RHEL" with a long support cycle,
that's what I'll stick with. Otherwise, I see Debian in my future.

<aside>
*P.S. I wrote this article on the Feast of Saint John the Baptist, the patron saint of
the Diocese of Charleston and of unborn children. Saint John the Baptist, pray for us!*
</aside>
