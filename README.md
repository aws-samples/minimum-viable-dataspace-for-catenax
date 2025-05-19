# Minimum Viable Dataspace for Catena-X on AWS

The Catena-X Automotive Network e.V. ([Catena-X](https://catena-x.net/) supports the automotive industry’s transition from peer-to-peer data exchange to an interoperable, transparent network leveraging open standards and industry collaboration. Catena-X is an automotive consortium formed by European automakers and their suppliers focused on creating an automotive-specific “data space”, i.e. a space for decentralized data sharing. The Catena-X data space is designed to improve information flow across the automotive value chain. Catena-X promotes a federated architecture, similar to data a mesh, where providers retain data control and sovereignty, sharing only metadata through a decentralized catalog. Data exchange via Catena-X occurs directly between partners, adhering to usage policies that are contractually agreed on.

This sample extends Catena-X' [Tractus-X MXD implementation](https://github.com/eclipse-tractusx/tutorial-resources/tree/main/mxd) to deploy a single-command Minimum Viable Dataspace (MVD) for Catena-X on AWS. For users, this serves as a starting point for experimentation on Catena-X onboarding, implementation against the Eclipse Dataspace Components' (EDC) APIs and testing of initial use cases. **This branch provides a reference implementation for Catena-X release [24.03](https://github.com/eclipse-tractusx/tractus-x-release/blob/main/CHANGELOG.md#2403---2024-03-08) on AWS.**

## Architecture

![architecture diagram](img/mvd-for-catenax.png)

## Getting Started

This project requires `corretto@17`, `docker`, `terraform`, `aws-cli`, `kubectl`, `git` and optionally `helm` to be installed. To provision the MVD for Catena-X on AWS run

```bash
~ ./deploy.sh up

Creating Minimum Viable Dataspace for Catena-X on AWS...
Please enter an alphanumeric string to protect access to your connector APIs.
EDC authentication key:
```

Enter a secret key that you would like the MVD to configure for access to the EDCs' APIs and submit.
The deployment will take 15-20 minutes to complete. After the deployment is done, verify the installation by running

```bash
~ kubectl get pod

NAME                                                     READY   STATUS    RESTARTS   AGE
alice-minio-74c9658b78-55gfw                             1/1     Running   0          5m33s
alice-tractusx-connector-controlplane-86d7dc59c9-x8984   1/1     Running   0          3m6s
alice-tractusx-connector-dataplane-79b7b667dd-9wg2t      1/1     Running   0          3m6s
alice-vault-0                                            1/1     Running   0          3m6s
azurite-5f6d4db54d-s4ptw                                 1/1     Running   0          5m49s
backend-service-74b8fc4bb9-2d4nn                         1/1     Running   0          5m33s
bdrs-server-6bdbc76b9b-tg4tf                             1/1     Running   0          5m32s
bdrs-server-vault-0                                      1/1     Running   0          5m32s
bob-minio-6685d4664f-f8vnc                               1/1     Running   0          5m33s
bob-tractusx-connector-controlplane-67ddfc4bf7-z568h     1/1     Running   0          3m5s
bob-tractusx-connector-dataplane-64d9c7b94b-xxbdf        1/1     Running   0          3m5s
bob-vault-0                                              1/1     Running   0          3m5s
common-postgres-664f7f445d-sgbbv                         1/1     Running   0          5m49s
keycloak-6884cb566f-pxr59                                1/1     Running   0          5m33s
miw-64f8f68996-wwp5c                                     1/1     Running   0          5m33s

~ kubectl get ing

NAME            CLASS   HOSTS   ADDRESS                                      PORTS   AGE
alice-ingress   nginx   *       <lb-domain>.elb.eu-central-1.amazonaws.com   80      5m39s
bob-ingress     nginx   *       <lb-domain>.elb.eu-central-1.amazonaws.com   80      5m39s
mxd-ingress     nginx   *       <lb-domain>.elb.eu-central-1.amazonaws.com   80      3m13s
```

All pods should be in a ready state, the seeding jobs should complete successfully. Next, use this project's [Insomnia](https://github.com/aws-samples/minimum-viable-dataspace-for-catenax/tree/main/insomnia) file as a starting point to perform API operations against the MVD's EDC connectors. For further information about the MVD and its components on AWS refer to this repository's [docs section](https://github.com/aws-samples/minimum-viable-dataspace-for-catenax/tree/main/docs). For an end-to-end walkthrough explaining the deployment and initial use of this sample please refer to the blog post *[Rapidly experimenting with Catena-X data space technology on AWS](https://aws.amazon.com/blogs/industries/rapidly-experimenting-with-catena-x-data-space-technology-on-aws/)*.

## Considerations for Production

The default resource configuration of this project is not indended for use in a production scenario. It is intended as a starting point for rapid Catena-X and data space experimentation and prototyping, that has to be adapted depending on how it is being used. For design principles and best practices on implementing a production-grade workload on AWS please refer to the [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html).

### Configuration

The MVD's EDC connectors are exposed over HTTPS through a [Network Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html) that is provisioned by the Kubernetes ingress controller. Initially, this project creates a self-signed X.509 certificate that is valid for 30 days and is being exposed to the NLB through [AWS Certificate Manager](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/create-tls-listener.html) (ACM). You can replace this initial certificate by requesting or importing a new one through ACM, and adjusting the NLB's listener configuration accordingly.

The MVD's EDC connectors come with key-based authentication for both their control and data planes that can be configured in this project's [`values.yaml.tpl`](https://github.com/aws-samples/minimum-viable-dataspace-for-catenax/blob/main/templates/values.yaml.tpl) template file. This key then has to be provided as an HTTP header `x-api-key` with every API call to one of the EDCs.

## Troubleshooting

### EDC data transfer ignores `keyName` property in `dataDestination`, instead takes the object key defined by the source

See https://github.com/eclipse-edc/Technology-Aws/issues/238 - this is an intended behavior which was introduced with the `keyPrefix` property.

### EDC data catalog requests are no longer working, resulting in timeouts and authentication errors

In case of EDC data catalog request timeouts, a quick remediation can be to redeploy the MXD. This can be done with the following commands

```bash
cd tutorial-resources/mxd/
terraform destroy --auto-approve && sleep 5 && terraform apply --auto-approve
```

Redeploying the Tractus-X MXD to the Kubernetes cluster should take less than 5 minutes to complete.

## Backlog

* Fix conflicts of various seed jobs during (repeated) MXD deployment
  * Error: job: default/bob-azurite-init is not in complete state
  * Error: job: default/alice-azurite-init is not in complete state
  * MXD seed job idempotency
* Include HTTP backend service to be used in addition to Amazon S3 for `DataAddress` definitions
* Include decentral [Digital Twin Registry](https://github.com/eclipse-tractusx/tutorial-resources/issues/50) into MVD deployment

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
