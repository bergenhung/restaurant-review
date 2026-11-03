output "url" {
  value = google_cloud_run_v2_service.app.uri
}

output "runtime_service_account" {
  value = google_service_account.runtime.email
}

output "build_service_account" {
  value = google_service_account.build.email
}
