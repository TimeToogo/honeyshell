# Dockerfile for building ssh honeypot running in AWS Lambda
FROM ubuntu:20.04

RUN apt update && \
    apt install -y curl openssh-server sudo socat inotify-tools vim jq

# Install and configure sudosh (logging shell) as root user shell
RUN curl -L https://github.com/cloudposse/sudosh/releases/download/0.3.0/sudosh_linux_amd64 -o /usr/bin/sudosh
RUN chmod +x /usr/bin/sudosh

RUN echo 'Defaults log_output' >> /etc/sudoers.d/sudosh
RUN echo 'Defaults!/usr/bin/sudoreplay !log_output' >> /etc/sudoers.d/sudosh
RUN echo 'Defaults!/sbin/reboot !log_output' >> /etc/sudoers.d/sudosh
RUN echo 'Defaults iolog_dir=/var/log/sudo-io' >> /etc/sudoers.d/sudosh
RUN echo 'Defaults iolog_file=session' >> /etc/sudoers.d/sudosh
RUN mkdir -p /var/log/sudo-io/session
RUN echo '/usr/bin/sudosh' >> /etc/shells

RUN chsh -s /usr/bin/sudosh root

# Set empty root password
RUN sed -i 's/root\s*ALL=(ALL:ALL)\s*ALL/root ALL=(ALL:ALL) NOPASSWD:ALL/g' /etc/sudoers
RUN passwd -d root

# Configure sshd
COPY sshd/sshd_config /etc/ssh/sshd_config 
RUN mkdir -p /run/sshd

# Install lambda runtime emulator if built with --build-arg RUNTIME_EMULATOR=1
ARG RUNTIME_EMULATOR
COPY install-rie.sh /run/install-rie.sh
RUN /run/install-rie.sh
RUN rm -f /run/install-rie.sh

# Install boot/runtime scripts
COPY boot.sh /run/boot.sh
RUN chmod +x /run/boot.sh

COPY runtime.sh /run/runtime.sh
RUN chmod +x /run/runtime.sh

WORKDIR /run/

ENTRYPOINT [ "/run/boot.sh" ]