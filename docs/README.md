# Tractus-X EDC on AWS

This page provides further details on the [Tractus-X EDC](https://github.com/eclipse-tractusx/tractusx-edc), its APIs and available AWS Cloud service integrations. While EDC is a modular software with a number of extensions available, only a subset are included by default into its Tractus-X variant. [This document](https://github.com/eclipse-tractusx/tractusx-edc/tree/main/docs/development/decision-records/2023-08-24-proprietrary-extensions) from 2023-08-24, describes the decision to include support for Amazon S3 as one initial proprietary extension. Tractus-X EDC also comes with a number of [custom extensions](https://github.com/eclipse-tractusx/tractusx-edc/tree/main/edc-extensions) that are specific to Catena-X.

There are OpenAPI specs / Swagger UI pages available on SwaggerHub for the [vanilla EDC connector](https://github.com/eclipse-edc/Connector):

* https://app.swaggerhub.com/apis/eclipse-edc-bot/management-api (control plane)
* https://app.swaggerhub.com/apis/eclipse-edc-bot/control-api (data plane)

Overall, there are extensions available for both Amazon S3 and AWS Secrets Manager, located in a [dedicated EDC repository](https://github.com/eclipse-edc/Technology-Aws) to which AWS has contributed. Tractus-X to date only bundles the S3 extension and does not yet support AWS Secrets Manager with the default images provided. Recent additions to EDC's AWS extensions include:

* Support for [prefix-based data transfer](https://github.com/eclipse-edc/Technology-Aws/pull/104) over S3 by introducing a new `keyPrefix` property within a `DataAddress` configuration

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
