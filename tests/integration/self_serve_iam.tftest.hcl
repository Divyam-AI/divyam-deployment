variables {
  env_name = "preprod"
}

run "router_only_excludes_switch" {
  command = plan
  variables {
    stack = "router"
  }
  assert {
    condition     = !contains(keys(output.service_accounts), "self-serve-server-preprod-sa")
    error_message = "Router-only plans must not create Switch identities."
  }
}

run "self_serve_identity_matches_helmfile" {
  command = plan
  variables {
    stack = "self-serve"
  }
  assert {
    condition     = output.service_accounts["self-serve-server-preprod-sa"].namespace == "self-serve-preprod-ns"
    error_message = "The server identity must bind to the Helmfile namespace."
  }
  assert {
    condition     = output.service_accounts["self-serve-ui-preprod-sa"].namespace == "self-serve-preprod-ns"
    error_message = "The UI identity must bind to the Helmfile namespace."
  }
  assert {
    condition     = output.service_accounts["self-serve-server-preprod-sa"].roles == ["secret_reader"]
    error_message = "Switch requires secret access without unrelated resource roles."
  }
}

run "mixed_stack_includes_switch" {
  command = plan
  variables {
    stack = "router, evalm8, self-serve"
  }
  assert {
    condition     = contains(keys(output.service_accounts), "self-serve-server-preprod-sa")
    error_message = "Mixed stacks containing self-serve must include its identities."
  }
}
