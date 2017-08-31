## @author     Dmitry Kolesnikov, <dmkolesnikov@gmail.com>
## @copyright  (c) 2016 Dmitry Kolesnikov. All Rights Reserved
##
## @doc
##   reference docker file for Erlang applications
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
