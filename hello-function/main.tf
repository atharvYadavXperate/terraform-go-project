variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "function_name" {
  type = string
}

variable "service_account_email"{
  type  = string
}
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "function_bucket" {
  name          = "${var.project_id}-${var.function_name}-${random_id.suffix.hex}"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_object" "function_archive" {
  name   = "function.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "function.zip" 
}

resource "google_cloudfunctions2_function" "hello_function" {
  name     = "${var.function_name}-${random_id.suffix.hex}"
  location = var.region

  build_config {
    runtime     = "go122"
    entry_point = "HelloWorld"
    service_account_email = var.service_account_email
    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.function_archive.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = "256M"
    ingress_settings      = "ALLOW_ALL"
    timeout_seconds       = 60
  }
}


resource "google_cloud_run_service_iam_member" "public_invoker" {
  location = var.region
  service  = google_cloudfunctions2_function.hello_function.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "function_url" {
  value = google_cloudfunctions2_function.hello_function.service_config[0].uri
}