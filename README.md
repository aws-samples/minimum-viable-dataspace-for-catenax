# Minimum Viable Dataspace for Catena-X on AWS

In October 2023, the Catena-X Automotive Network was productively launched. [Catena-X](https://catena-x.net/) aims to create greater transparency by building a trustworthy, collaborative, open and secure data ecosystem for the automotive industry. [AWS joined Catena-X](https://aws.amazon.com/blogs/industries/aws-joins-catena-x/) as a member in January 2023.

This sample extends Catena-X' [Tractus-X MXD implementation](https://github.com/eclipse-tractusx/tutorial-resources/tree/main/mxd) to deploy a single-command Minimum Viable Dataspace (MVD) for Catena-X on AWS. For users, this serves as a starting point for experimentation around Catena-X onboarding, implementation against the Eclipse Dataspace Components' (EDC) API and realization of initial use cases. This repository provides a reference implementation for Catena-X release [23.12](https://github.com/eclipse-tractusx/tractus-x-release/blob/main/CHANGELOG.md#2312---2023-12-08) on AWS.

## Architecture

![architecture diagram](img/mvd-for-catenax.png)

## Getting Started

This project requires `terraform`, `aws-cli`, `kubectl` and `git` to be installed. To provision the MVD on AWS sample run

```bash
~ ./deploy.sh up
```

The deployment will take around 20 minutes to complete. After the deployment is done verify the installation by running

```bash
~ kubectl get pod

NAME                                                     READY   STATUS    RESTARTS   AGE
alice-tractusx-connector-controlplane-6b9f67d7f5-qlclg   1/1     Running   0          23m
alice-tractusx-connector-dataplane-667c9c899d-l7t4w      1/1     Running   0          23m
alice-vault-0                                            1/1     Running   0          23m
bob-tractusx-connector-controlplane-78ff8655dd-89qhr     1/1     Running   0          23m
bob-tractusx-connector-dataplane-6cfcdbdccc-j6v2b        1/1     Running   0          23m
bob-vault-0                                              1/1     Running   0          23m
keycloak-6f7c877cff-xk2s5                                1/1     Running   0          24m
miw-967d66dd5-xqpkb                                      1/1     Running   0          24m
postgres-65d5475f95-5mng8                                1/1     Running   0          24m

~ kubectl get ing

NAME            CLASS   HOSTS   ADDRESS                                      PORTS   AGE
alice-ingress   nginx   *       <lb-domain>.elb.eu-central-1.amazonaws.com   80      25m
bob-ingress     nginx   *       <lb-domain>.elb.eu-central-1.amazonaws.com   80      25m
mxd-ingress     nginx   *       <lb-domain>.elb.eu-central-1.amazonaws.com   80      24m
```

All pods should be in a ready state, the seeding jobs should complete successfully. Concludingly, use this project's [Insomnia](https://github.com/aws-samples/minimum-viable-dataspace-for-catenax/tree/main/insomnia) file as a starting point to perform API operations against the MVD's EDC connectors. For further information about the MVD and its components on AWS refer to this repository's [docs section](https://github.com/aws-samples/minimum-viable-dataspace-for-catenax/tree/main/docs).

## Considerations for Production

The default resource configuration of this project is not indended for use in a production scenario. It is intended as a starting point for rapid Catena-X and dataspace experimentation and prototyping, that has to be adapted depending on how it is being used. For design principles and best practices on implementing a production-grade workload on AWS please refer to the [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html).

### Configuration

The MVD's EDC connectors are exposed over HTTPS through a [Network Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html) that is provisioned by the Kubernetes ingress controller. Initially, this project creates a self-signed X.509 certificate that is valid for 30 days and is being exposed to the NLB through [AWS Certificate Manager](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/create-tls-listener.html) (ACM). You can replace this initial certificate by requesting or importing a new one through ACM, and adjusting the NLB's listener configuration accordingly.

The MVD's EDC connectors come with key-based authentication for both their control and data planes that can be configured in this project's [`values.yaml.tpl`](https://github.com/aws-samples/minimum-viable-dataspace-for-catenax/blob/main/templates/values.yaml.tpl) template file. This key then has to be provided as an HTTP header `x-api-key` with every API call to one of the EDCs.

## Troubleshooting

### EDC data plane operations are no longer working, how to resolve?

In case of EDC data plane issues such as when facing timeouts on data catalog requests, a quick remediation is to redeploy the MXD. This can be achieved with the following commands

```bash
cd tutorial-resources/mxd/
terraform destroy --auto-approve && sleep 5 && terraform apply --auto-approve
```

Redeploying the Tractus-X MXD to the Kubernetes cluster should take less than 5 minutes to complete.

## Backlog

* Include HTTP backend service to be used in addition to Amazon S3 for `DataAddress` definitions
* Adjust templating for compatibility with the latest MXD version's [MinIO deployment](https://github.com/eclipse-tractusx/tutorial-resources/commit/74d830b0a5166c3c0fd9fbd0f7812802ef4b40f0)

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
