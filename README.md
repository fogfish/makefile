# Erlang build script

There is a needs to build standalone Erlang software service deployable to hosts on network, such high-level package is called a _release_ in OTP. There was an attempt to use various build solution such as GNU autotools with custom M4 macros, application packaging as depicted by Erlang OTP In Action, rebar, reltool, erlang.mk and other. However, there is set of requirements which needs to be addressed to simplify production operation, see section below. Rebar and reltool with naive Makefile glue allows to achieve then. This Makefile script is one way to focus on these requirements. 

## Requirements

1. The production deployment of Erlang application performed on hosts running vanilla Linux distribution. The major assumption -- Erlang/OTP runtime __is not__ installed on target host. The application needs to package and deliver Erlang runtime along with its code.

1. The application life-cycle management is performed using _service_ management tools supplied by Linux distribution. The operation team can start / stop target application as a daemons using unified approach (e.g. service xxx start).

1. The application development and operation is performed on various environment; the development environment is built on Mac OS; the production system uses Linux distributions. The developer shall have ability to assemble of production image without access to dedicated build machines.

1. The assembly of production images always managed from source code repository either private or public git. It slows down procedure of package assembly but ensure consistency of delivered code.

## Background

The Makefile is utility script to build and release Erlang applications. The script is a convenience wrapper for rebar and reltool. Its philosophy to perform management actions using make utility within command-line. It produces self-contained package (tar-ball or executable bundle) distributable as-is to any vanilla Linux distribution. You copy-and-execute unit on destination host, nothing else is required. The script supports simple Erlang library and complex Erlang application that are packaged inside release. The knowledge of rebar and reltool is needed. 

```
   make
   make test
   make benchmark
   make pkg
   make node pass=... host=...
```

The show-case scenario of Makefile is shown on https://github.com/fogfish/hyperion project that define an empty Erlang node.


## Build library / application

The library or standalone application is simplest unit that implements some use-case, provides interface and exposes dependencies to other application. Please see Erlang manual for detail about the application concept http://www.erlang.org/doc/design_principles/applications.html

Copy Makefile to root folder of application



### Compile

```
   make
```
The utility expects presence of rebar.config that define application dependencies.



### Unit Test

```
   make test
```
Executes unit tests specified at test folder. Having ```{cover_enabled, true}.``` at rebar.config ensure compilation of coverage report.



### Run

```
   make run [APP=...] [NET=...]
```
The utility spawn Erlang VM, configures path environment to application dependencies. The node name equals to application name (the name of current folder) by default. It can be overridden using ```APP``` variable, which allows to spawn multiple node with same code base for RnD purposes. The node is bound to ip address of en0 interface. The default binding is changed through ```NET``` variable.



### Benchmark

```
   make benchmark [TEST=...]
```
The command executes performance benchmark script. It spawn basho_bench along with benchmark specification supplied by application. Makefile uses the default benchmark specification defined at ```priv/${APP}.benchmark``` but ```TEST``` variable can re-define path to any specification. The benchmark procedure follows practice of basho_bench utility. It requires development of application specific benchmark driver. See http://docs.basho.com/riak/latest/ops/building/benchmarking/. The driver is defined at application src folder, specification at priv folder. Makefile contain variable BB that defined path to basho_bench executables.

The benchmark specification MUST defined ```code_path``` to _all_ beam objects and name of ```driver``` module.

```
...
{code_paths, ["./ebin", "./deps/someapp"]}.
{driver,     myapp_benchmark}.
...
```


## Build Erlang Release

Erlang _release_ is an approach to package target application including only those application that are needed to work as-a-service. There was written tons of tutorial about release management

 * http://www.erlang.org/doc/man/reltool.html
 * http://learnyousomeerlang.com/release-is-the-word
 * http://alancastro.org/2010/05/01/erlang-application-management-with-rebar.html

The last one explain on rebal and reltool.config


### Tarball

```
   make rel [config=...]
```
It has dependencies on reltool.config. The script assembles tarball ```{relname}-{vsn}.{arch}.{plat}.tgz```. The release name and version is extracted from ```reltool.config``` as it is defined by ```target_dir``` variable. The arch and plat is CPU architecture and OS platform e.g x86_64.Linux. The tarball contains all dependencies and virtual machine. You can copy tarball to any network host and extract it to any place ```tar -zxvf {relname}-{vsn}.{arch}.{plat}.tgz```

It is possible to supply a dedicated variables overlays via ```config``` variable if the reltool uses overaly. 


### Bundle

```
   make pkg [config=...]
```
The bundle is an executable tarball prefixed with shell script. The bundle script performs all installation actions, e.g. discover ip address and rewrite vm.args, create init.d script, etc. The makefile uses ```rel/deploy.sh``` script to define application specific actions, the deploy script is defined with variables

 * PREFIX - path to installation prefix
 * REL - path to application root folder
 * APP - application name
 * VSN - application version

### Cross platform bundle

```
   make pkg PLAT=Linux [GIT=...]
```
The command assembles Linux compatible release on Mac OS. It uses docker (boot2docker Mac OS) to assemble the application. It spawn docker container and supply shell instruction to it. These instruction clones git repository and make package using make && make pkg. The resulted file is uploaded to host. It is required to define virtual machine image at Makefile (e.g. ```VMI=fogfish/otp:R16B03-1```) and prefix to git repository (e.g. ```GIT=https://github.com/fogfish```)

### Deploy

```
   make node pass=... host=... [PLAT=...]
```
The script deploys (copy-and-executed) the bundle to network host. The ```pass``` variable define path to private ssh key ```host``` is user name and host name (e.g. ```make node pass=~/.ssh/id_rsa  host=ec2-user@example.com```)

