# Erlang Workflow (Makefile)

The workflow depicts the process of distribution Erlang application from sources to the cloud. The actions of this workflow is shown with an example [here](https://github.com/fogfish/hyperion).

## Inspiration

There was multiple attempt to design a various toolchains for building and packaging of Erlang applications such as [GNU auto tools](https://www.gnu.org/software/autoconf/manual/autoconf.html#Erlang-Libraries), application packaging as depicted by Erlang OTP In Action, [rebar](https://github.com/rebar/rebar), [reltool](http://erlang.org/doc/man/reltool.html), [erlang.mk](https://erlang.mk) and other. 

> When you have written one or more applications, you might want to create a complete system with these applications and a subset of the Erlang/OTP applications. This is called a **release**.

The **release** contains complete system including VM binaries, which makes it a perfect distribution package -- a single file to copy into target environment. 

This **workflow** builds a distribution package of Erlang application using [rebar3](https://www.rebar3.org), [relx](https://github.com/erlware/relx) and Makefile orchestration. The workflow aims consistency of operation at developer's environment and automation CI/CD systems. 


## Workflow

1. Clone Erlang application(s) from public, private or enterprise GitHub repository.
1. Set-up development environment and download dependencies.
1. Compile application(s).
1. Spawn backing services (mock environment).
1. Test application(s) with Common Test framework.
1. Debug application(s) at development console (in the shell).
1. Debug application(s) at local Docker runtime.
1. Uniquely identify the release version
1. Package application(s) into Erlang release.
1. Assemble self-installable application bundle from the release.
1. Build a Docker image from the application bundle
1. Ship and run the Docker image at the cloud

This workflow has been developed with following requirements in mind:

* The production deployment of Erlang application performed on hosts running vanilla Linux distribution. The major assumption -- Erlang/OTP runtime __is not__ installed on target host. The application needs to package and deliver Erlang runtime along with its code.

* The application life-cycle management is performed using _service_ management tools supplied by Linux distribution.

* The application development and operation is performed at different environments; the development environment is Mac OSX; the production is either Linux or Docker runtime. The developer shall have ability to assemble of production image without access to dedicated build machines.

* The assembly of production images always automatically executed by CI/CD using source code.


## How it works

The workflow do not conflict with [rebar3 workflow](https://www.rebar3.org/docs/basic-usage). These scripts is a convenience wrapper for rebar3. The usage of this workflow requires Makefiles ([`Makefile`](Makefile), [`erlang.mk`](erlang.mk)) at the root of the project.

```
/app
 └── ...
 └── Makefile
 └── erlang.mk
```

### Setup development environment

Makefile **rebar3** target downloads the rebar3. The target is automatically executed during the compilation phase of the application. Makefile generates all auxiliary scripts and environment variables required by the workflow.

The `rebar.config` identify dependencies of application, which are also managed by rebar3


### Compile and Test application   

The easiest way to compile and test the application is the default Makefile target. You can also invoke **compile** and **test** targets sequentially.

```
make

make compile
make test
```

The **test** target requires that application uses [Common Test framework](http://learnyousomeerlang.com/common-test-for-uncommon-tests). It executes tests, generates html report and returns tests coverage (you can use [coveralls integration](https://github.com/markusn/coveralls-erl) with your project).

```
/app
 └── /test
      └── cover.spec
      └── tests.config
      └── ...
```

### Spawn backing service

The Erlang application might consume any service over network as part of its normal operation. These services are called [backing service](https://12factor.net/backing-services). You might spawn any external backing services within local Docker runtime for development purpose. The Makefile defines targets to spawn (**mock-up**) and tear-down (**mock-rm**) backing services. The **mock-rm** target removes all containers and images. The `test/mock/docker-compose.yml` orchestrates the process of deployment.

```back
make mock-up
make mock-rm
```

These targets requires a `docker-compose.yml` file at `test/mock` subfolder for your project.

```
/app
 └── /test
      └── ...
      └── /mock
           └── docker-compose.yml
```   

### Run application

The **run** target configures path environment, configures VM command line arguments and finally spawns Erlang runtime system **node**. The node name equals to name of application. You can spawn many nodes of same application using `APP` variable to override the node identity.

```
   make run
   
   make run APP=a
   make run APP=b
   make run APP=c
```

### Identify the release

The workflow recommends to use [semantic versioning](http://semver.org) and [git tagging](https://git-scm.com/book/en/v2/Git-Basics-Tagging). It streamlines the process of artefacts labelling. The release identity consists of application name (`app`), git tag (`x.y.z`) and optional pre-release version (`n`). The unique identity is `app-x.y.z[-n]`.  

```
example-0.0.0     // initial application release
example-0.0.0-10  // intermediate release (10 commits after version 0.0.0)
example-0.0.1     // application release with bug fix 
...
example-0.0.1-26  // intermediate release (26 commits after version 0.0.1) 
example-0.1.0     // application release with new feature
...
```

The workflow only requires that developers assigns tags to repository in consistent manner.


### Make release

Erlang **release** is the distribution package, it includes only those application that are required for operation. Please read [this tutorial about releases](http://learnyousomeerlang.com/release-is-the-word) and [that one too](http://alancastro.org/2010/05/01/erlang-application-management-with-rebar.html).    

The **rel** target uses rebar3 to generate release. This process requires a `rel/relx.config.src` file as input. 

```
make release
```

As the result, it assembles a tar-ball `app-x.y.z+arch.plat.tar.gz`. The tar-ball contains Erlang VM and all code required by the application. You can copy this tar-ball to any host and install the application using following command. 

```
tar -zxvf app-x.y.z+arch.plat.tar.gz
```
The `arch` and `plat` identifies CPU architecture and OS platform.

```
example-0.0.0+x86_64.Darwin.tar.gz
example-0.0.0+x86_64.Linux.tar.gz
```

You can automate the installation process of the application using bundles. The bundle is an executable tar-ball prefixed with bootstrap shell script. This script performs installation actions e.g. discover ip address and rewrite vm.args, create init.d script, etc. This workflow provide a reference [`bootstap.sh`](bootstart.sh) 

Use **dist** target to assemble bundle. The bundle production process requires `rel/bootstrap.sh` file.

```
make dist
```  

As the result it produces `app-x.y.z+arch.plat.bundle`. Copy and execute this file on the target host. 


The cross-platform release compilation is required if you are doing development on Mac while using Linux at the cloud. The workflow facilitates cross-platform builds using concept of build toolchain as Docker container. The cross-platform build process spawns a Docker container, copies a git repository and build releases using Linux platform. You can initiate a cross-platform build using following command

```
make dist PLAT=Linux
```

### Run release

You can run the release for quality acceptance purposes using **console** target. It spawns the latest version application release in foreground mode. 

```
make console
``` 

You can also spawn the release and its external backing services with-in local Docker runtime. The Makefile defines targets to spawn (**node-up**) and tear-down (**node-rm**) backing services. The **node-rm** target removes all containers and images. The [`docker-compose.yml`](docker-compose.yml) orchestrates the process of deployment.

```
make node-up
make node-rm
```

<!--
### Benchmark release

**Note**: the benchmark requires significant improvements. 

```
   make benchmark [TEST=...]
```
The command executes performance benchmark script. It spawn basho\_bench along with benchmark specification supplied by application. Makefile uses the default benchmark specification defined at ```priv/${APP}.benchmark``` but ```TEST``` variable can re-define path to any specification. The benchmark procedure follows practice of basho_bench utility. It requires development of application specific benchmark driver. See http://docs.basho.com/riak/latest/ops/building/benchmarking/. The driver is defined at application src folder, specification at priv folder. Makefile contain variable BB that defined path to basho_bench executables.

The benchmark specification MUST defined ```code_path``` to _all_ beam objects and name of ```driver``` module.

```
...
{code_paths, ["./ebin", "./deps/someapp"]}.
{driver,     myapp_benchmark}.
...
```

-->

### Build Docker image

The workflow defines a `Dockerfile` that makes an executable microservice from the bundle. Use **docker** target to package the bundle.

```
make docker
```

The workflow do not define a targets to **publish** and **deploy** docker images. They remains as a cloud platform extension.


## Getting started

The latest version of the workflow is available at `master` branch. Copy all necessary files into your project. 

A typical project structure is following  

```
/app
 └── ...
 └── Makefile
 └── erlang.mk
 └── docker-compose.yml
 └── Dockerfile 
 └── /rel
      └── bootstrap.sh
      └── relx.config.src
 └── /test
      └── cover.spec
      └── tests.config
      └── ...
      └── /mock
           └── docker-compose.yml
           └── ...
```

## Changelog

* 1.0.x - enable composition of multiple workflows (split files)
* 0.9.x - fix and improve workflow for different production use-cases
* 0.8.x - define a basic workflow use-cases

## License

Copyright (c) 2012 Dmitry Kolesnikov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.