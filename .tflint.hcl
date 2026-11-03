# The module has never declared provider version constraints. Adding them sets the oldest provider
# versions customers can use, so that is its own change rather than a lint fix.
rule "terraform_required_providers" {
  enabled = false
}
