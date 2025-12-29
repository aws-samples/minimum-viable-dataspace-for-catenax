# Tractus-X MXD Data Exchange Walk-Through

[!WARNING]
This walk-through was created in 2024 to follow along the blog post *[Rapidly experimenting with Catena-X data space technology on AWS](https://aws.amazon.com/blogs/industries/rapidly-experimenting-with-catena-x-data-space-technology-on-aws/)*. The `mxd` blueprint used in this guide has been deprecated since, as the upstream [Tractus-X MXD](https://github.com/eclipse-tractusx/tutorial-resources/tree/main/mxd) is no longer maintained. As a result, this walk-through may no longer work but can still serve as a reference for an EDC data transfer.

## Step 1: Environment Setup

Inside the cloned repository, run the ```./deploy.sh``` script, which will use the default AWS CLI settings to deploy the MVD using Terraform. The deployment will take 15-20 minutes to complete. When prompted, provide a secret API key and store it as an environment variable:

```bash
./deploy.sh up mxd
```
```bash
export API_KEY=<SECRET_API_KEY>
```

The deployment defaults to the ```eu-central-1``` (Frankfurt) region but can be changed in ```./deploy.sh```. After it’s deployed, the script will print the Alice and Bob Amazon S3 bucket names - store these in variables:

```bash
export ALICE_BUCKET=<ALICE_BUCKET_NAME>
export BOB_BUCKET=<BOB_BUCKET_NAME>
```

Next, obtain the NLB Domain Name System (DNS) name.

```bash
kubectl get ing
```
You will get an output similar to this:
```bash
NAME            CLASS   HOSTS   ADDRESS                               PORTS   AGE
alice-ingress   nginx   *       <NAME>.elb.eu-central-1.amazonaws.com   80      14h
bob-ingress     nginx   *       <NAME>.elb.eu-central-1.amazonaws.com   80      14h
mxd-ingress     nginx   *       <NAME>.elb.eu-central-1.amazonaws.com   80      14h
```

Store the DNS name of the NLB created for Alice, Bob, and the MXD ingresses:
```bash
export NLB_DNS=<NAME>.elb.eu-central-1.amazonaws.com
```

## Step 2: Create a File in Alice’s Bucket

```bash
echo "Hello World" >> alice-file.txt
aws s3 cp alice-file.txt s3://$ALICE_BUCKET
```

## Step 3: Create the EDC Asset

Next, Alice has to register the file in Amazon S3 with the data space connector by creating an Asset.
```bash
curl -k --location "https://$NLB_DNS/alice/management/v3/assets" \
--header 'Content-Type: application/json' \
--header "X-Api-Key: $API_KEY" \
--data-raw '{
  "@context": {},
  "@id": "20",
  "properties": {
    "name": "alice-test-document",
    "description": "Product EDC Demo S3 Asset",
    "contenttype": "text/plain",
    "version": "1.0"
  },
  "dataAddress": {
    "@type": "DataAddress",
    "type": "AmazonS3",
    "keyName": "alice-file.txt",
    "region": "eu-central-1",
    "bucketName": "'$ALICE_BUCKET'"
  }
}'
```

## Step 4: Create the EDC Usage Policy

Usage of Assets can be restricted by attaching contracts to them. Restrictions are defined by Policies that are attached to Contracts. Before Alice can create a Contract, she has to create those Policies. Alice wants to restrict usage of the Asset to data space participants who have an active Catena-X business partner number (BPN); that is, those who are registered in the data space and are currently active members. The following Usage Policy achieves this.
```bash
curl -k --location "https://$NLB_DNS/alice/management/v2/policydefinitions" \
--header 'Content-Type: application/json' \
--header "X-Api-Key: $API_KEY" \
--data-raw '{
  "@context": {
    "odrl": "http://www.w3.org/ns/odrl/2/"
  },
  "@type": "PolicyDefinitionRequestDto",
  "@id": "201",
  "policy": {
    "@type": "odrl:Set",
    "odrl:permission": [
      {
        "odrl:action": "USE",
        "odrl:constraint": {
          "@type": "LogicalConstraint",
          "odrl:or": [
            {
              "@type": "Constraint",
              "odrl:leftOperand": "BpnCredential",
              "odrl:operator": {
                "@id": "odrl:eq"
              },
              "odrl:rightOperand": "active"
            }
          ]
        }
      }
    ]
  }
}'
```

## Step 5: Create the EDC Contract Policy

The Contract Policy restricts who can enter a Contract for the Asset with the asset provider. Here, Alice restricts access to Bob by allow-listing his BPN.
```bash
curl -k --location "https://$NLB_DNS/alice/management/v2/policydefinitions" \
--header 'Content-Type: application/json' \
--header "X-Api-Key: $API_KEY" \
--data-raw '{
  "@context": {
    "odrl": "http://www.w3.org/ns/odrl/2/"
  },
  "@type": "PolicyDefinitionRequestDto",
  "@id": "202",
  "policy": {
    "@type": "odrl:Set",
    "odrl:permission": [
      {
        "odrl:action": "USE",
        "odrl:constraint": {
          "@type": "LogicalConstraint",
          "odrl:or": [
            {
              "@type": "Constraint",
              "odrl:leftOperand": "BusinessPartnerNumber",
              "odrl:operator": {
                "@id": "odrl:eq"
              },
              "odrl:rightOperand": "BPNL000000000002"
            }
          ]
        }
      }
    ]
  }
}'
```

## Step 6: Create the EDC Contract Definition

Now, Alice is ready to create the Contract for the Asset and assign the two previously created Policies to it.
```bash
curl -k --location "https://$NLB_DNS/alice/management/v2/contractdefinitions" \
--header 'Content-Type: application/json' \
--header "X-Api-Key: $API_KEY" \
--data-raw '{
  "@context": {},
  "@id": "20",
  "@type": "ContractDefinition",
  "accessPolicyId": "201",
  "contractPolicyId": "202",
  "assetsSelector": {
    "@type": "CriterionDto",
    "operandLeft": "https://w3id.org/edc/v0.0.1/ns/id",
    "operator": "=",
    "operandRight": "20"
  }
}'
```

## Step 7: Query Alice’s Data Catalog

All the previous interactions were with Alice’s instance of the data space connector. Because we let Bob see the Contract by adding his BPN to the Contract Policy, he should now see the Contract when querying Alice’s data catalog.
```bash
curl -k --location "https://$NLB_DNS/bob/management/v2/catalog/request" \
--header 'Content-Type: application/json' \
--header "X-Api-Key: $API_KEY" \
--data-raw '{
  "@context": {
    "edc": "https://w3id.org/edc/v0.0.1/ns/"
  },
  "@type": "CatalogRequest",
  "counterPartyAddress": "http://alice-controlplane:8084/api/v1/dsp",
  "counterPartyId": "BPNL000000000001",
  "protocol": "dataspace-protocol-http",
  "querySpec": {
    "offset": 0,
    "limit": 50
  }
}'
```

You will get output similar to this:
```bash
{
    "@id": "f66c2bd8-df28-4970-80db-00d99285b89f",
    "@type": "dcat:Catalog",
    "dcat:dataset": [
        {
            "@id": "20",
            "@type": "dcat:Dataset",
            "odrl:hasPolicy": {
                "@id": "<CONTRACT_ID>",
                "@type": "odrl:Set",...
                },...
            },...
        }
    ],...
}
```
Take note of the `<CONTRACT_ID>` of the response. You will need it in the next step.

## Step 8: Initiate the EDC Contract Negotiation

Next, Bob has to initiate a Contract Negotiation for the Asset. During a Contract Negotiation, the connectors check whether both parties are authorized to enter the contract.
```bash
curl -k --location "https://$NLB_DNS/bob/management/v2/contractnegotiations" \
--header 'Content-Type: application/json' \
--header "X-Api-Key: $API_KEY" \
--data-raw '{
  "@context": {
    "odrl": "http://www.w3.org/ns/odrl/2/"
  },
  "@type": "NegotiationInitiateRequestDto",
  "connectorAddress": "http://alice-controlplane:8084/api/v1/dsp",
  "protocol": "dataspace-protocol-http",
  "connectorId": "BPNL000000000001",
  "providerId": "BPNL000000000001",
  "offer": {
    "offerId": "<CONTRACT_ID>",
    "assetId": "20",
    "policy": {
      "@type": "odrl:Set",
      "odrl:permission": {
        "odrl:target": "20",
        "odrl:action": {
          "odrl:type": "USE"
        },
        "odrl:constraint": {
          "odrl:or": [
            {
              "@type": "Constraint",
              "odrl:leftOperand": "BusinessPartnerNumber",
              "odrl:operator": {
                "@id": "odrl:eq"
              },
              "odrl:rightOperand": "BPNL000000000002"
            }
          ]
        }
      },
      "odrl:prohibition": [],
      "odrl:obligation": [],
      "odrl:target": "20"
    }
  }
}'
```

Take note of the `<NEGOTIATION_ID>`. You will need it in the next step.
```bash
{
    "@type": "edc:IdResponse",
    "@id": "<NEGOTIATION_ID>",
    "edc:createdAt": 1710328741168,
    ...
}
```

## Step 9: Check the Negotiation Result

Bob can now check whether the Negotiation was successful and whether he can therefore start the Asset transfer process from Alice’s Amazon S3 bucket to his own Amazon S3 bucket.
```bash
curl -k --location "https://$NLB_DNS/bob/management/v2/contractnegotiations/<NEGOTIATION_ID>" \
--header "X-Api-Key: $API_KEY"
```
You should see a “FINALIZED” negotiation.
```bash
{
    "@type": "edc:ContractNegotiation",
    "@id": "<NEGOTIATION_ID>",
    ...
    "edc:state": "FINALIZED",
    ...
    "edc:contractAgreementId": "<CONTRACT_AGREEMENT_ID>",
    ...
}
```

Take note of the `<CONTRACT_AGREEMENT_ID>`. You will need it in the next step.

## Step 10: Initiate the EDC Data Transfer

Using the `<CONTRACT_AGREEMENT_ID>` of the negotiated contract, Bob can now initiate a data transfer. For this, he has to specify the destination of the data transfer, such as his Amazon S3 bucket. The source and destination of the data transfer are decoupled. It would similarly be possible to transfer data to a destination different from Amazon S3 or to pull data through an HTTP endpoint directly. 
```bash
curl -k --location "https://$NLB_DNS/bob/management/v2/transferprocesses" \
--header 'Content-Type: application/json' \
--header "X-Api-Key: $API_KEY" \
--data-raw '{
  "@context": {
    "odrl": "http://www.w3.org/ns/odrl/2/"
  },
  "assetId": "20",
  "connectorAddress": "http://alice-controlplane:8084/api/v1/dsp",
  "connectorId": "BPNL000000000001",
  "contractId": "<CONTRACT_AGREEMENT_ID>",
  "dataDestination": {
    "type": "AmazonS3",
    "keyName": "alice-file.txt",
    "bucketName": "'$BOB_BUCKET'",
    "region": "eu-central-1"
  },
  "protocol": "dataspace-protocol-http"
}'
```

You should get an output similar to this:
```bash
{
    "@type": "edc:IdResponse",
    "@id": "<TRANSFER_ID>",
    "edc:createdAt": 1710329089538,
    ...
}
```

Take note of the `<TRANSFER_ID>`. You will need it in the final step.

## Step 11: Check the EDC Data Transfer Status

During the data transfer process, Bob can check its status:
```bash
curl -k --location "https://$NLB_DNS/bob/management/v2/transferprocesses/<TRANSFER_ID>" \
--header "X-Api-Key: $API_KEY" 
```
You should get an output similar to this: 
```bash
{
    "@id": "ff2fa40c-30b9-49ad-8079-7cb484b51f58",
    "@type": "edc:TransferProcess",
    "edc:correlationId": "<TRANSFER_ID>",
    "edc:state": "COMPLETED",
    "edc:stateTimestamp": 1710329092276,
    "edc:type": "CONSUMER",
    "edc:assetId": "20",
    "edc:contractId": "<CONTRACT_AGREEMENT_ID>",
    ...
}
```

## Step 12: Inspect the Transferred File

The data transfer will complete within a few seconds. Bob can now inspect his Amazon S3 bucket and will find the transferred file, indicating that the transfer has been completed successfully. 
```bash
aws s3 ls $BOB_BUCKET
2024-04-05 16:17:57         12 alice-file.txt
```
