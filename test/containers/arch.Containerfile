# SPDX-License-Identifier: GPL-2.0-or-later
#
# Arch Linux for test/update-routes.sh: the engine's build dependencies,
# kpackagetool6, git, python, and a user "tester" who may use sudo inside the
# container.
FROM docker.io/library/archlinux:latest
RUN pacman -Syu --noconfirm --needed base-devel cmake qt6-base qt6-declarative qt6-5compat \
        kcoreaddons kpty git sudo kpackage python \
    && pacman -Scc --noconfirm \
    && useradd -m tester \
    && echo 'tester ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/tester
USER tester
WORKDIR /home/tester

# kpackagetool6 cannot install a Plasma/Applet package without Plasma's applet
# structure, which comes with libplasma.
USER root
RUN pacman -Sy --noconfirm --needed libplasma && pacman -Scc --noconfirm
USER tester

# ccache lets the test's many fresh containers reuse what an earlier one
# compiled.
USER root
RUN pacman -Sy --noconfirm --needed ccache && pacman -Scc --noconfirm
USER tester
