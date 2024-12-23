FROM rocker/tidyverse:4.3.0

WORKDIR /usr/iidda

RUN apt-get update && \ 
apt-get install -y make && \
apt-get install -y git && \
apt-get clean

# Copy files required for package R installation
COPY Makefile .
COPY .iidda .
COPY setup.mk .
COPY ignore.mk .
COPY R ./R
COPY global-metadata ./global-metadata

RUN make install

WORKDIR /usr/home/iidda

CMD ["bash"]
