// GitHub - https://github.com/hashicorp-education/learn-terraform-dynamic-credentials/tree/main

//////////////////////////////
// HCP
//////////////////////////////
data "external" "env" {
  program = ["${path.module}/env.sh"]
}

provider "hcp" {
  client_id     = data.external.env.result["client_id"]
  client_secret = data.external.env.result["client_secret"]
}

data "hcp_vault_cluster" "gs" {
  project_id = var.hcp_vault_cluster_project_id
  cluster_id = var.hcp_vault_cluster_cluster_id
}

//////////////////////////////
// Vault
//////////////////////////////
provider "vault" {
  address   = data.hcp_vault_cluster.gs.vault_public_endpoint_url
  namespace = "admin"
  // auth_login {
  //   path      = "auth/userpass/login/admin"
  //   namespace = "admin"
  //   parameters = {
  //     password = var.login_password
  //   }
  // }
  // token = "hvs.CAESIFx0iKqMr7Kn8WeDKFPAlmnD9puGipHqGyZ8J86z9BlhGikKImh2cy45RlVSVHB2TFZEeHBmbjFZMnd5VWMzU1AuQjRxQVgQl7jSAQ"
}

resource "vault_jwt_auth_backend" "tf" {
  description        = "Demonstration of the Terraform JWT auth backend"
  path               = "jwt"
  oidc_discovery_url = "https://app.terraform.io"
  bound_issuer       = "https://app.terraform.io"
}

resource "vault_policy" "tf" {
  name = "tfc-policy"

  policy = <<EOT
# Allow tokens to query themselves
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Allow tokens to renew themselves
path "auth/token/renew-self" {
    capabilities = ["update"]
}

# Allow tokens to revoke themselves
path "auth/token/revoke-self" {
    capabilities = ["update"]
}

# Configure the actual secrets the token should have access to
path "secret/*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_jwt_auth_backend_role" "example" {
  backend        = vault_jwt_auth_backend.tf.path
  role_name      = "tfc-role"
  token_policies = ["tfc-policy"]

  bound_audiences   = ["vault.workload.identity"]
  bound_claims_type = "glob"
  bound_claims = {
    sub = "organization:*:project:*:workspace:*:run_phase:*"
  }
  user_claim = "terraform_full_workspace"
  role_type  = "jwt"
  token_ttl  = 20 * 60
}

//////////////////////////////
// AWS
//////////////////////////////
provider "aws" {
  region = var.aws_region
}

data "tls_certificate" "tfc_certificate" {
  url = "https://${var.tfc_hostname}"
}

resource "aws_iam_openid_connect_provider" "tfc_provider" {
  url             = data.tls_certificate.tfc_certificate.url
  client_id_list  = [var.tfc_aws_audience]
  thumbprint_list = [data.tls_certificate.tfc_certificate.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "tfc_role" {
  name = "tfc-role"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Principal": {
       "Federated": "${aws_iam_openid_connect_provider.tfc_provider.arn}"
     },
     "Action": "sts:AssumeRoleWithWebIdentity",
     "Condition": {
       "StringEquals": {
         "${var.tfc_hostname}:aud": "${one(aws_iam_openid_connect_provider.tfc_provider.client_id_list)}"
       },
       "StringLike": {
         "${var.tfc_hostname}:sub": "organization:${var.tfc_organization_name}:project:*:workspace:*:run_phase:*"
       }
     }
   }
 ]
}
EOF
}

resource "aws_iam_policy" "tfc_policy" {
  name        = "tfc-policy"
  description = "TFC run policy"

  policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Action": [
       "s3:ListBucket"
     ],
     "Resource": "*"
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "tfc_policy_attachment" {
  role       = aws_iam_role.tfc_role.name
  policy_arn = aws_iam_policy.tfc_policy.arn
}

//////////////////////////////
// Azure
//////////////////////////////
// provider "azurerm" {
//   features {}
// }

// provider "azuread" {}

// data "azurerm_subscription" "current" {}

// resource "azuread_application" "tfc_application" {
//   display_name = "tfc-application"
// }

// resource "azuread_service_principal" "tfc_service_principal" {
//   application_id = azuread_application.tfc_application.application_id
// }

// resource "azuread_application_federated_identity_credential" "tfc_federated_credential_plan" {
//   application_object_id = azuread_application.tfc_application.object_id
//   display_name          = "my-tfc-federated-credential-plan"
//   audiences             = [var.tfc_azure_audience]
//   issuer                = "https://${var.tfc_hostname}"
//   subject               = "organization:${var.tfc_organization_name}:project:${var.tfc_project_name}:workspace:azure-dynamic:run_phase:plan"
// }

// resource "azuread_application_federated_identity_credential" "tfc_federated_credential_apply" {
//   application_object_id = azuread_application.tfc_application.object_id
//   display_name          = "my-tfc-federated-credential-apply"
//   audiences             = [var.tfc_azure_audience]
//   issuer                = "https://${var.tfc_hostname}"
//   subject               = "organization:${var.tfc_organization_name}:project:${var.tfc_project_name}:workspace:azure-dynamic:run_phase:apply"
// }

// resource "azurerm_role_assignment" "tfc_role_assignment" {
//   scope                = data.azurerm_subscription.current.id
//   principal_id         = azuread_service_principal.tfc_service_principal.object_id
//   role_definition_name = "Contributor"
// }

//////////////////////////////
// GCP
//////////////////////////////
// provider "google" {
//   project = "vault-366703"
//   region  = "asia-northeast3"
// }

// data "google_project" "project" {}

// locals {
//   gcp_service_list = [
//     "serviceusage.googleapis.com",
//     "iam.googleapis.com",
//     "cloudresourcemanager.googleapis.com",
//     "sts.googleapis.com",
//     "iamcredentials.googleapis.com"
//   ]
// }

// resource "google_project_service" "services" {
//   count = length(local.gcp_service_list)
//   // project = data.google_project.project.id
//   service = local.gcp_service_list[count.index]
//   disable_dependent_services=true
// }

// resource "google_iam_workload_identity_pool" "tfc_pool" {
//   depends_on = [google_project_service.services]
//   workload_identity_pool_id = "my-tfc-pool"
// }

// resource "google_iam_workload_identity_pool_provider" "tfc_provider" {
//   depends_on = [google_project_service.services]
//   workload_identity_pool_id          = google_iam_workload_identity_pool.tfc_pool.workload_identity_pool_id
//   workload_identity_pool_provider_id = "my-tfc-provider-id"

//   attribute_mapping = {
//     "google.subject"                        = "assertion.sub",
//     "attribute.aud"                         = "assertion.aud",
//     "attribute.terraform_run_phase"         = "assertion.terraform_run_phase",
//     "attribute.terraform_project_id"        = "assertion.terraform_project_id",
//     "attribute.terraform_project_name"      = "assertion.terraform_project_name",
//     "attribute.terraform_workspace_id"      = "assertion.terraform_workspace_id",
//     "attribute.terraform_workspace_name"    = "assertion.terraform_workspace_name",
//     "attribute.terraform_organization_id"   = "assertion.terraform_organization_id",
//     "attribute.terraform_organization_name" = "assertion.terraform_organization_name",
//     "attribute.terraform_run_id"            = "assertion.terraform_run_id",
//     "attribute.terraform_full_workspace"    = "assertion.terraform_full_workspace",
//   }
//   oidc {
//     issuer_uri = "https://${var.tfc_hostname}"
//     # allowed_audiences = [var.tfc_gcp_audience]
//   }
//   attribute_condition = "assertion.sub.startsWith(\"organization:${var.tfc_organization_name}:project:${var.tfc_project_name}:workspace:gcp-dynamic\")"
// }

// resource "google_service_account" "tfc_service_account" {
//   depends_on = [google_project_service.services]
//   account_id   = "tfc-service-account"
//   display_name = "Terraform Cloud Service Account"
// }

// resource "google_service_account_iam_member" "tfc_service_account_member" {
//   service_account_id = google_service_account.tfc_service_account.name
//   role               = "roles/iam.workloadIdentityUser"
//   member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.tfc_pool.name}/*"
// }

// resource "google_project_iam_member" "tfc_project_member" {
//   project = data.google_project.project.id
//   role    = "roles/editor"
//   member  = "serviceAccount:${google_service_account.tfc_service_account.email}"
// }

//////////////////////////////
// TFC
//////////////////////////////
provider "tfe" {
  hostname = "app.terraform.io"
  // token    = var.token
}

resource "tfe_organization" "dynamic" {
  name  = var.tfc_organization_name
  email = "hahohh@gmail.com"
}

locals {
  provider = {
    vault = {
      TFC_VAULT_PROVIDER_AUTH = "true"
      TFC_VAULT_ADDR          = data.hcp_vault_cluster.gs.vault_public_endpoint_url
      TFC_VAULT_RUN_ROLE      = "tfc-role"
      TFC_VAULT_NAMESPACE     = var.vault_namespace
      TFC_VAULT_AUTH_PATH     = "jwt"
    }
    aws = {
      TFC_AWS_PROVIDER_AUTH = "true"
      TFC_AWS_RUN_ROLE_ARN  = aws_iam_role.tfc_role.arn
      // TFC_AWS_WORKLOAD_IDENTITY_AUDIENCE = var.tfc_aws_audience
    }
    // azure = {
    //   TFC_AZURE_PROVIDER_AUTH = "true"
    //   TFC_AZURE_RUN_CLIENT_ID = azuread_application.tfc_application.application_id
    //   // TFC_AZURE_WORKLOAD_IDENTITY_AUDIENCE = var.tfc_azure_audience
    //   ARM_SUBSCRIPTION_ID = data.azurerm_subscription.current.subscription_id
    //   ARM_TENANT_ID       = data.azurerm_subscription.current.tenant_id
    // }
    // gcp = {
    //   TFC_GCP_PROVIDER_AUTH             = "true"
    //   TFC_GCP_PROJECT_NUMBER            = data.google_project.project.number
    //   TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL = google_service_account.tfc_service_account.email
    //   TFC_GCP_WORKLOAD_POOL_ID          = google_iam_workload_identity_pool.tfc_pool.workload_identity_pool_id
    //   TFC_GCP_WORKLOAD_PROVIDER_ID      = google_iam_workload_identity_pool_provider.tfc_provider.workload_identity_pool_provider_id
    // }
  }
}

resource "tfe_workspace" "ws" {
  for_each     = toset(keys(local.provider))
  name         = "${each.key}-dynamic"
  organization = tfe_organization.dynamic.name
  tag_names    = ["${each.key}", "dynamic"]
  force_delete = true
}

resource "tfe_variable" "vault" {
  for_each     = local.provider.vault
  key          = each.key
  value        = each.value
  category     = "env"
  workspace_id = tfe_workspace.ws["vault"].id
}

resource "tfe_variable" "aws" {
  for_each     = local.provider.aws
  key          = each.key
  value        = each.value
  category     = "env"
  workspace_id = tfe_workspace.ws["aws"].id
}

// resource "tfe_variable" "azure" {
//   for_each     = local.provider.azure
//   key          = each.key
//   value        = each.value
//   category     = "env"
//   workspace_id = tfe_workspace.ws["azure"].id
// }

// resource "tfe_variable" "gcp" {
//   for_each     = local.provider.gcp
//   key          = each.key
//   value        = each.value
//   category     = "env"
//   workspace_id = tfe_workspace.ws["gcp"].id
// }

//////////////////////////////
// TF_TEST_CONFIG
//////////////////////////////
resource "local_file" "aws" {
  content = templatefile("${path.module}/template/aws.tftpl", {
    tfc_hostname          = var.tfc_hostname
    tfc_organization_name = var.tfc_organization_name
    tfc_workspace_tag     = "aws"
    aws_region            = var.aws_region
  })
  filename = "${path.module}/aws_test/main.tf"
}

// resource "local_file" "azure" {
//   content = templatefile("${path.module}/template/azure.tftpl", {
//     tfc_hostname          = var.tfc_hostname
//     tfc_organization_name = var.tfc_organization_name
//     tfc_workspace_tag     = "azure"
//   })
//   filename = "${path.module}/azure_test/main.tf"
// }

// resource "local_file" "gcp" {
//   content = templatefile("${path.module}/template/gcp.tftpl", {
//     tfc_hostname          = var.tfc_hostname
//     tfc_organization_name = var.tfc_organization_name
//     tfc_workspace_tag     = "gcp"
//     gcp_region            = var.gcp_region
//     gcp_project           = var.gcp_project
//   })
//   filename = "${path.module}/gcp_test/main.tf"
// }

resource "local_file" "vault" {
  content = templatefile("${path.module}/template/vault.tftpl", {
    tfc_hostname          = var.tfc_hostname
    tfc_organization_name = var.tfc_organization_name
    tfc_workspace_tag     = "vault"

    vault_address   = data.hcp_vault_cluster.gs.vault_public_endpoint_url
    vault_namespace = var.vault_namespace
  })
  filename = "${path.module}/vault_test/main.tf"
}