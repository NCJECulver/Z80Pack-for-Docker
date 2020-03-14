#=========================
#   Z80Pack for Docker
#=========================

# Build a Z80Pack docker image. The resulting image will
# include only cpmsim, not the Altair or Cromemco simulators.

# To build:
#
#   docker build -f Dockerfile.z80pack.136 .

# =============================================================
# 2020-03-14 Added code to link /bin/sh to /bin/bash.
# 
# 2020-03-13 Update launch script update code
#            Now using ZPackScripts, so remove zpack_os, install
#--------------------------------------------------------------

# Specify here the version of Z80Pack you would like to install.
# Options range from 1.8 to 1.36 (though this build has only be
# tested with versions >1.20). The default setting here may be
# overridden at build time with the cmdline param 
#   --build-arg ZPackVer=1.35

# Note, so far I haven't gotten this to work. 

ARG     ZPackVer=1.36

# This is a multi-stage build, which will leave intermediate
# build images. To clean them once the Z80Pack image build is
# complete, run:
#
#   docker rmi $(docker images -q -f dangling=true)

# Once built, run this image as follows:
#   docker run -it \
#              -v /pathto/host/z80pack/cpmsim/library:/root/z80pack/cpmsim/library \
#              -p 4000:4000 -p 4001:4001 -p 4002:4002 -p 4003:4003 \
#     z80pack.136 ./cpm2
#
# To do:
#   - Set up an external public directory.


# ---------------------------
# Stage 1 - BUILD ENVIRONMENT
# ---------------------------

# Creating a base image with the necessary development packages
# and other needed tools.

# Start with a clean base...

FROM    alpine AS z80pack-base

# ...set some variables...

ENV     Z80PACK_VERS="1.36" \
        CPMTOOLS_VERS="2.20"

# ...and install the build tools

RUN     apk --no-cache update                                                       && \
        apk upgrade                                                                 && \
        apk --no-cache add bash joe sudo git wget dpkg-dev                          && \
        apk --no-cache add g++ gcc make libc-dev mesa-dev                           && \
        apk --no-cache add libjpeg-turbo-dev libxmu-dev                             && \
        apk --no-cache add libx11-dev glu-dev socat tmux


# ---------------------------
# Stage 2 - ZPACK, CPMTOOLS
# ---------------------------

FROM z80pack-base AS z80pack-installed

# z80pack
# -------

# Fetch and unpack
RUN     cd /root/                                                                   && \
        if [ ! -d /root/bin ]; then mkdir /root/bin;fi && PATH="$PATH:/root/bin"    && \
        cd ~                                                                        && \
        wget http://www.autometer.de/unix4fun/z80pack/ftp/z80pack-$Z80PACK_VERS.tgz && \
        tar xzvf z80pack-$Z80PACK_VERS.tgz                                          && \
        mv z80pack-$Z80PACK_VERS z80pack                                            && \
        rm z80pack-$Z80PACK_VERS.tgz

# Build
RUN     cd /root/z80pack/cpmsim/srcsim/                                             && \
        make -f Makefile.linux                                                      && \
        make -f Makefile.linux clean                                                && \
        cd /root/z80pack/cpmsim/srctools/                                           && \
        make                                                                        && \
        make install                                                                && \
        make clean

# Backup
RUN     cd /root/z80pack/cpmsim/disks/library/                                      && \
        if [ ! -d ../backups ]; then mkdir -p ../backups; fi                        && \
        cp -p * ../backups

RUN     cd /root/                                                                   && \
        git clone https://github.com/NCJECulver/ZPackScripts.git                    && \
        cp ZPackScripts/* z80pack/                                                  && \
        cd z80pack/                                                                 && \
        sed -i 's|docker\=no|docker\=yes|' zpack_install                            && \
        cd ..                                                                       &&\
        rm -r ZPackScripts/

#COPY    zpack_os /root/z80pack/cpmsim
#COPY    install /root/z80pack/cpmsim

# cpmtools
# --------
RUN     cd /root/                                                                   && \
        if [ ! -d cpmtools ]; then mkdir cpmtools; fi                               && \
        cd /root/cpmtools                                                           && \
        wget http://www.moria.de/~michael/cpmtools/files/cpmtools-2.20.tar.gz       && \
        tar xzvf cpmtools-2.20.tar.gz  
        
RUN     cd /root/cpmtools/cpmtools-2.20                                             && \
       ./configure                                                                  && \
        make                                                                        && \
        make install                                                                && \
        make clean         

# clean up
# ----- --
RUN     cd /root/                                                                   && \
        rm -r cpmtools                                                              && \
        cd /root/z80pack/                                                           && \
        rm -r altairsim                                                             && \
        rm -r cromemcosim                                                           && \
        rm -r frontpanel                                                            && \
        rm -r imsaisim                                                              && \
        rm -r doc                                                                   && \
        rm -r z80*                                                                  && \
        rm -r iodevices                                                             && \
        rm -r README                                                                && \
        cd cpmsim                                                                   && \
        rm -r src*

# update scripts
# ------ -------
#WORKDIR /root/z80pack/cpmsim
#RUN     for scr in cpm13 cpm14 cpm1975 cpm2 cpm3 cpm3-8080 fuzix mpm;                  \
#        do                                                                             \
#          echo "Updating script: $scr"                                                ;\
#          sed -i 's|bin/sh|bin/bash|g' $scr                                           ;\
#          sed -i 's|\.cpm|\.dsk|g' $scr                                               ;\
#          sed -i 's|\./format|mkdskimg|g' $scr                                        ;\
#          simcmd=$(grep ./ $scr)                                                      ;\
#          sed -i 's|./|#./|' $1                                                       ;\
#          echo "" >> $scr                                                             ;\
#          echo "#---- ZPack_OS mods" >> $scr                                          ;\
#          echo "simcmd='$simcmd'" >> $scr                                             ;\
#          echo "[ -f ../zpack_os ] && . ../zpack_os" >> $scr                          ;\
#          echo "\$simcmd" >> $scr                                                     ;\
#        done
WORKDIR /root/z80pack/cpmsim
RUN     for scr in cpm13 cpm14 cpm1975 cpm2 cpm3 cpm3-8080 fuzix mpm;                  \
        do                                                                             \
          echo "Updating script: $scr"                                                ;\
          sed -i 's|bin/sh|bin/bash|g' $scr                                           ;\
          sed -i 's|\.cpm|\.dsk|g' $scr                                               ;\
          sed -i 's|\./format|mkdskimg|g' $scr                                        ;\
          simcmd=$(grep ^./ $scr)                                                     ;\
          sed -i 's|^./|\#./|' $scr                                                   ;\
          echo "" >> $scr                                                             ;\
          echo "#---- ZPack_OS mods" >> $scr                                          ;\
          echo "simcmd='$simcmd'" >> $scr                                             ;\
          echo "[ -f ../zpack_os ] && . ../zpack_os" >> $scr                          ;\
          echo "\$simcmd" >> $scr                                                     ;\
        done
# ----------------------------
# Stage 3 - FRESH IMAGE
# ----------------------------

# Everything's done. Now copy the results into a clean
# base image. Result: reduction from 628mb to 50mb.

# Start with a clean base

FROM    alpine AS z80pack.136

# Add wget (for installing additional components), TMUX, BASH

RUN     apk --no-cache add wget tmux bash && mv /bin/sh /bin/sh.old && ln -s /bin/bash /bin/sh

# Set IP ports for MP/M networking

EXPOSE  4000-4031

ENV     PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/bin:/root/z80pack/cpmsim
RUN     sed -i 's/\/bin\/ash/\/bin\/bash/g' /etc/passwd && \
        sed -i 's/\/sbin\:\/bin/\/sbin\:\/bin\:\/root\/bin\:\/root\/z80pack\/cpmsim/g' /etc/profile

# Copy over only the binaries

COPY    --from=z80pack-installed /root/                    /root/
COPY    --from=z80pack-installed /usr/local/bin/cpm*       /root/bin/
COPY    --from=z80pack-installed /usr/local/bin/*.cpm      /root/bin/
COPY    --from=z80pack-installed /usr/local/share/diskdefs /usr/local/share/
COPY    --from=z80pack-installed /tmp/.z80pack/            /tmp/.z80pack/

# Alpine base doesn't have man, so skip man pages

#  COPY --from=z80pack-installed /usr/local/share/man/man1/cpm*.1  /usr/local/share/man/man1/
#  COPY --from=z80pack-installed /usr/local/share/man/man1/*.cpm.1 /usr/local/share/man/man1/
#  COPY --from=z80pack-installed /usr/local/share/man/man5/cpm.5   /usr/local/share/man/man5/

WORKDIR /root/z80pack/cpmsim
