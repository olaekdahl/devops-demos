# Conftest / OPA policy: refuse manifests that reference :latest images.
package main

deny[msg] {
  input.kind == "Deployment"
  some i
  c := input.spec.template.spec.containers[i]
  endswith(c.image, ":latest")
  msg := sprintf("container %q uses :latest tag (forbidden)", [c.name])
}
