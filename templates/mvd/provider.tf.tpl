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


# This file deploys all the components needed for the provider side of the scenario,
# i.e. a catalog server ("bob"), two connectors ("ted" and "carol") as well as one identityhub and one vault

# first provider connector "provider-qna"
module "provider-qna-connector" {
  source            = "./modules/connector"
  humanReadableName = "provider-qna"
  participantId     = var.provider-did
  database = {
    user     = "postgres"
    password = "BOB_DB_PASSWORD"
    url      = "jdbc:postgresql://BOB_DB_ENDPOINT/qna"
  }
  namespace     = kubernetes_namespace.ns.metadata.0.name
  vault-url     = "http://provider-vault:8200"
  sts-token-url = "${module.provider-identityhub.sts-token-url}/token"
  useSVE        = var.useSVE
}

# Second provider connector "provider-manufacturing"
module "provider-manufacturing-connector" {
  source            = "./modules/connector"
  humanReadableName = "provider-manufacturing"
  participantId     = var.provider-did
  database = {
    user     = "postgres"
    password = "BOB_DB_PASSWORD"
    url      = "jdbc:postgresql://BOB_DB_ENDPOINT/manufacturing"
  }
  namespace     = kubernetes_namespace.ns.metadata.0.name
  vault-url     = "http://provider-vault:8200"
  sts-token-url = "${module.provider-identityhub.sts-token-url}/token"
  useSVE        = var.useSVE
}

module "provider-identityhub" {
  depends_on        = [module.provider-vault]
  source            = "./modules/identity-hub"
  credentials-dir   = dirname("./assets/credentials/k8s/provider/")
  humanReadableName = "provider-identityhub"
  # must be named "provider-identityhub" until we regenerate DIDs and credentials
  participantId = var.provider-did
  vault-url     = "http://provider-vault:8200"
  service-name  = "provider"
  namespace     = kubernetes_namespace.ns.metadata.0.name

  database = {
    user     = "postgres"
    password = "BOB_DB_PASSWORD"
    url      = "jdbc:postgresql://BOB_DB_ENDPOINT/identity"
  }
  useSVE = var.useSVE
}

# Catalog server runtime
module "provider-catalog-server" {
  source            = "./modules/catalog-server"
  humanReadableName = "provider-catalog-server"
  participantId     = var.provider-did
  namespace         = kubernetes_namespace.ns.metadata.0.name
  vault-url         = "http://provider-vault:8200"
  sts-token-url     = "${module.provider-identityhub.sts-token-url}/token"

  database = {
    user     = "postgres"
    password = "BOB_DB_PASSWORD"
    url      = "jdbc:postgresql://BOB_DB_ENDPOINT/bob"
  }
  useSVE = var.useSVE
}

module "provider-vault" {
  source            = "./modules/vault"
  humanReadableName = "provider-vault"
  namespace         = kubernetes_namespace.ns.metadata.0.name
}