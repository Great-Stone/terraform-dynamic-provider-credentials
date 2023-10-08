output "debug" {
  value = {
    vault_url                      = data.hcp_vault_cluster.gs.public_endpoint ? data.hcp_vault_cluster.gs.vault_public_endpoint_url : ""
    // azuread_plan_openid_claims     = azuread_application_federated_identity_credential.tfc_federated_credential_plan.subject
    // azuread_apply_openid_claims    = azuread_application_federated_identity_credential.tfc_federated_credential_apply.subject
    // azurerm_subscription_id        = data.azurerm_subscription.current.subscription_id
    // azurerm_tenant_id              = data.azurerm_subscription.current.tenant_id
    // azuread_run_client_id          = azuread_application.tfc_application.application_id
    // gcp_openid_claims              = google_iam_workload_identity_pool_provider.tfc_provider.attribute_condition
    // gcp_service_account_email      = google_service_account.tfc_service_account.email
    // gcp_project_id                 = trimprefix(data.google_project.project.id, "projects/")
    // gcp_project_number             = data.google_project.project.number
    // gcp_workload_pool_id           = google_iam_workload_identity_pool.tfc_pool.workload_identity_pool_id
    // gcp_workload_provider_id       = google_iam_workload_identity_pool_provider.tfc_provider.workload_identity_pool_provider_id
    // gcp_workload_identity_audience = one(google_iam_workload_identity_pool_provider.tfc_provider.oidc).allowed_audiences
  }
}