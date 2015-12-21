## @author     Dmitry Kolesnikov, <dmkolesnikov@gmail.com>
## @copyright  (c) 2012 - 2014 Dmitry Kolesnikov. All Rights Reserved
##
## @description
##   Makefile to build and release Erlang applications using
##   rebar, reltool, etc (see README for details)
##
##   application version schema (based on semantic version)
##   ${APP}-${VSN}+${HEAD}.${ARCH}.${PLAT}
##
## @version 0.9.0

#####################################################################
##
## application config
##
#####################################################################
PREFIX ?= /usr/local
APP ?= $(notdir $(CURDIR))
ARCH?= $(shell uname -m)
PLAT?= $(shell uname -s)
HEAD = $(shell test -z "`git status --porcelain`" && git rev-parse --short HEAD || echo 'SNAPSHOT')
GTAG = $(shell git describe --abbrev=0 --tags)
VSN ?= ${GTAG}-${HEAD}
REL  = ${APP}-${VSN}
PKG  = ${REL}+${ARCH}.${PLAT}
TEST?= ${APP}
S3  ?=
VMI ?= sys/erlang:latest
NET ?= lo0

## root path to benchmark framework
BB     = ../basho_bench
SSHENV = /tmp/ssh-agent.conf
COOKIE?= nocookie

## erlang flags (make run only)
ROOT   = `pwd`
ADDR   = $(shell ifconfig ${NET} | sed -En 's/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
EFLAGS = \
	-name ${APP}@${ADDR} \
	-setcookie ${COOKIE} \
	-pa ${ROOT}/ebin \
	-pa ${ROOT}/deps/*/ebin \
	-pa ${ROOT}/apps/*/ebin \
	-pa ${ROOT}/rel/files \
	-pa ${ROOT}/priv \
	-kernel inet_dist_listen_min 32100 \
	-kernel inet_dist_listen_max 32199 \
	+P 1000000 \
	+K true +A 160 -sbt ts

## self-extracting bundle wrapper
BUNDLE_INIT = PREFIX=${PREFIX}\nREL=${PREFIX}/${REL}\nAPP=${APP}\nVSN=${VSN}\nLINE=\`grep -a -n 'BUNDLE:\x24' \x240\`\ntail -n +\x24(( \x24{LINE\x25\x25:*} + 1)) \x240 | gzip -vdc - | tar -C ${PREFIX} -xvf - > /dev/null\n
BUNDLE_FREE = exit\nBUNDLE:\n
BUILDER = FROM ${VMI}\nRUN mkdir ${APP}\nCOPY . ${APP}/\nRUN cd ${APP} && make && make rel\n

#####################################################################
##
## build
##
#####################################################################
all: rebar deps compile

compile:
	@./rebar compile

deps:
	@./rebar get-deps

clean:
	@./rebar clean ; \
	rm -rf test.*-temp-data ; \
	rm -rf tests ; \
	rm -rf log ; \
	rm -f  *.tgz ; \
	rm -f  *.bundle

distclean: clean 
	@./rebar delete-deps

unit: all
	@./rebar skip_deps=true eunit

test:
	@erl ${EFLAGS} -run deb test test/${TEST}.config

docs:
	@./rebar skip_deps=true doc

#####################################################################
##
## release 
##
#####################################################################
rel: ${PKG}.tgz

## assemble VM release
ifeq (${PLAT},$(shell uname -s))
${PKG}.tgz:
	@./rebar generate target_dir=${REL} ;\
	test -d rel/${REL} && tar -C rel -zcf $@ ${REL} ;\
	test -f $@ && echo "==> tarball: $@"
else
${PKG}.tgz: Dockermake
	@docker build --file=$< --force-rm=true	--tag=build/${APP}:latest . ;\
	I=`docker create build/${APP}:latest` ;\
	docker cp $$I:/${APP}/$@ $@ ;\
	docker rm -f $$I ;\
	docker rmi build/${APP}:latest ;\
	rm $< ;\
	test -f $@ && echo "==> tarball: $@"

Dockermake:
	@echo "${BUILDER}" > $@
endif


#####################################################################
##
## package / bundle
##
#####################################################################
pkg: ${PKG}.tgz ${PKG}.bundle

${PKG}.bundle: rel/deploy.sh
	@printf "${BUNDLE_INIT}" > $@ ;\
	cat $<  >> $@ ;\
	printf  "${BUNDLE_FREE}" >> $@ ;\
	cat  ${PKG}.tgz >> $@ ;\
	chmod ugo+x $@ ;\
	rm -f ${APP}-latest+${ARCH}.${PLAT}.bundle ;\
	ln -s ${PKG} ${APP}-latest+${ARCH}.${PLAT}.bundle ;\
	echo "==> bundle: $@"

## copy 'package' to s3
s3: ${PKG}.bundle
	aws s3 cp $< ${S3}/$<

s3-latest: ${PKG}.bundle
	aws s3 cp $< ${S3}/${APP}-latest${VARIANT}.bundle

#####################################################################
##
## deploy
##
#####################################################################
ifneq (${host},)
${SSHENV}:
	@echo "==> ssh: config keys" ;\
	ssh-agent -s > ${SSHENV}

node: ${PKG}.bundle ${SSHENV}
	@echo "==> deploy: ${host}" ;\
	. ${SSHENV} ;\
	k=`basename ${pass}` ;\
	l=`ssh-add -l | grep $$k` ;\
	if [ -z "$$l" ] ; then \
		ssh-add ${pass} ;\
	fi ;\
	rsync -cav --rsh=ssh --progress $< ${host}:$< ;\
	ssh -t ${host} "sudo sh ./$<"
endif

#####################################################################
##
## debug
##
#####################################################################
run:
	@erl ${EFLAGS}

benchmark:
	@echo "==> benchmark: ${TEST}" ;\
	$(BB)/basho_bench -N bb@127.0.0.1 -C nocookie priv/${TEST}.benchmark ;\
	$(BB)/priv/summary.r -i tests/current ;\
	open tests/current/summary.png

start: ${PKG}.tgz
	@./rel/${REL}/bin/${APP} start

stop: ${PKG}.tgz
	@./rel/${REL}/bin/${APP} stop

console: ${PKG}.tgz
	@./rel/${REL}/bin/${APP} console

attach: ${PKG}.tgz
	@./rel/${REL}/bin/${APP} attach

#####################################################################
##
## dependencies
##
#####################################################################
rebar:
	@curl -L -O https://github.com/rebar/rebar/wiki/rebar ; \
	chmod ugo+x rebar

.PHONY: test rel deps all pkg 

