# Overview

Certain users of the AAW platform (e.g. StatCan employees) require access to certain services in our internal cloud environment (e.g. our internal gitlab instance). This documentation page describes the various mechanisms used to enable certain AAW namespaces connectivity to our cloud main environment.

## Relevant Repositories

- [UDR/Firewall PR to networking module](https://gitlab.k8s.cloud.statcan.ca/cloudnative/aaw/modules/terraform-azure-statcan-aaw-network/-/merge_requests/17)
# Feature Deployment

**Note about Istio Logging**:
> See [Configuring Istio Logging](https://cloudnative.pages.cloud.statcan.ca/en/documentation/monitoring-surveillance/logging/istio/) for more information on how Istio logging is configured. Istio's default log level (`warning`) doesn't show the access logs for this feature, but if you set the log level to `debug`, you can confirm that the correct requests are, in fact, routed through the Istio Egress Gateway.

## Profile State Controller

The `profile-state-controller` watches rolebindings in each kubeflow profile. If a profile only contains role bindings whose subjects' email domains are either `statcan.gc.ca` or `cloud.statcan.ca`, then the profile and corresponding namespace are given the label `state.aaw.statcan.gc.ca/non-employee-users=false`, indicating that there are no non-employee users present in the namespace. If one or more role bindings contain a subject with an email domain other than `statcan.gc.ca` or `cloud.statcan.ca`, the profile and namespace are given the label `state.aaw.statcan.gc.ca/non-employee-users=true`, indicating that there is at least one non-employee user with access to the namespace.

![profile-state-controller](cloud_main_connectivity_profile_state_controller.png)

## Istio Egress Gateway

A `virtual-service-controller` in the `daaas-system` namespace watches namespaces and creates an Istio Virtual Service (`gitlab-virtual-service`) in namespaces with the label `state.aaw.statcan.gc.ca/non-employee-users=false`, but not in namespaces with the label `state.aaw.statcan.gc.ca/non-employee-users=true`. The virtual service configures the envoy proxies of pods in the employee namespace to route outbound traffic with host matching `gitlab.k8s.cloud.statcan.ca` to the `cloud-main-egress-gateway`.

The subnet of the `cloud-main-nodepool` on `aaw-prod-cc-00` has a different IP range from the subnet of user nodes as per https://github.com/StatCan/daaas/issues/1097#issuecomment-1126119440. Due to these different IP ranges, a dedicated Istio egress gateway (`cloud-main-egress-gateway`) can be deployed on a `cloud-main-system` node pool with a distinct IP range from pods scheduled to the user node pool.

The virtual service deployed into employee-only namespaces configures the envoy proxies on each pod in the namespace to route traffic to `gitlab.k8s.cloud.statcan.ca` to the `cloud-main-egress-gateway`. Therefore, when pods running in employee-only namespaces (containing `gitlab-service-entry`) initiate a request to `gitlab.k8s.cloud.statcan.ca`, the request is routed through the `cloud-main-egress-gateway`, which will have an outgoing IP associated with one of the `cloud-main-system` nodes. When pods running in namespaces that contain an external employee (not containing `gitlab-service-entry`), requests to `gitlab.k8s.cloud.statcan.ca` will not be routed through the `cloud-main-egress-gateway`, and therefore will have an outgoing IP address associated with a user node.

In the cloud main boundary firewall, a rule can be put in place to only allow incoming TCP traffic on ports 443 or 22 originating from the `cloud-main-egress-gateway` IP address; requests originating from user pod IPs will be blocked at the firewall level.

In each employee-only namespace, network policies must be added that allow egress to the `cloud-main-system` namespace. A corresponding network policy based on a namespace label selector (see e.g. description posted in  https://github.com/StatCan/daaas/issues/1097#issue-1234409276) must be added to the `cloud-main-system` namespace to allow ingress from employee-only namespaces.

The green arrow in the diagram below shows the route taken by requests to `gitlab.k8s.cloud.statcan.ca` from employee-only namespaces, while the red arrow shows the route taken by requests to `gitlab.k8s.cloud.statcan.ca` from namespaces with at least one non-employee users.

![istio-virtual-service](cloud_main_connectivity_egress_gateway.png)

## Azure Networking

Several Azure components need to be configured through Terraform.

> TODO

![azure-networking](cloud_main_connectivity_azure_network.png)