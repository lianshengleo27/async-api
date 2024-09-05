FROM --platform=linux/x86_64 public.ecr.aws/ubuntu/ubuntu:22.04_stable

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update                                          &&\
    apt-get install -y curl unzip jq                        &&\
    apt-get install -y git-core vim binutils                &&\
    apt-get install -y cmake g++ gcc                        &&\
    apt-get install -y libgdal-dev libfreenect-dev          \
                        libeigen3-dev libtbb-dev            \
                        libavcodec-dev libavformat-dev      \
                        libavutil-dev libboost-thread-dev   \
                        libboost-program-options-dev        \
                        libcgal-dev libcgal-qt5-dev         \
                        libdlib-dev libswscale-dev          \
                        libtbb-dev libqt5opengl5-dev        \
                        qtbase5-dev qt5-qmake               \
                        qttools5-dev qtwebengine5-dev       \
                        qttools5-dev-tools libqt5svg5-dev   \
                        libproj-dev libdlib-dev             \
                        libqt5websockets5-dev xvfb          &&\
    apt-get clean

WORKDIR /tmp

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" &&\
    unzip awscliv2.zip && ./aws/install && rm ./awscliv2.zip

ENV DISPLAY=:1

RUN nohup Xvfb -ac ${DISPLAY} -screen 0 1280x780x24 &

RUN git clone --branch version_2.12.4 --single-branch --recursive https://github.com/cloudcompare/CloudCompare.git

COPY build /tmp/CloudCompare/build

RUN chmod 755 /tmp/CloudCompare/build/configure.sh

RUN cd /tmp/CloudCompare/build &&\
    ./configure.sh          &&\
    make                    &&\
    make install            &&\
    make clean

ENV QT_QPA_PLATFORM=offscreen

COPY entrypoint_curl_location.sh ./script/entrypoint.sh

RUN chmod 755 ./script/entrypoint.sh

ENTRYPOINT /tmp/script/entrypoint.sh