from typing import Dict, List
from pathlib import Path

TEMPLATE_REPLACEMENTS = {
    "{{ .Values.database }}": "db",
    "{{ .Values.clickhouse.clustername }}": "cluster",
    "{{ .Values.kafka_integration.broker_list }}": "kafka_broker_list",
    "{{ .Values.mysql_integration.host }}": "mysql_host",
    "{{ .Values.mysql_integration.source_database }}": "mysql_source_db",
    "{{ .Values.mysql_integration.username }}": "mysql_username",
    "{{ .Values.mysql_integration.password }}": "mysql_password",
    "{{ .Values.metrics_ttl_days }}": "metrics_ttl_days",
    "{{ .Values.logs_ttl_days }}": "logs_ttl_days",
}

def get_sqls_from_file(
    file_path: str,
    all_parameters: Dict[str, str]
) -> List[str]:
    """
    Reads SQL template file, replaces Helm placeholders,
    and splits into individual SQL statements.
    
    Returns:
        list_of_sql_statements
    """

    raw_sql = Path(file_path).read_text()

    # --- Replace templates ---
    for template, param_key in TEMPLATE_REPLACEMENTS.items():
        if param_key not in all_parameters:
            raise ValueError(f"Missing parameter: {param_key}")
        # Replace all occurrences of the template with the parameter value
        raw_sql = raw_sql.replace(template, str(all_parameters[param_key]))

    # --- Split on semicolon safely ---
    statements: List[str] = []
    for stmt in raw_sql.split(";"):
        # Split this in to lines and ignore the line if it starts with -- or is empty
        # For each split, create one statement and add it to the list
        statement: str = ""
        for line in stmt.split("\n"):
            if line.strip().startswith("--") or not line.strip():
                continue   
            statement += line.strip() + " "
        statement = statement.strip()
        if not statement:
            continue
        statements.append(statement + ";")
    return statements