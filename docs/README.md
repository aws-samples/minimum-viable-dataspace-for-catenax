# Tractus-X EDC on AWS

This page provides further details on [Tractus-X EDC](https://github.com/eclipse-tractusx/tractusx-edc), its APIs and available AWS service integrations. While EDC is a modular software with a number of extensions available, only a subset are included by default into its Tractus-X variant. As of 2025, support for [Amazon S3](https://aws.amazon.com/s3/) is included as part of an initial set of extensions. Tractus-X EDC also comes with a number of [custom extensions](https://github.com/eclipse-tractusx/tractusx-edc/tree/main/edc-extensions) that are specific to Catena-X.

The Tractus-X EDC REST API documentation is available on SwaggerHub:

* https://app.swaggerhub.com/apis/eclipse-tractusx-bot/tractusx-edc/0.9.0

For the [Eclipse EDC connector](https://github.com/eclipse-edc/Connector), there are extensions available for both Amazon S3 and [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/), located in a [dedicated repository](https://github.com/eclipse-edc/Technology-Aws) to which AWS has contributed. Tractus-X EDC to date only bundles the S3 extension and does not yet support AWS Secrets Manager with the default images provided. Recent additions to both EDC's and Digital Twin Registry's (DTR) AWS integrations include:

* Support for [prefix-based data transfer](https://github.com/eclipse-edc/Technology-Aws/pull/104) over S3 by introducing a new `keyPrefix` property within a `DataAddress` configuration
* Support for [Amazon Cognito](https://aws.amazon.com/cognito/) as an alternative to Keycloak in Digital Twin Registry ([PR is still open](https://github.com/eclipse-tractusx/sldt-digital-twin-registry/pull/400))

For further information also refer to the [Tractus-X MXD's documentation](https://github.com/eclipse-tractusx/tutorial-resources/tree/main/mxd/docs) on GitHub.

## EDC API Calls for Amazon S3

`POST /v3/assets` (data provider)

```json
{
  "@context": {
    "edc": "https://w3id.org/edc/v0.0.1/ns/"
  },
  "@id": "1",
  "properties": {
    "description": "Amazon S3 Demo Asset"
  },
  "dataAddress": {
    "type": "AmazonS3",
    "keyName": "provider/example.json",
    "region": "eu-central-1",
    "bucketName": "catena-x-mvd"
  }
}

```

`POST /v2/transferprocesses` (data consumer)

```json
{
  "@context": {
    "odrl": "http://www.w3.org/ns/odrl/2/"
  },
  "assetId": "1",
  "connectorAddress": "http://provider-controlplane:8084/api/v1/dsp",
  "connectorId": "BPNL000000000001",
  "contractId": "f3c6774b-9fe6-4851-cc1d-f8a7dd96c712",
  "dataDestination": {
    "type": "AmazonS3",
    "keyName": "consumer/example.json",
    "region": "eu-central-1",
    "bucketName": "catena-x-mvd"
  },
  "protocol": "dataspace-protocol-http",
  "transferType": {
    "contentType": "application/octet-stream",
    "isFinite": true
  }
}
```

## Learn More

To learn more about Catena-X, Tractus-X and the EDC refer to the following links

* [AWS joins Catena-X, underscoring commitment to transparency and collaboration in the global Automotive and Manufacturing Industries](https://aws.amazon.com/blogs/industries/aws-joins-catena-x/)
* [Eclipse Tractus-X Changelog](https://github.com/eclipse-tractusx/tractus-x-release/blob/main/CHANGELOG.md)
* [Eclipse Tractus-X Connector KIT](https://eclipse-tractusx.github.io/docs-kits/category/connector-kit)
* [Eclipse Tractus-X EDC (Eclipse Dataspace Connector)](https://github.com/eclipse-tractusx/tractusx-edc)
* [Aspect Models for Eclipse Tractus-X Semantic Layer (SLDT)](https://github.com/eclipse-tractusx/sldt-semantic-models/)
