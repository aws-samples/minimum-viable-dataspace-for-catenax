# Minimum Viable Dataspace for Catena-X on AWS

[Catena-X](https://catena-x.net/) aims to create greater transparency by building a trustworthy, collaborative, open and secure data ecosystem for the automotive industry. [AWS joined Catena-X](https://aws.amazon.com/blogs/industries/aws-joins-catena-x/) as a member in January 2023.

This sample extends Catena-X' [Tractus-X MXD implementation](https://github.com/eclipse-tractusx/tutorial-resources/tree/main/mxd) to deploy a single-command Minimum Viable Dataspace (MVD) for Catena-X on AWS. For users, this serves as a starting point for experimentation around Catena-X onboarding, implementation against the Eclipse Dataspace Components' (EDC) APIs and evaluation of initial use cases. **This repository provides reference implementations for the Catena-X releases [24.03](https://github.com/eclipse-tractusx/tractus-x-release/blob/main/CHANGELOG.md#2403---2024-03-08) and [24.12](https://github.com/eclipse-tractusx/tractus-x-release/blob/main/CHANGELOG.md#2412---2024-12-02) on AWS.** For past versions refer to this repository's [releases](https://github.com/aws-samples/minimum-viable-dataspace-for-catenax/releases).

## Architecture

![architecture diagram](img/mvd-for-catenax.png)

## Getting Started

This project requires `corretto@17`, `docker`, `terraform`, `aws-cli`, `kubectl`, `git` and optionally `helm` to be installed. To provision the MVD on AWS sample run

```bash
~ ./deploy.sh up

Creating Minimum Viable Dataspace for Catena-X on AWS...
Please enter an alphanumeric string to protect access to your connector APIs.
EDC authentication key:
```

Enter a secret key that you would like the MVD sample to configure to access the EDCs' APIs and submit.
The deployment will take 15-20 minutes to complete. After the deployment is done, verify the installation by running

```bash
~ kubectl get pod

NAME                                                     READY   STATUS    RESTARTS   AGE
alice-catalogserver-58d5b55db9-lpdc9                     1/1     Running   0          3m36s
alice-catalogserver-postgres-6fd4786898-4mnds            1/1     Running   0          6m12s
alice-ih-b844bf6cd-dpwv8                                 1/1     Running   0          3m37s
alice-minio-796bbc5965-hxrp4                             1/1     Running   0          6m12s
alice-postgres-79484d5968-ccgdg                          1/1     Running   0          6m12s
alice-sts-75f7f9d557-sz7gr                               1/1     Running   0          6m12s
alice-tractusx-connector-controlplane-85bb9c6f6c-pgd2s   1/1     Running   0          5m44s
alice-tractusx-connector-dataplane-cb6dd7986-dpwrb       1/1     Running   0          5m44s
alice-vault-0                                            1/1     Running   0          5m44s
azurite-5f6d4db54d-5knmh                                 1/1     Running   0          6m12s
bdrs-postgres-7df445cdc6-xk8jc                           1/1     Running   0          6m12s
bdrs-server-6d487f7794-9h6ht                             1/1     Running   0          5m44s
bdrs-server-vault-0                                      1/1     Running   0          5m44s
bob-ih-6686cf9457-w7vm7                                  1/1     Running   0          3m37s
bob-minio-9c54f56f8-9ztvc                                1/1     Running   0          6m12s
bob-postgres-68994f97fd-2xjk7                            1/1     Running   0          6m12s
bob-tractusx-connector-controlplane-8bc45fd79-fgqdv      1/1     Running   0          5m44s
bob-tractusx-connector-dataplane-77c89798b4-l5bq7        1/1     Running   0          5m44s
bob-vault-0                                              1/1     Running   0          5m44s
data-service-api-589d664459-hfb94                        1/1     Running   0          6m12s
dataspace-issuer-server-65b999ff84-ptfvq                 1/1     Running   0          6m12s

~ kubectl get ing

NAME                          CLASS   HOSTS       ADDRESS                     PORTS   AGE
alice-connector-ingress       nginx   *           <lb-domain>.amazonaws.com   80      6m27s
alice-cs-ingress              nginx   localhost   <lb-domain>.amazonaws.com   80      3m32s
alice-ih-did-server-ingress   nginx   localhost   <lb-domain>.amazonaws.com   80      3m22s
alice-ih-ingress              nginx   localhost   <lb-domain>.amazonaws.com   80      3m22s
bob-connector-ingress         nginx   *           <lb-domain>.amazonaws.com   80      6m27s
bob-ih-did-server-ingress     nginx   localhost   <lb-domain>.amazonaws.com   80      3m22s
bob-ih-ingress                nginx   localhost   <lb-domain>.amazonaws.com   80      3m22s
```

## Known issues

* Vaults can't be seeded when re-deploying MXD without re-deploying the full solution, persistant DB vs. non-peristant vault causes conflicts
* Init jobs for Azurite, MinIO, MXD seed frequently time out and result in errors that yet need to be investigated

**Note: Currently, the concluding MXD deployment times out during creation of the `kubernetes_deployment.backend-service` resource, terminating with the error `Waiting for rollout to finish: 1 replicas wanted; 0 replicas Ready`. This is an expected behavior and is due to the MXD's recently added backend service requiring a local Gradle build and loading process of the resulting container image, which this project does not yet support.**

All pods, except for the `backend-service`, should be in a ready state, the seeding jobs should complete successfully. Concludingly, use this project's [Insomnia](https://github.com/aws-samples/minimum-viable-dataspace-for-catenax/tree/main/insomnia) file as a starting point to perform API operations against the MVD's EDC connectors. For further information about the MVD and its components on AWS refer to this repository's [docs section](https://github.com/aws-samples/minimum-viable-dataspace-for-catenax/tree/main/docs).

## Considerations for Production

The default resource configuration of this project is not indended for use in a production scenario. It is intended as a starting point for rapid Catena-X and dataspace experimentation and prototyping, that has to be adapted depending on how it is being used. For design principles and best practices on implementing a production-grade workload on AWS please refer to the [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html).

### Configuration

The MVD's EDC connectors are exposed over HTTPS through a [Network Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html) that is provisioned by the Kubernetes ingress controller. Initially, this project creates a self-signed X.509 certificate that is valid for 30 days and is being exposed to the NLB through [AWS Certificate Manager](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/create-tls-listener.html) (ACM). You can replace this initial certificate by requesting or importing a new one through ACM, and adjusting the NLB's listener configuration accordingly.

The MVD's EDC connectors come with key-based authentication for both their control and data planes that can be configured in this project's [`values.yaml.tpl`](https://github.com/aws-samples/minimum-viable-dataspace-for-catenax/blob/main/templates/values.yaml.tpl) template file. This key then has to be provided as an HTTP header `x-api-key` with every API call to one of the EDCs.

## Troubleshooting

### EDC data transfer ignores `keyName` property in `dataDestination`, instead takes the object key defined by the source

See https://github.com/eclipse-edc/Technology-Aws/issues/238 - this is an intended behavior which was introduced with the `keyPrefix` property.

### EDC data catalog requests are no longer working, resulting in timeouts and authentication errors

In case of EDC data catalog request timeouts, a quick remediation can be to redeploy the MXD. This can be achieved with the following commands

```bash
cd tutorial-resources/mxd/
terraform destroy --auto-approve && sleep 5 && terraform apply --auto-approve
```

Redeploying the Tractus-X MXD to the Kubernetes cluster should take less than 5 minutes to complete.

## Backlog

* Include HTTP backend service to be used in addition to Amazon S3 for `DataAddress` definitions
* Include decentral [Digital Twin Registry](https://github.com/eclipse-tractusx/tutorial-resources/issues/50) into MVD deployment

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
