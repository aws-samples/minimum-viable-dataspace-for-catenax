#
#  Copyright (c) 2023 Contributors to the Eclipse Foundation
#
#  See the NOTICE file(s) distributed with this work for additional
#  information regarding copyright ownership.
#
#  This program and the accompanying materials are made available under the
#  terms of the Apache License, Version 2.0 which is available at
#  https://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#  License for the specific language governing permissions and limitations
#  under the License.
#
#  SPDX-License-Identifier: Apache-2.0
#
---

################################
# EDC ControlPlane + DataPlane #
################################
participant:
  id: "test-participant"
controlplane:
  debug:
    enabled: true
    port: 1044
  livenessProbe:
    enabled: true
  readinessProbe:
    enabled: true
  service:
    type: NodePort
  endpoints:
    management:
      authKey: "EDC_AUTH_KEY"
  image:
    pullPolicy: Never
#    repository: "edc-controlplane-postgresql-hashicorp-vault"
  securityContext:
    # avoids some errors in the log: cannot write temp files of large multipart requests when R/O
    readOnlyRootFilesystem: false
  ssi:
    miw:
      url: "http://localhost:8080"
      authorityId: "authorityId"
    oauth:
      client:
        secretAlias: "client-secret"
dataplane:
  debug:
    enabled: true
    port: 1044
  livenessProbe:
    enabled: true
  readinessProbe:
    enabled: true
  image:
    pullPolicy: Never
#    repository: "edc-dataplane-hashicorp-vault"
  securityContext:
    # avoids some errors in the log: cannot write temp files of large multipart requests when R/O
    readOnlyRootFilesystem: false
  aws:
    endpointOverride: http://minio:9000
    secretAccessKey: qwerty123
    accessKeyId: qwerty123

  env:
    "EDC_API_AUTH_KEY" : "EDC_AUTH_KEY"

postgresql:
   # JDBC URL should be set from `main.tf`
   jdbcUrl:
#  jdbcUrl: jdbc:postgresql://{{ .Release.Name }}-postgresql:5432/edc
   auth:
     username:
     password:
vault:
  hashicorp:
    url: http://{{ .Release.Name }}-vault:8200
    token: root
  secretNames:
    transferProxyTokenEncryptionAesKey: aes-keys
    transferProxyTokenSignerPrivateKey: transferProxyTokenSignerPrivateKey
    transferProxyTokenSignerPublicKey: transferProxyTokenSignerPublicKey
    # this must be set through CLI args: --set vault.secrets=$YOUR_VAULT_SECRETS where YOUR_VAULT_SECRETS should
    #    # be a string in the format "key1:secret1;key2:secret2;..."
    secrets:
backendService:
  httpProxyTokenReceiverUrl: "http://backend:8080"
tests:
  hookDeletePolicy: before-hook-creation