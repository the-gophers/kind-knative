# kind-knative
Template providing a starting point for building a knative application using Kind and GitHub Actions. In this
sample, you will have a fast innerloop development experience using [tilt.dev](https://tilt.dev/) and 
[KinD](https://kind.sigs.k8s.io/).

## Requirements
- [Docker](https://docs.docker.com/get-docker/)
- [Install kind v0.9+](https://kind.sigs.k8s.io/#installation-and-usage)
- [Install Tilt](https://docs.tilt.dev/install.html)

## Getting Started
This is a GitHub template repo, so when you click "Use this template", it will create a new copy of this 
template in your org or personal repo of choice. Once you have created a repo from this template, you 
should be able to clone and navigate to the root of the repository.

### First Build
```shell script
make
```

### What's in Here
```shell script
.
├── config
│   ├── image-patch-template.yml
│   ├── kind-config.yml
│   ├── knative-helloworld.yml
│   ├── kourier-listen.yml
│   ├── kustomization.yml
│   └── service.yml
├── Dockerfile
├── .github
│   └── workflows
│       └── e2e.yml
├── .gitignore
├── go.mod
├── LICENSE
├── main.go
├── Makefile
├── README.md
├── scripts
│   ├── ci-e2e.sh
│   ├── go_install.sh
│   └── kind-without-local-registry.sh
├── test
│   └── config
│       ├── image-patch.yml
│       └── kustomization.yml
├── Tiltfile

```
#### [./config](./config)
This is where all our K8s yamls are stored. These include our knative service, service.yml.

#### [./main.go](./main.go)
The entrypoint for our Go knative service.

#### [./scripts](./scripts)
Contains any of the setup and build related scripts. The `./scripts/ci-e2e.sh` runs a continuous integration
build with a time based tag of the knative service to be hosted in Kind for use in E2E testing in GitHub Actions.

#### [./test/config](./test/config)
This is where we add our test patches which help us to override values in the default configuration.

## Run with Tilt
Tilt will live reload your containers to allow you to build with a super fast inner loop. To jump into this,
run the following:
```shell script
make tilt-up
```
Once Tilt is running, press space, and it will open a browser with a UI.

To access the running service, run the following:
```
curl $(make dev-url)
```

## What's Next?
Go build your own stuff in the knative service and tell everyone about it!

## Lab Video
TODO: record and post the first lab walking through creation, execution and optimization

## Contributions
Always welcome! Please open a PR or an issue, and remember to follow the [Gopher Code of Conduct](https://www.gophercon.com/page/1475132/code-of-conduct).
