from clickhouse_configs import *
from clickhouse_connect.driver import create_client as create_clickhouse_client # type: ignore
from clickhouse_connect.driver.client import Client
from clickhouse_connect.driver.query import QueryResult
from query_utils import get_sqls_from_file
from typing import Dict

print(f"K8s Clickhouse Namespace: {K8s_CLICKHOUSE_NAMESPACE}")
print(f"Clickhouse Cluster Name: {CLICKHOUSE_CLUSTER_NAME}")
print(f"Clickhouse Database: {CLICKHOUSE_DATABASE}")
print(f"Dry Run: {DRY_RUN}")
print(f"Connecting to Clickhouse at {CLICKHOUSE_HOST}:{CLICKHOUSE_PORT} with username {CLICKHOUSE_USERNAME}")
clk_client: Client = create_clickhouse_client(host=CLICKHOUSE_HOST, port=CLICKHOUSE_PORT, username=CLICKHOUSE_USERNAME, password=CLICKHOUSE_PASSWORD or "")
print(f"Connected to Clickhouse at {CLICKHOUSE_HOST}:{CLICKHOUSE_PORT}")


all_parameters: Dict[str, str] = {
    "db": CLICKHOUSE_DATABASE,    
    "cluster": CLICKHOUSE_CLUSTER_NAME,
    "kafka_broker_list": KAFKA_BROKER_LIST,
    "mysql_host": MYSQL_HOST,
    "mysql_source_db": MYSQL_DATABASE,
    "mysql_username": MYSQL_USERNAME,
    "mysql_password": MYSQL_PASSWORD or "",
    "metrics_ttl_days": METRICS_TTL_DAYS,
    "logs_ttl_days": LOGS_TTL_DAYS,
}

# Check if the database exists, if not start running all sqls in the schema folder and fail if any sql fails
result: QueryResult = clk_client.query( # type: ignore
    query="SELECT 1 FROM system.databases WHERE name = {db:String}",
    parameters=all_parameters
)
schema_version: int = 0

if not result.result_rows: # type: ignore
    print(f"Database: {CLICKHOUSE_DATABASE} does not exist.")
else:
    # Read the last updated schema version from the database table divyam_version_info
    try:
        result = clk_client.query( # type: ignore
            query=f"SELECT version FROM {CLICKHOUSE_DATABASE}.divyam_version_info ORDER BY timestamp DESC LIMIT 1",
        )
        if not result.result_rows: # type: ignore
            print(f"Last updated schema version not found in divyam_version_info table in the database {CLICKHOUSE_DATABASE}.")
        else:
            schema_version = int(result.result_rows[0][0]) # type: ignore
            print(f"Last updated schema version found in divyam_version_info table in the database {CLICKHOUSE_DATABASE}: {schema_version}")
    except Exception as e:
        print(f"Last updated schema version not found in divyam_version_info table in the database {CLICKHOUSE_DATABASE}. Got exception: {e}")

print(f"Last updated schema version of the datastore is: {schema_version}")
for sql_file in sorted(os.listdir("schema")):
    sqls = get_sqls_from_file(os.path.join("schema", sql_file), all_parameters)
    for sql in sqls:
        try:
            result: QueryResult = clk_client.query(query=sql) # type: ignore
            if not result.result_rows: # type: ignore
                print(f"❌ ERROR: SQL query in file {sql_file} failed: {sql}")
                print(f"Error: {result.error_message}") # type: ignore
                exit(1)
            else:
                print(f"✅ SQL query in file {sql_file} executed successfully: {sql}")
        except Exception as e:
            print(f"❌ ERROR: SQL query in file {sql_file} failed: {sql}")
            print(f"Error: {e}")
            exit(1)
    schema_version = int(sql_file.split("_")[0])
    # Insert the new schema version into the divyam_version_info table
    clk_client.query(query=f"INSERT INTO {CLICKHOUSE_DATABASE}.divyam_version_info (version, timestamp) VALUES ('{schema_version}', now())") # type: ignore
    print(f"✅ Schema file {sql_file} executed successfully and schema version {schema_version} updated in divyam_version_info table")
print(f"✅ All schema files executed successfully.")