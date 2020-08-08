############################################################
# Dockerfile - Janus Gateway on Debian Buster
############################################################

FROM buildpack-deps:buster
MAINTAINER Maanas Royy <m4manas@gmail.com>
RUN apt-get update -y && apt-get upgrade -y
RUN mkdir /build

# boringssl build
RUN apt-get -y update && apt-get install -y --no-install-recommends \
        g++ \
        gcc \
        libc6-dev \
        make \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*
ENV GOLANG_VERSION 1.7.5
ENV GOLANG_DOWNLOAD_URL https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz
ENV GOLANG_DOWNLOAD_SHA256 2e4dd6c44f0693bef4e7b46cc701513d74c3cc44f2419bf519d7868b12931ac3
RUN curl -fsSL "$GOLANG_DOWNLOAD_URL" -o golang.tar.gz \
    && echo "$GOLANG_DOWNLOAD_SHA256  golang.tar.gz" | sha256sum -c - \
    && tar -C /usr/local -xzf golang.tar.gz \
    && rm golang.tar.gz
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

# boringssl
WORKDIR /build
RUN apt-get  update && \
    apt-get install -y cmake libunwind-dev golang
RUN git clone https://boringssl.googlesource.com/boringssl
WORKDIR /build/boringssl
RUN git reset --hard c7db3232c397aa3feb1d474d63a1c4dd674b6349 
RUN sed -i s/" -Werror"//g CMakeLists.txt
RUN mkdir -p build
WORKDIR /build/boringssl/build
RUN cmake -DCMAKE_CXX_FLAGS="-lrt" ..
RUN make
WORKDIR /build/boringssl
RUN mkdir -p /opt/boringssl/lib
RUN cp -R include /opt/boringssl/  && \
	cp build/ssl/libssl.a /opt/boringssl/lib/  && \
	cp build/crypto/libcrypto.a /opt/boringssl/lib/

# websocket
ENV WEBSOCKET_VERSION 4.0.1
RUN apt-get install libssl-dev
WORKDIR /build
RUN wget https://github.com/warmcat/libwebsockets/archive/v$WEBSOCKET_VERSION.tar.gz
RUN tar xfvz v$WEBSOCKET_VERSION.tar.gz
WORKDIR /build/libwebsockets-$WEBSOCKET_VERSION
RUN mkdir build
WORKDIR /build/libwebsockets-$WEBSOCKET_VERSION/build
# See https://github.com/meetecho/janus-gateway/issues/732 re: LWS_MAX_SMP
RUN cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_C_FLAGS="-fpic" -DLWS_MAX_SMP=1 -DLWS_IPV6="ON" ..
RUN make && make install

# libsrtp
ENV LIBSRTP_VERSION 2.2.0
WORKDIR /build
RUN apt-get remove -y libsrtp0-dev 
RUN wget https://github.com/cisco/libsrtp/archive/v$LIBSRTP_VERSION.tar.gz 
RUN tar xfvz v$LIBSRTP_VERSION.tar.gz
WORKDIR /build/libsrtp-$LIBSRTP_VERSION
RUN ./configure --prefix=/usr --enable-openssl
RUN make shared_library && make install


# libnice
ENV LIBNICE_VERSION 0.1.16
WORKDIR /build
RUN apt-get remove -y libnice-dev libnice10
RUN apt-get  update && \
    apt-get install -y gtk-doc-tools libgnutls28-dev
# RUN wget https://gitlab.freedesktop.org/libnice/libnice/-/archive/$LIBNICE_VERSION/libnice-$LIBNICE_VERSION.tar.gz
# RUN tar xfvz libnice-$LIBNICE_VERSION.tar.gz
# WORKDIR /build/libnice-$LIBNICE_VERSION
RUN git clone https://gitlab.freedesktop.org/libnice/libnice.git
WORKDIR /build/libnice
RUN git checkout 67807a17ce983a860804d7732aaf7d2fb56150ba
RUN ./autogen.sh
RUN ./configure --prefix=/usr
RUN make && make install

# coturn
ENV COTRUN_VERSION 4.5.0.8
RUN apt-get install -y libevent-dev coturn
# WORKDIR /build
# RUN wget https://github.com/coturn/coturn/archive/$COTRUN_VERSION.tar.gz
# RUN tar xzvf $COTRUN_VERSION.tar.gz
# WORKDIR /build/coturn-$COTRUN_VERSION
# RUN ./configure
# RUN make && make install

# # data channel
ENV USRSCTP_VERSION 0.9.3.0
WORKDIR /build
# RUN wget https://github.com/sctplab/usrsctp/archive/$USRSCTP_VERSION.tar.gz
# RUN tar xzvf $USRSCTP_VERSION.tar.gz
# WORKDIR /build/usrsctp-$USRSCTP_VERSION
RUN git clone https://github.com/sctplab/usrsctp.git
WORKDIR /build/usrsctp
RUN git checkout origin/master && git reset --hard 1c9c82fbe3582ed7c474ba4326e5929d12584005 
RUN ./bootstrap
RUN ./configure --prefix=/usr 
RUN make && make install


# janus dependencies
RUN apt-get update -y && apt-get install -y libmicrohttpd-dev \
	libjansson-dev \
    libsofia-sip-ua-dev \
    libglib2.0-dev \
    libopus-dev \
    libogg-dev \
    libcurl4-openssl-dev \
    liblua5.3-dev \
    libini-config-dev \
    libcollection-dev \
    libconfig-dev \
    libavformat-dev \
    libavcodec-dev \
    libavutil-dev \
    pkg-config\
    gengetopt \
    libtool \
    automake \
    cmake \
    ca-certificates

# janus
WORKDIR /build
RUN wget https://github.com/meetecho/janus-gateway/archive/v0.9.2.tar.gz
RUN tar xzvf v0.9.2.tar.gz
WORKDIR janus-gateway-0.9.2
RUN sh autogen.sh
RUN ./configure --prefix=/opt/janus \
	--enable-post-processing \
    --enable-boringssl \
    --enable-data-channels \
    --disable-rabbitmq \
    --disable-mqtt \
    --disable-unix-sockets \
    --enable-dtls-settimeout \
    --enable-plugin-echotest \
    --enable-plugin-recordplay \
    --enable-plugin-sip \
    --enable-plugin-videocall \
    --enable-plugin-voicemail \
    --enable-plugin-textroom \
    --enable-plugin-audiobridge \
    --enable-plugin-nosip \
    --enable-all-handlers && \
    make && make install && make configs && ldconfig

COPY ./compose/janus/janus.jcfg /opt/janus/etc/janus/janus.jcfg
COPY ./compose/janus/janus.transport.http.jcfg /opt/janus/etc/janus/janus.transport.http.jcfg

WORKDIR /opt/janus
ENTRYPOINT ["/opt/janus/bin/janus"]
