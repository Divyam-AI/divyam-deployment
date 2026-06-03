# Shared alert renderer (provider-less, no resources).
#
# Turns the neutral rule schema into ready-to-map objects for each backend:
#   - prometheus_rules : flat list, multi-tier expanded (warning + critical), {{threshold}} substituted
#   - datadog_monitors : map keyed by alert, with the rendered Datadog query string
#
# Query authoring is hybrid (see ../rules/README.md):
#   - structured `query` IR  -> both PromQL + Datadog query are rendered here, via metric_map
#   - template (`expr` / `datadog.query`) -> placeholders substituted, used as-is
#
# Datadog metric names + filter values are normalized (lowercase, '-' -> '_') at emit time.

locals {
  metric_map = jsondecode(file(var.metric_map_file))

  # Datadog scope cluster value. Datadog lowercases tag values but PRESERVES hyphens (minuses are
  # an allowed tag-value character), so we lowercase only — do NOT convert '-' to '_' here, or a
  # cluster like `divyam-prod` would render `divyam_prod` and match zero series. (Metric NAMES, by
  # contrast, cannot contain hyphens and are converted below.) PromQL paths keep the raw value
  # (Prometheus label matching is case-sensitive and exact).
  dd_cluster = lower(var.cluster_name)

  # Rule groups = every *.json except the metric catalog.
  rule_files = [for f in fileset(var.rules_folder, "*.json") : f if f != "metric_map.json"]
  groups = {
    for f in local.rule_files :
    trimsuffix(basename(f), ".json") => jsondecode(file("${var.rules_folder}/${f}"))
  }

  # Flatten groups -> rules; attach group metadata; merge group labels under rule labels;
  # filter excluded alerts.
  rules = flatten([
    for gname, g in local.groups : [
      for r in g.rules : merge(r, {
        _group_name     = gname              # file basename ("k8s") — stable for_each key
        _group_title    = try(g.name, gname) # JSON `name` ("kubernetes") — resource name attribute
        _group_desc     = try(g.description, try(g.name, gname))
        _group_interval = g.interval
        _group_enabled  = try(g.enabled, true)
        _labels         = merge(try(g.labels, {}), try(r.labels, {}))
      }) if !contains(var.exclude_list, try(r.alert, ""))
    ]
  ])

  # ---- Per-rule scalars -----------------------------------------------------
  window     = { for r in local.rules : r.alert => try(r.window, var.default_window) }
  comparison = { for r in local.rules : r.alert => try(r.query.comparison, ">") }
  scale      = { for r in local.rules : r.alert => try(r.query.scale, 1) }
  is_struct  = { for r in local.rules : r.alert => try(r.query, null) != null }
  thr_crit   = { for r in local.rules : r.alert => try(tostring(r.thresholds.critical), null) }
  thr_warn   = { for r in local.rules : r.alert => try(tostring(r.thresholds.warning), null) }
  has_warn   = { for r in local.rules : r.alert => try(r.thresholds.warning, null) != null && try(r.thresholds.critical, null) != null }

  # Datadog inlines the critical value into the query string. A per-rule datadog.thresholds
  # override wins over the neutral threshold (e.g. pvc-usage-high pages at 80 on Datadog but
  # alerts at 60 on Prometheus).
  dd_crit = { for r in local.rules : r.alert => coalesce(try(tostring(r.datadog.thresholds.critical), null), local.thr_crit[r.alert], "0") }

  # ---- PromQL term rendering (structured rules) -----------------------------
  # A term renders to `metric{k='v',...}` (raw values; PromQL is case-sensitive).
  prom_num = {
    for r in local.rules : r.alert => [
      for t in try(r.query.terms, []) :
      "${try(local.metric_map[t.metric].prometheus, t.metric)}${length(try(t.filters, {})) > 0 ? "{${join(",", [for k, v in t.filters : "${k}='${v}'"])}}" : ""}"
    ] if local.is_struct[r.alert]
  }
  prom_den = {
    for r in local.rules : r.alert => [
      for t in try(r.query.denominator, []) :
      "${try(local.metric_map[t.metric].prometheus, t.metric)}${length(try(t.filters, {})) > 0 ? "{${join(",", [for k, v in t.filters : "${k}='${v}'"])}}" : ""}"
    ] if local.is_struct[r.alert]
  }

  # ---- Datadog term rendering (structured rules) ----------------------------
  # A term renders to `<agg>:<metric>{kube_cluster_name:<c>,k:v,...} by {g1,g2}`.
  # metric name + filter values normalized (lowercase, '-' -> '_').
  dd_num = {
    for r in local.rules : r.alert => [
      for t in try(r.query.terms, []) :
      "${try(r.query.aggregation, "avg")}:${replace(lower(try(local.metric_map[t.metric].datadog, t.metric)), "-", "_")}{${join(",", concat(local.dd_cluster != "" ? ["kube_cluster_name:${local.dd_cluster}"] : [], [for k, v in try(t.filters, {}) : "${k}:${lower(tostring(v))}"]))}}${length(try(r.query.group_by, [])) > 0 ? " by {${join(",", r.query.group_by)}}" : ""}"
    ] if local.is_struct[r.alert]
  }
  dd_den = {
    for r in local.rules : r.alert => [
      for t in try(r.query.denominator, []) :
      "${try(r.query.aggregation, "avg")}:${replace(lower(try(local.metric_map[t.metric].datadog, t.metric)), "-", "_")}{${join(",", concat(local.dd_cluster != "" ? ["kube_cluster_name:${local.dd_cluster}"] : [], [for k, v in try(t.filters, {}) : "${k}:${lower(tostring(v))}"]))}}${length(try(r.query.group_by, [])) > 0 ? " by {${join(",", r.query.group_by)}}" : ""}"
    ] if local.is_struct[r.alert]
  }

  # ---- Combine terms -> numerator / denominator / body ----------------------
  # Multiple terms combine with " + " (combine: sum). min/max combine is not modelled
  # in structured mode — use a template rule for those shapes.
  prom_num_str = { for a, terms in local.prom_num : a => length(terms) > 1 ? "(${join(" + ", terms)})" : terms[0] }
  prom_den_str = { for a, terms in local.prom_den : a => length(terms) > 1 ? "(${join(" + ", terms)})" : (length(terms) == 1 ? terms[0] : "") }
  dd_num_str   = { for a, terms in local.dd_num : a => length(terms) > 1 ? "(${join(" + ", terms)})" : terms[0] }
  dd_den_str   = { for a, terms in local.dd_den : a => length(terms) > 1 ? "(${join(" + ", terms)})" : (length(terms) == 1 ? terms[0] : "") }

  # PromQL wraps the body in parens (matches the established rule style); Datadog does not
  # parenthesize a bare single-term query.
  prom_body = {
    for r in local.rules : r.alert => (
      local.prom_den_str[r.alert] != "" ? "(${local.prom_num_str[r.alert]} / ${local.prom_den_str[r.alert]})" : "(${local.prom_num_str[r.alert]})"
    ) if local.is_struct[r.alert]
  }
  dd_body = {
    for r in local.rules : r.alert => (
      local.dd_den_str[r.alert] != "" ? "(${local.dd_num_str[r.alert]} / ${local.dd_den_str[r.alert]})" : local.dd_num_str[r.alert]
    ) if local.is_struct[r.alert]
  }

  # Body is already parenthesized (ratio or single-term PromQL), so scaling needs no extra parens.
  prom_body_scaled = { for a, b in local.prom_body : a => local.scale[a] != 1 ? "${b} * ${local.scale[a]}" : b }
  dd_body_scaled   = { for a, b in local.dd_body : a => local.scale[a] != 1 ? "${b} * ${local.scale[a]}" : b }

  # ---- PromQL expr template (with {{threshold}} placeholder retained) -------
  # Structured: built body + comparison + placeholder. Template: rule's expr verbatim.
  # Globals ({{cluster_name}}, {{env}}) substituted now; {{threshold}} left for tier expansion.
  expr_tmpl = {
    for r in local.rules : r.alert => replace(replace(
      local.is_struct[r.alert] ? "${local.prom_body_scaled[r.alert]} ${local.comparison[r.alert]} {{threshold}}" : try(r.expr, ""),
    "{{cluster_name}}", var.cluster_name), "{{env}}", var.env)
  }

  # ---- Datadog query (threshold inlined as critical; no tier expansion) -----
  dd_query = {
    for r in local.rules : r.alert => (
      local.is_struct[r.alert]
      ? "${try(r.query.rollup, "min")}(last_${local.window[r.alert]}):${local.dd_body_scaled[r.alert]} ${local.comparison[r.alert]} ${local.dd_crit[r.alert]}"
      : try(replace(replace(replace(replace(r.datadog.query,
        "{{cluster_name}}", local.dd_cluster),
        "{{env}}", var.env),
        "{{window}}", local.window[r.alert]),
      "{{threshold}}", local.dd_crit[r.alert]), null)
    )
  }

  # ---- Common per-rule metadata shared by all backends ----------------------
  common = {
    for r in local.rules : r.alert => {
      labels            = r._labels
      summary           = try(r.annotations.summary, r.alert)
      description       = try(r.annotations.description, "")
      runbook_url       = try(r.annotations.runbook_url, null)
      dashboard_url     = try(r.annotations.dashboard_url, null)
      auto_resolve      = try(r.auto_resolve, null)
      enabled           = try(r.enabled, true)
      group_enabled     = r._group_enabled
      interval          = r._group_interval
      for               = r.for
      group_name        = r._group_name
      group_title       = r._group_title
      group_description = r._group_desc
      # Neutral paging override only (pages on EVERY backend). The legacy datadog.notify is a
      # Datadog-only override and is applied in the datadog module — it must NOT leak into the
      # GCP/Azure paging decision, which read this field.
      notify            = try(r.notification.notify, false)
      renotify_interval = try(r.notification.renotify_interval, null)
      # Optional per-rule GCP channel override (gcp.notification_channels); null => use module default.
      gcp_notification_channels = try(r.gcp.notification_channels, null)
    }
  }

  # ---- Prometheus output: multi-tier expansion ------------------------------
  # Primary tier (critical threshold) is always emitted; a warning tier is appended only when
  # the rule declares both neutral thresholds. range(0|1) keeps both branches list-typed so the
  # ternary unifies (tuples of differing length do not).
  prom_expanded = flatten([
    for r in local.rules : concat(
      [
        merge(local.common[r.alert], {
          alert    = r.alert
          expr     = local.thr_crit[r.alert] != null ? replace(local.expr_tmpl[r.alert], "{{threshold}}", local.thr_crit[r.alert]) : local.expr_tmpl[r.alert]
          severity = try(r.severity, "CRITICAL")
        })
      ],
      [
        for _ in range(local.has_warn[r.alert] ? 1 : 0) :
        merge(local.common[r.alert], {
          alert    = "${r.alert}-warning"
          expr     = replace(local.expr_tmpl[r.alert], "{{threshold}}", local.thr_warn[r.alert])
          severity = "WARNING"
          notify   = false
        })
      ]
    )
  ])

  # ---- Datadog output: one monitor per rule that yields a query -------------
  dd_monitors = {
    for r in local.rules : r.alert => merge(r, local.common[r.alert], {
      query    = local.dd_query[r.alert]
      severity = try(r.severity, "CRITICAL")
    })
    if local.dd_query[r.alert] != null && local.dd_query[r.alert] != ""
  }
}
