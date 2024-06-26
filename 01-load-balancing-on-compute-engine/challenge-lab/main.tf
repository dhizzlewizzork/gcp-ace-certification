# Prerequisites.  Build a network
#
resource "google_compute_network" "this" {
  project = var.project_id

  name                    = "nucleus-vpc"
  auto_create_subnetworks = true
}

# Task 1. Create a project jumphost instance
#
resource "google_compute_instance" "this" {
  project = var.project_id

  name         = var.instance_name
  zone         = var.zone
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  network_interface {
    network = google_compute_network.this.self_link
  }
}

# Task 2. Set up an HTTP load balancer
#
resource "google_compute_instance_template" "this" {
  project = var.project_id

  name         = "web-server-template"
  description  = "Instance template for web server"
  machine_type = "e2-micro"

  metadata_startup_script = file("startup.sh")

  disk {
    source_image = "debian-cloud/debian-12"
  }

  network_interface {
    network = google_compute_network.this.self_link

    access_config {
      network_tier = "PREMIUM"
    }
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  tags = ["allow-health-check"]
}

resource "google_compute_instance_group_manager" "this" {
  project = var.project_id

  name               = "web-server-group"
  base_instance_name = "web-server"
  zone               = var.zone

  target_size = 2

  version {
    instance_template = google_compute_instance_template.this.self_link
  }

  named_port {
    name = "http"
    port = 80
  }

  lifecycle {
    replace_triggered_by = [
      google_compute_instance_template.this.self_link
    ]
  }
}

resource "google_compute_firewall" "this" {
  project = var.project_id

  name      = var.firewall_rule_name
  network   = google_compute_network.this.self_link
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [80]
  }

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]

  target_tags = google_compute_instance_template.this.tags
}

resource "google_compute_health_check" "this" {
  project = var.project_id

  name = "http-health-check"

  timeout_sec         = 5
  check_interval_sec  = 5
  unhealthy_threshold = 2

  http_health_check {
    port_specification = "USE_NAMED_PORT"
    port_name          = "http"
  }
}

resource "google_compute_backend_service" "this" {
  project = var.project_id

  name      = "web-server-backend"
  protocol  = "HTTP"
  port_name = "http"

  load_balancing_scheme = "EXTERNAL_MANAGED"

  health_checks = [
    google_compute_health_check.this.self_link
  ]

  backend {
    group           = google_compute_instance_group_manager.this.instance_group
    # balancing_mode  = "UTILIZATION"
    # capacity_scaler = 1.0
  }

  lifecycle {
    replace_triggered_by = [
      google_compute_health_check.this.self_link,
      google_compute_instance_group_manager.this.instance_group
    ]
  }
}

resource "google_compute_url_map" "this" {
  project = var.project_id

  name            = "web-server-map"
  default_service = google_compute_backend_service.this.self_link

  lifecycle {
    replace_triggered_by = [
      google_compute_backend_service.this.self_link
    ]
  }
}

resource "google_compute_target_http_proxy" "this" {
  project = var.project_id

  name    = "http-lb-proxy"
  url_map = google_compute_url_map.this.self_link

  lifecycle {
    replace_triggered_by = [
      google_compute_url_map.this.self_link
    ]
  }
}

resource "google_compute_global_forwarding_rule" "this" {
  project = var.project_id

  name = "http-content-rule"

  load_balancing_scheme = "EXTERNAL_MANAGED"

  ip_protocol = "TCP"
  port_range  = "80"
  target      = google_compute_target_http_proxy.this.self_link

  lifecycle {
    replace_triggered_by = [
      google_compute_target_http_proxy.this.self_link
    ]
  }
}