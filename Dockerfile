## @author     Dmitry Kolesnikov, <dmkolesnikov@gmail.com>
## @copyright  (c) 2016 Dmitry Kolesnikov. All Rights Reserved
##
## @doc
##   reference docker file for Erlang applications
FROM centos

ENV   ARCH  x86_64
ENV   PLAT  Linux
ARG   APP=hercule
ARG   VSN=

##
## install dependencies
RUN \
   yum -y install \
      tar  \
      git  \
      make \
      unzip

##
## install application
COPY ${APP}-${VSN}+${ARCH}.${PLAT}.bundle /tmp/${APP}.bundle

RUN \
   sh /tmp/${APP}.bundle && \
   rm /tmp/${APP}.bundle 

ENV PATH $PATH:/usr/local/${APP}/bin/

EXPOSE 8080
EXPOSE 4369
EXPOSE 32100

ENTRYPOINT /etc/init.d/${APP} foreground
