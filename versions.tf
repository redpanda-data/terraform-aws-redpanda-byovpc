terraform {
  # terraform_data (network.tf) is a 1.4 builtin. Below that, operators get "the provider
  # terraform.io/builtin/terraform does not support resource type terraform_data" rather than a
  # version message. The module already required 1.2 implicitly for lifecycle preconditions.
  # The removed block in storage.tf is a 1.7 feature.
  required_version = ">= 1.7.0"
}
