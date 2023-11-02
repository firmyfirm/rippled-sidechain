#runs development and sidechain branch for AMM testing
FROM	python:3.10
VOLUME	["/rippled-develop", "/rippled-sidechain", "/opt/local", "/var/lib/rippled/db"]
EXPOSE	51235
RUN apt -y update
RUN apt -y install gcc g++ wget git cmake pkg-config libprotoc-dev protobuf-compiler libprotobuf-dev libssl-dev
RUN pip install --upgrade pip
RUN pip install 'conan<2'
WORKDIR /
RUN wget https://boostorg.jfrog.io/artifactory/main/release/1.78.0/source/boost_1_78_0.tar.gz
RUN tar -xzf boost_1_78_0.tar.gz
WORKDIR /boost_1_78_0
RUN ./bootstrap.sh
RUN ./b2 headers
RUN ./b2 -j 8
WORKDIR /
RUN wget https://github.com/XRPLF/rippled/archive/refs/heads/sidechain.zip
RUN wget https://github.com/XRPLF/rippled/archive/refs/heads/develop.zip
RUN unzip develop.zip
RUN unzip sidechain.zip
RUN mkdir /rippled-sidechain/build
WORKDIR /rippled-sidechain/build
ENV BOOST_ROOT=/boost_1_78_0
RUN cmake -DCMAKE_BUILD_TYPE=Release ..
RUN cmake --build . -- -j 8
RUN pip install -r /rippled-sidechain/bin/sidechain/python/requirements.txt
ARG RIPPLED_MAINCHAIN_EXE=/usr/local/bin/rippled
ARG RIPPLED_SIDECHAIN_EXE=/rippled-sidechain/build
RUN mkdir config
ENV RIPPLED_SIDECHAIN_CFG_DIR=/sidechain-main/build/config
WORKDIR /rippled-develop
RUN mkdir build
WORKDIR /rippled-develop/build
RUN touch develop
RUN conan profile new develop --detect
RUN conan profile update settings.compiler.cppstd=20 develop
RUN conan install \
  --install-folder build/generators \
  --build missing \
  --settings build_type=Release \
  ..
RUN cmake \
  -DCMAKE_TOOLCHAIN_FILE=build/generators/conan_toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  ..
RUN cmake --build .
RUN make install
RUN cmake --install . --prefix /opt/local
WORKDIR /rippled-develop
CMD rippled --net --conf /opt/local/etc/rippled.cfg
