# SPDX-License-Identifier: GPL-2.0-or-later
#
# Fedora 45 for test/update-routes.sh: the engine's build dependencies,
# kpackagetool6, git, python3, and a user "tester" who may use sudo inside the
# container.
FROM registry.fedoraproject.org/fedora:45
RUN dnf -y --setopt=install_weak_deps=False install \
        cmake gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel \
        qt6-qt5compat-devel kf6-kcoreaddons-devel kf6-kpty-devel \
        git sudo kf6-kpackage procps-ng findutils which python3 \
    && dnf clean all \
    && useradd -m tester \
    && echo 'tester ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/tester
USER tester
WORKDIR /home/tester

# kpackagetool6 cannot install a Plasma/Applet package without Plasma's applet
# structure, which comes with libplasma.
USER root
RUN dnf -y --setopt=install_weak_deps=False install libplasma && dnf clean all
USER tester

# ccache lets the test's many fresh containers reuse what an earlier one
# compiled.
USER root
RUN dnf -y --setopt=install_weak_deps=False install ccache && dnf clean all
USER tester

# Fedora's Qt logs to the journal, which a container does not have; the test
# reads the scripts' output, so keep Qt's messages on stderr.
ENV QT_FORCE_STDERR_LOGGING=1
