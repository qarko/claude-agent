FROM ubuntu:22.04 
RUN apt-get update -y 
RUN apt-get install -y curl tmux 
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 
RUN apt-get install -y nodejs 
RUN npm install -g @anthropic-ai/claude-code 
CMD ["sleep", "infinity"] 
