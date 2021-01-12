# Dockerfile for building ssh honeypot running
FROM alpine

RUN apk add --no-cache socat bash openssh sudo inotify-tools \
    && rm -rf /var/cache/apk/*

# Install and configure sudosh (logging shell) as user shell
RUN wget https://github.com/cloudposse/sudosh/releases/download/0.3.0/sudosh_linux_amd64 -O /usr/bin/sudosh
RUN chmod +x /usr/bin/sudosh

RUN echo 'Defaults log_input' >> /etc/sudoers.d/sudosh
RUN echo 'Defaults log_output' >> /etc/sudoers.d/sudosh
RUN echo 'Defaults!/usr/bin/sudoreplay !log_output' >> /etc/sudoers.d/sudosh
RUN echo 'Defaults!/sbin/reboot !log_output' >> /etc/sudoers.d/sudosh
RUN echo 'Defaults iolog_dir=/var/log/sudo-io' >> /etc/sudoers.d/sudosh
RUN echo 'Defaults iolog_file=session' >> /etc/sudoers.d/sudosh
RUN mkdir -p /var/log/sudo-io/session
RUN echo '/usr/bin/sudosh' >> /etc/shells

# Create target users with empty passwords and sudosh shell
COPY add-insecure-user.sh /run/
RUN /run/add-insecure-user.sh ec2-user
RUN /run/add-insecure-user.sh mysql
RUN /run/add-insecure-user.sh postgres
RUN /run/add-insecure-user.sh user
RUN /run/add-insecure-user.sh admin
RUN /run/add-insecure-user.sh test
RUN /run/add-insecure-user.sh info
RUN /run/add-insecure-user.sh ubuntu
RUN /run/add-insecure-user.sh administrator
RUN rm -f /run/add-insecure-user.sh

# Configure sshd
COPY sshd/* /etc/ssh/
RUN chmod 600 /etc/ssh/ssh_host_dsa_key /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_rsa_key
RUN chmod 644 /etc/ssh/ssh_host_dsa_key.pub /etc/ssh/ssh_host_ecdsa_key.pub /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_rsa_key.pub
RUN mkdir -p /run/sshd

# Install boot/runtime scripts
COPY boot.sh /run/boot.sh
RUN chmod +x /run/boot.sh

COPY runtime.sh /run/runtime.sh
RUN chmod +x /run/runtime.sh

WORKDIR /run/

ENTRYPOINT [ "/run/boot.sh" ]