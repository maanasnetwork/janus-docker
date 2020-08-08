############################################################
# Build - Janus Gateway on Debian Buster
# https://github.com/minelytics/janus-gateway-docker
############################################################

export LC_ALL=en_US.UTF-8

sudo apt-get update -y && apt-get upgrade -y
sudo mkdir /build

# boringssl build
sudo apt-get -y update && apt-get install -y --no-install-recommends \
        g++ \
        gcc \
        libc6-dev \
        make \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*
export GOLANG_VERSION="1.7.5"
export GOLANG_DOWNLOAD_URL="https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz"
export GOLANG_DOWNLOAD_SHA256=2e4dd6c44f0693bef4e7b46cc701513d74c3cc44f2419bf519d7868b12931ac3
sudo curl -fsSL "$GOLANG_DOWNLOAD_URL" -o golang.tar.gz \
    && echo "$GOLANG_DOWNLOAD_SHA256  golang.tar.gz" | sha256sum -c - \
    && tar -C /usr/local -xzf golang.tar.gz \
    && rm golang.tar.gz
export GOPATH="/go"
export PATH="$GOPATH/bin:/usr/local/go/bin:$PATH"
sudo mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

# boringssl
cd /build
sudo apt-get  update && \
    apt-get install -y cmake libunwind-dev golang
sudo git clone https://boringssl.googlesource.com/boringssl
cd /build/boringssl
sudo git reset --hard c7db3232c397aa3feb1d474d63a1c4dd674b6349 
sudo sed -i s/" -Werror"//g CMakeLists.txt
sudo mkdir -p build
cd /build/boringssl/build
sudo cmake -DCMAKE_CXX_FLAGS="-lrt" ..
sudo make
cd /build/boringssl
sudo mkdir -p /opt/boringssl/lib
sudo cp -R include /opt/boringssl/  && \
	cp build/ssl/libssl.a /opt/boringssl/lib/  && \
	cp build/crypto/libcrypto.a /opt/boringssl/lib/

# websocket
export WEBSOCKET_VERSION="4.0.1"
sudo apt-get install libssl-dev
cd /build
sudo wget https://github.com/warmcat/libwebsockets/archive/v$WEBSOCKET_VERSION.tar.gz
sudo tar xfvz v$WEBSOCKET_VERSION.tar.gz
cd /build/libwebsockets-$WEBSOCKET_VERSION
sudo mkdir build
cd /build/libwebsockets-$WEBSOCKET_VERSION/build
# See https://github.com/meetecho/janus-gateway/issues/732 re: LWS_MAX_SMP
sudo cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_C_FLAGS="-fpic" -DLWS_MAX_SMP=1 -DLWS_IPV6="ON" ..
sudo make && make install

# libsrtp
export LIBSRTP_VERSION="2.2.0"
cd /build
sudo apt-get remove -y libsrtp0-dev 
sudo wget https://github.com/cisco/libsrtp/archive/v$LIBSRTP_VERSION.tar.gz 
sudo tar xfvz v$LIBSRTP_VERSION.tar.gz
cd /build/libsrtp-$LIBSRTP_VERSION
sudo ./configure --prefix=/usr --enable-openssl
sudo make shared_library && make install


# libnice
export LIBNICE_VERSION="0.1.16"
cd /build
sudo apt-get remove -y libnice-dev libnice10
sudo apt-get  update && \
    apt-get install -y gtk-doc-tools libgnutls28-dev
# sudo wget https://gitlab.freedesktop.org/libnice/libnice/-/archive/$LIBNICE_VERSION/libnice-$LIBNICE_VERSION.tar.gz
# sudo tar xfvz libnice-$LIBNICE_VERSION.tar.gz
# cd /build/libnice-$LIBNICE_VERSION
sudo git clone https://gitlab.freedesktop.org/libnice/libnice.git
cd /build/libnice
sudo git checkout 67807a17ce983a860804d7732aaf7d2fb56150ba
sudo ./autogen.sh
sudo ./configure --prefix=/usr
sudo make && make install

# coturn
export COTRUN_VERSION="4.5.0.8"
sudo apt-get install libevent-dev coturn
# cd /build
# sudo wget https://github.com/coturn/coturn/archive/$COTRUN_VERSION.tar.gz
# sudo tar xzvf $COTRUN_VERSION.tar.gz
# cd /build/coturn-$COTRUN_VERSION
# sudo ./configure
# sudo make && make install

# # data channel
export USRSCTP_VERSION="0.9.3.0"
cd /build
# sudo wget https://github.com/sctplab/usrsctp/archive/$USRSCTP_VERSION.tar.gz
# sudo tar xzvf $USRSCTP_VERSION.tar.gz
# cd /build/usrsctp-$USRSCTP_VERSION
sudo git clone https://github.com/sctplab/usrsctp.git
cd /build/usrsctp
sudo git checkout origin/master && git reset --hard 1c9c82fbe3582ed7c474ba4326e5929d12584005 
sudo ./bootstrap
sudo ./configure --prefix=/usr 
sudo make && make install


# janus dependencies
sudo apt-get update -y && apt-get install -y libmicrohttpd-dev \
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
cd /build
sudo wget https://github.com/meetecho/janus-gateway/archive/v0.9.2.tar.gz
sudo tar xzvf v0.9.2.tar.gz
cd janus-gateway-0.9.2
sudo sh autogen.sh
sudo ./configure --prefix=/opt/janus \
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

cd /opt/media
cp ./compose/janus/janus.jcfg /opt/janus/etc/janus/janus.jcfg
cp ./compose/janus/janus.transport.http.jcfg /opt/janus/etc/janus/janus.transport.http.jcfg
