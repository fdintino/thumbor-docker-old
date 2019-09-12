FROM python:2

LABEL maintainer="MinimalCompact"

VOLUME /data

# base OS packages
RUN  \
    awk '$1 ~ "^deb" { $3 = $3 "-backports"; print; exit }' /etc/apt/sources.list > /etc/apt/sources.list.d/backports.list \
    && apt-get update \
    && apt-get -y upgrade \
    && apt-get -y autoremove \
    && apt-get install -y -q \
        python-numpy \
        python-opencv \
        git \
        curl \
        libdc1394-22 \
        libjpeg-turbo-progs \
        graphicsmagick \
        libgraphicsmagick++3 \
        libgraphicsmagick++1-dev \
        libgraphicsmagick-q16-3 \
        zlib1g-dev \
        libboost-python-dev \
        libmemcached-dev \
        gifsicle \
        ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y -q \
        build-essential cmake \
    && mkdir /build \
    && cd /build \
    && wget https://github.com/uclouvain/openjpeg/archive/version.2.0.1.tar.gz \
    && tar xf version.2.0.1.tar.gz \
    && cd openjpeg-version.2.0.1 \
    && cmake . \
    && make install \
    && ldconfig /usr/lib \
    && cd / \
    && rm -rf /build \
    && apt-get remove --purge -y build-essential cmake \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y -q \
        build-essential nasm \
    && mkdir /build \
    && cd /build \
    && wget https://github.com/mozilla/mozjpeg/archive/v3.1.tar.gz \
    && tar xf v3.1.tar.gz \
    && cd mozjpeg-3.1 \
    && autoreconf -fiv \
    && mkdir build \
    && cd build \
    && CXXFLAGS="-fPIC" CFLAGS="-fPIC" sh ../configure --disable-shared --enable-static --prefix=/usr/local \
    && make install \
    && ldconfig /usr/lib \
    && cd / \
    && rm -rf /build \
    && apt-get remove --purge -y build-essential nasm \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y -q \
        build-essential nasm \
    && mkdir /build \
    && cd /build \
    && wget https://github.com/pornel/pngquant/archive/2.5.0.tar.gz \
    && tar xf 2.5.0.tar.gz \
    && cd pngquant-2.5.0 \
    && make install \
    && ldconfig /usr/lib \
    && cd / \
    && rm -rf /build \
    && apt-get remove --purge -y build-essential nasm \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y -q \
        pngnq pngcrush optipng \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV HOME /app
ENV SHELL bash
ENV WORKON_HOME /app
WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --trusted-host None --no-cache-dir \
   -r /app/requirements.txt

COPY conf/thumbor.conf.tpl /app/thumbor.conf.tpl

ADD conf/circus.ini.tpl /etc/
RUN mkdir  /etc/circus.d /etc/setup.d
ADD conf/thumbor-circus.ini.tpl /etc/circus.d/

RUN \
    ln /usr/lib/python2.7/dist-packages/cv2.x86_64-linux-gnu.so /usr/local/lib/python2.7/cv2.so && \
    ln /usr/lib/python2.7/dist-packages/cv.py /usr/local/lib/python2.7/cv.py

ARG SIMD_LEVEL
# workaround for https://github.com/python-pillow/Pillow/issues/3441
# https://github.com/thumbor/thumbor/issues/1102
RUN if [ -z "$SIMD_LEVEL" ]; then \
    # Use newer pillow
    PILLOW_VERSION=5.2.0 && \
    pip uninstall -y pillow || true && \
    # https://github.com/python-pillow/Pillow/pull/3241
    LIB=/usr/lib/x86_64-linux-gnu/ \
    # https://github.com/python-pillow/Pillow/pull/3237 or https://github.com/python-pillow/Pillow/pull/3245
    INCLUDE=/usr/include/x86_64-linux-gnu/ \
    pip install --no-cache-dir -U --force-reinstall --no-binary=:all: "pillow<=$PILLOW_VERSION" \
    # --global-option="build_ext" --global-option="--debug" \
    --global-option="build_ext" --global-option="--enable-lcms" \
    --global-option="build_ext" --global-option="--enable-zlib" \
    --global-option="build_ext" --global-option="--enable-jpeg" \
    --global-option="build_ext" --global-option="--enable-tiff" \
    --global-option="build_ext" --global-option="--enable-jpeg2000" \
    --global-option="build_ext" --global-option="--enable-webp" \
    ; fi
RUN if [ -n "$SIMD_LEVEL" ]; then apt-get install -y -q libjpeg-dev zlib1g-dev; fi
RUN if [ -n "$SIMD_LEVEL" ]; then pip uninstall -y pillow; CC="cc -m$SIMD_LEVEL" LDFLAGS=-L/usr/lib/x86_64-linux-gnu/ pip install --no-cache-dir -U --force-reinstall Pillow-SIMD==5.3.0.post0; fi

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

# running thumbor multiprocess via circus by default
# to override and run thumbor solo, set THUMBOR_NUM_PROCESSES=1 or unset it
CMD ["circus"]

EXPOSE 80 8888
