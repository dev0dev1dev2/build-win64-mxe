FROM docker.io/library/buildpack-deps:bullseye

RUN echo 'deb [trusted=yes] https://developer.download.nvidia.com/hpc-sdk/ubuntu/amd64 /' | tee /etc/apt/sources.list.d/nvhpc.list

RUN apt-get update \
  && apt-get install -y \
    # http://mxe.cc/#requirements-debian
    autopoint bison flex gettext gperf g++-multilib \
    intltool libc6-dev-i386 libtool-bin libxml-parser-perl \
    lzip p7zip-full python-is-python3 python3-mako ruby
    # lzip p7zip-full python-is-python3 python3-mako ruby \
    # nvidia-driver firmware-nonfree linux-headers-$(uname -r) dkms

RUN apt-get install -y nvhpc-23-11
RUN apt-get install -y environment-modules

# RUN cat  /etc/environment-modules/modulespath
RUN sed -i -e '$a/opt/nvidia/hpc_sdk/modulefiles' /etc/environment-modules/modulespath
# # ENV PATH /usr/lib/wsl/lib:$PATH
# # ENV LD_LIBRARY_PATH /usr/lib/wsl/lib:$LD_LIBRARY_PATH
# RUN . /etc/profile.d/modules.sh \
#   && module avail \
#   && module load nvhpc/23.5 \
#   && nvc --version 
#   # && nvaccelinfo -v \
#   # && nvidia-smi
# sudo sed -i -e '$a/opt/nvidia/hpc_sdk/modulefiles' /etc/environment-modules/modulespath

# The build dir is mounted at /data, so this runs the build script in that
ENTRYPOINT ["/bin/bash", "/data/build.sh"]

# The build dir is mounted here
WORKDIR /data
