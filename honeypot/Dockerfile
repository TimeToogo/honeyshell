# Dockerfile for building ssh honeypot running
FROM alpine

RUN apk add --no-cache socat openssh sudo inotify-tools \
    && rm -rf /var/cache/apk/*

# Install and configure sudosh (logging shell) as root user shell
RUN wget https://github.com/cloudposse/sudosh/releases/download/0.3.0/sudosh_linux_amd64 -O /usr/bin/sudosh
RUN ln -s /bin/sh /usr/bin/bash
RUN chmod +x /usr/bin/sudosh

RUN echo 'Defaults log_output' >> /etc/sudoers.d/sudosh
RUN echo 'Defaults!/usr/bin/sudoreplay !log_output' >> /etc/sudoers.d/sudosh
RUN echo 'Defaults!/sbin/reboot !log_output' >> /etc/sudoers.d/sudosh
RUN echo 'Defaults iolog_dir=/var/log/sudo-io' >> /etc/sudoers.d/sudosh
RUN echo 'Defaults iolog_file=session' >> /etc/sudoers.d/sudosh
RUN mkdir -p /var/log/sudo-io/session
RUN echo '/usr/bin/sudosh' >> /etc/shells

# Change root shell to sudosh
RUN sed -i 's/root:x:0:0:root:\/bin\/ash/root:x:0:0:root:\/usr\/bin\/sudosh/g' /etc/passwd

# Set empty root password
RUN sed -i 's/root\s*ALL=(ALL:ALL)\s*ALL/root ALL=(ALL:ALL) NOPASSWD:ALL/g' /etc/sudoers
RUN passwd -d root

# Configure sshd
COPY sshd/sshd_config /etc/ssh/sshd_config 
RUN mkdir -p /run/sshd

# Install boot/runtime scripts
COPY boot.sh /run/boot.sh
RUN chmod +x /run/boot.sh

COPY runtime.sh /run/runtime.sh
RUN chmod +x /run/runtime.sh

RUN ssh-keygen -A

WORKDIR /run/

ENTRYPOINT [ "/run/boot.sh" ]