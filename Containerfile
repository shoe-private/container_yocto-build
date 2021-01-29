# origin https://raw.githubusercontent.com/bstubert/dr-yocto/62f67a6dfe575f7fcddfd979f81be4e1b6d19f2e/18.04/Dockerfile
# Use Ubuntu 18.04 LTS (Bionic Beaver) as the basis for the Docker image.
FROM docker.io/ubuntu:18.04

# Install all Linux packages required for Yocto builds as given in section "Build Host Packages"
# on https://www.yoctoproject.org/docs/3.0.2/brief-yoctoprojectqs/brief-yoctoprojectqs.html.
# I added the package git-lfs, which I found missing during a Yocto build.
# Without DEBIAN_FRONTEND=noninteractive, the image build hangs indefinitely
# at "Configuring tzdata". Even if you answer the question about the time zone, it will
# not proceed.
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    gawk wget git-core diffstat unzip texinfo gcc-multilib \
    build-essential chrpath socat cpio python python3 python3-pip python3-pexpect \
    xz-utils debianutils iputils-ping python3-git python3-jinja2 \
    pylint3 xterm tar file git-lfs locales

# By default, Ubuntu uses dash as an alias for sh. Dash does not support the source command
# needed for setting up Yocto build environments. Use bash as an alias for sh.
RUN which dash &> /dev/null && (\
    echo "dash dash/sh boolean false" | debconf-set-selections && \
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash) || \
    echo "Skipping dash reconfigure (not applicable)"

# Install the repo tool to handle git submodules (meta layers) comfortably.
ADD https://storage.googleapis.com/git-repo-downloads/repo /usr/local/bin/
RUN chmod 755 /usr/local/bin/repo

# Set the locale to en_US.UTF-8, because the Yocto build fails without any locale set.
# RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen en_US.UTF-8 && locale-gen && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
RUN locale-gen en_US.UTF-8 && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN DEBIAN_FRONTEND=noninteractive apt-get autoremove \
    && apt-get clean

RUN echo "bitbake core-image-minimal" >> /root/.bash_history

## users are not handled properly in podmans rootless containers in combination with mounted volumes.  Therefore we skip that currently

# Add user "embeddeduse" to sudoers. Then, the user can install Linux packages in the container.
# ENV USER_NAME embeddeduse
# RUN echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USER_NAME} && \
#     chmod 0440 /etc/sudoers.d/${USER_NAME}

# The running container writes all the build artefacts to a host directory (outside the container).
# The container can only write files to host directories, if it uses the same user ID and
# group ID owning the host directories. The host_uid and group_uid are passed to the docker build
# command with the --build-arg option. By default, they are both 1001. The docker image creates
# a group with host_gid and a user with host_uid and adds the user to the group. The symbolic
# name of the group and user is embeddeduse.
# ARG host_uid=1000
# ARG host_gid=1001
# RUN groupadd -g $host_gid $USER_NAME && useradd -g $host_gid -m -s /bin/bash -u $host_uid $USER_NAME

# Perform the Yocto build as user embeddeduse (not as root).
# By default, docker runs as root. However, Yocto builds should not be run as root, but as a 
# normal user. Hence, we switch to the newly created user embeddeduse.
# USER $USER_NAME

## end skipped

RUN echo -e "\nfile=poky/oe-init-build-env; test -f \$file && source \$file . ; unset file;\n" >> /etc/bash.bashrc
WORKDIR /work
ENTRYPOINT ["/bin/bash"]
