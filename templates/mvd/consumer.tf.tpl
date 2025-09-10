#
#  Copyright (c) 2024 Metaform Systems, Inc.
#
#  This program and the accompanying materials are made available under the
#  terms of the Apache License, Version 2.0 which is available at
#  https://www.apache.org/licenses/LICENSE-2.0
#
#  SPDX-License-Identifier: Apache-2.0
#
#  Contributors:
#       Metaform Systems, Inc. - initial API and implementation
#

# This file deploys all the components needed for the consumer side of the scenario,
# i.e. the connector, an identityhub and a vault.

# consumer connector
module "consumer-connector" {
  source            = "./modules/connector"
  humanReadableName = "consumer"
  participantId     = var.consumer-did
  database = {
    user     = "postgres"
    password = "ALICE_DB_PASSWORD"
    url      = "jdbc:postgresql://ALICE_DB_ENDPOINT/alice"
  }
  vault-url     = "http://consumer-vault:8200"
  namespace     = kubernetes_namespace.ns.metadata.0.name
  sts-token-url = "${module.consumer-identityhub.sts-token-url}/token"
  useSVE        = var.useSVE
}

# consumer identity hub
module "consumer-identityhub" {
  depends_on        = [module.consumer-vault]
  source            = "./modules/identity-hub"
  credentials-dir   = dirname("./assets/credentials/k8s/consumer/")
  humanReadableName = "consumer-identityhub"
  participantId     = var.consumer-did
  vault-url         = "http://consumer-vault:8200"
  service-name      = "consumer"
  database = {
    user     = "postgres"
    password = "ALICE_DB_PASSWORD"
    url      = "jdbc:postgresql://ALICE_DB_ENDPOINT/alice"
  }
  namespace = kubernetes_namespace.ns.metadata.0.name
  useSVE    = var.useSVE
}


# consumer vault
module "consumer-vault" {
  source            = "./modules/vault"
  humanReadableName = "consumer-vault"
  namespace         = kubernetes_namespace.ns.metadata.0.name
}