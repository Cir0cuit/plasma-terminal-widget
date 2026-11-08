# SPDX-License-Identifier: GPL-2.0-or-later
#
# Debian 13 (trixie) for test/update-routes.sh: the engine's build
# dependencies, kpackagetool6, git, python3, and a user "tester" who may use
# sudo inside the container.
FROM docker.io/library/debian:trixie
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        cmake build-essential qt6-base-dev qt6-declarative-dev qt6-5compat-dev \
        libkf6coreaddons-dev libkf6pty-dev \
        git sudo ca-certificates kpackagetool6 qml6-module-qtquick qml6-module-qtquick-window python3 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash tester \
    && echo 'tester ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/tester
USER tester
WORKDIR /home/tester

# kpackagetool6 cannot install a Plasma/Applet package without Plasma's applet
# structure, which comes with libplasma6; plasma-desktoptheme is the theme it
# expects.
USER root
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libplasma6 plasma-desktoptheme && rm -rf /var/lib/apt/lists/*
USER tester

# ccache lets the test's many fresh containers reuse what an earlier one
# compiled.
USER root
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ccache && rm -rf /var/lib/apt/lists/*
USER tester
