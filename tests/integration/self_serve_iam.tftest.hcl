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
    # tolist, not a bare literal: merge() unifies the role lists across stacks to list(string),
    # and a tuple literal never equals that however identical the elements are.
    condition     = output.service_accounts["self-serve-server-preprod-sa"].roles == tolist(["secret_reader", "selectors_blob_reader"])
    error_message = "Switch requires secret access and the selector bundle store, without unrelated resource roles."
  }
}

# The selector bundle store is the switch server's alone. The UI never reads a bundle, and a
# router-only deployment has no reader at all, so a regression that widens either is caught here
# rather than at apply time as an unexplained bucket binding.
run "selector_store_reader_is_scoped" {
  command = plan
  variables {
    stack = "self-serve"
  }
  assert {
    # join, not a list compare: a for expression yields a tuple and the roles are list(string).
    condition     = join(",", [for name, sa in output.service_accounts : name if contains(sa.roles, "selectors_blob_reader")]) == "self-serve-server-preprod-sa"
    error_message = "Only the switch server may read the selector bundle store."
  }
}

run "router_only_has_no_selector_store_reader" {
  command = plan
  variables {
    stack = "router"
  }
  assert {
    condition     = length([for name, sa in output.service_accounts : name if contains(sa.roles, "selectors_blob_reader")]) == 0
    error_message = "A router-only deployment must not grant the selector bundle store to anything."
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
