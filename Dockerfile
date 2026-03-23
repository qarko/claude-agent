FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl sudo tmux openssh-server git \
    && mkdir /var/run/sshd

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

RUN useradd -m -s /bin/bash claude && \
    echo 'claude:claude123' | chpasswd && \
    echo 'claude ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN echo 'root:railway' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
