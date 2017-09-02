##
## Copyright (C) 2012 Dmitry Kolesnikov
##
## This Dockerfile may be modified and distributed under the terms
## of the MIT license.  See the LICENSE file for details.
## https://github.com/fogfish/makefile
##
## @doc
##   This dockerfile is a reference container for Erlang releases
##
## @version 1.0.0
FROM centos

##
## install dependencies
RUN set -e \
   && yum -y update  \
   && yum -y install \
      tar  \
      unzip

ENV   ARCH  x86_64
ENV   PLAT  Linux
ARG   APP=
ARG   VSN=

##
## install application
COPY ${APP}-${VSN}+${ARCH}.${PLAT}.bundle /tmp/${APP}.bundle
RUN set -e \
   && sh /tmp/${APP}.bundle \
   && rm /tmp/${APP}.bundle 

ENV PATH $PATH:/usr/local/${APP}/bin/


ENTRYPOINT /etc/init.d/application foreground
