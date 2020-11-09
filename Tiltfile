default_registry('dev.local')

def our_knative():
    # deploy the kustomizations
    k8s_yaml(kustomize("./config"))

    # Set Knative service as a Tilt workload
    k8s_kind('Service', api_version='serving.knative.dev/v1',image_json_path='{.spec.template.spec.containers[*].image}')

    # Set up an image build
    docker_build("docker.pkg.github.com/the-gophers/knative-service", ".")

# build our services and live update
our_knative()
