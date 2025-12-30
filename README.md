# Minimum Viable Dataspace on AWS

🚀 Deploy complete [*data space*](https://docs.internationaldataspaces.org/ids-knowledgebase) environments on AWS with a single command.

Secure, sovereign sharing of information is emerging as a requirement across industries globally. This project accelerates data space experimentation and use case testing by making mature reference implementations available as single-command deployment blueprints on AWS. The `mvd` blueprint, for the [Eclipse Minimum Viable Dataspace](https://github.com/eclipse-edc/MinimumViableDataspace), comes with a web application through which data discovery, contract negotiation and data transfers can be explored in a visual manner.

## Quick Start

This project requires additional dependencies to be installed:

* `corretto@17` and `docker` to build [Eclipse Dataspace Components](https://projects.eclipse.org/projects/technology.edc) modules and container images
* `terraform`, `aws-cli` and `kubectl` to deploy AWS infrastructure and Kubernetes resources
* `git` to integrate with relevant GitHub projects (Eclipse MVD, EDC Data Dashboard, Tractus-X Umbrella)

*Minimum Viable Dataspace on AWS* comes with support for two data space blueprints: [Eclipse MVD](https://github.com/eclipse-edc/MinimumViableDataspace) and [Tractus-X MXD](https://github.com/eclipse-tractusx/tutorial-resources/tree/main/mxd) **(deprecated!)**. By default, the `mvd` blueprint should be used.

> [!NOTE]
> If you're accessing this repository to follow along the 2024 blog *[Rapidly experimenting with Catena-X data space technology on AWS](https://aws.amazon.com/blogs/industries/rapidly-experimenting-with-catena-x-data-space-technology-on-aws/)*, make sure to review the warning in [Tractus-X MXD Data Exchange Walk-Through](https://github.com/aws-samples/minimum-viable-dataspace-for-catenax/blob/main/docs/tractusx-mxd-data-exchange-walkthrough.md) upfront.

```bash
~ ./deploy.sh up mvd

Creating Minimum Viable Dataspace on AWS...
Please enter an alphanumeric string to protect access to your connector APIs.
EDC authentication key:
```

Enter a secret key that you would like to configure for access to EDC APIs. Deployment takes 15-20 minutes to complete.

```bash
~ kubectl get pod

NAME                                     READY   STATUS    RESTARTS   AGE
consumer-controlplane-75fcb7bb6d-pj65b   1/1     Running   0          2m13s
consumer-dataplane-78444656f7-msjcn      1/1     Running   0          107s
consumer-identityhub-576f45f8f-qt757     1/1     Running   0          2m49s
consumer-vault-0                         1/1     Running   0          2m51s
data-dashboard-59f55d784f-kwmmx          1/1     Running   0          66s
...

~ kubectl get ing

NAME                           CLASS   HOSTS   ADDRESS                                       PORTS   AGE
consumer-did-ingress           nginx   *        <lb-domain>.elb.eu-central-1.amazonaws.com   80      2m16s
consumer-identityhub-ingress   nginx   *        <lb-domain>.elb.eu-central-1.amazonaws.com   80      2m16s
consumer-ingress               nginx   *        <lb-domain>.elb.eu-central-1.amazonaws.com   80      85s
data-dashboard                 nginx   *        <lb-domain>.elb.eu-central-1.amazonaws.com   80      69s
...
```

🛠️ The included [EDC Data Dashboard](https://github.com/eclipse-edc/DataDashboard) will be accessible under `https://<lb-domain>.elb.eu-central-1.amazonaws.com/dashboard/home`. To get started with experimenting refer to the Eclipse MVD's [Postman Collections](https://github.com/eclipse-edc/MinimumViableDataspace/tree/main/deployment/postman) and [EDC Samples](https://github.com/eclipse-edc/Samples) repository.

## Architecture

![architecture diagram](img/tractusx-mxd-blueprint-architecture.png)

## Learn More

* [AWS-specific service integrations for EDC](https://github.com/eclipse-edc/Technology-Aws)
* [AWS joins Catena-X, underscoring commitment to transparency and collaboration in the global Automotive and Manufacturing Industries](https://aws.amazon.com/blogs/industries/aws-joins-catena-x/)
* [Aspect Models for Eclipse Tractus-X Semantic Layer (SLDT)](https://github.com/eclipse-tractusx/sldt-semantic-models/)
* [Rapidly experimenting with Catena-X data space technology on AWS](https://aws.amazon.com/blogs/industries/rapidly-experimenting-with-catena-x-data-space-technology-on-aws/)

## Configuration

The MVD's EDC connectors and Data Dashboard are exposed over HTTPS through a [Network Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html) that is provisioned by the Kubernetes Nginx ingress controller. Initially, this project creates a self-signed X.509 certificate that is valid for 30 days and is being exposed to the NLB through [AWS Certificate Manager](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/create-tls-listener.html) (ACM). You can replace this initial certificate by requesting or importing a new one through ACM, and adjusting the NLB's listener configuration accordingly.

The MVD's EDC connectors come with API key-based authentication that is configured as part of this project's [`deploy.sh`](https://github.com/aws-samples/minimum-viable-dataspace-for-catenax/blob/main/deploy.sh) dialog. This API key then needs to be provided through an HTTP header `x-api-key` with each invocation of one of the EDCs' APIs.

By default, this project creates a new AWS VPC with all required networking components. However, you can optionally deploy into an existing VPC by providing its VPC ID to the `deploy.sh` script.

### Using an Existing VPC

To deploy into an existing VPC, set the `VPC_ID` variable:

```bash
# deploy.sh
VPC_ID="vpc-1234567890abcdef0"
```

### Requirements for Existing VPCs

* **Private Subnets**: At least 2 private subnets tagged with `kubernetes.io/role/internal-elb=1`
* **Public Subnets**: At least 2 public subnets tagged with `kubernetes.io/role/elb=1`
* **Availability Zones**: Subnets must be distributed across multiple AZs for high availability

## Considerations for Production

The default configuration of this project is not indended for use in a production scenario. It is intended as a starting point for rapid data space and Catena-X experimentation and prototyping, that needs adaptation depending on how it is being used. For design principles and best practices on implementing production-ready workloads on AWS please refer to the [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html).

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
