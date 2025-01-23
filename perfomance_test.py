import requests
import pandas as pd
import datetime
import time
from pymongo import MongoClient
import random

# MongoDB Configuration
MONGO_URI = 'mongodb://172.174.98.4:27017'
DB_NAME = 'sample_analytics'
COLLECTION_NAME = 'transactions'

# Prometheus Configuration
PROMETHEUS_URL = "http://172.174.98.4:9090/api/v1/query_range"
METRICS = [
    "mongodb_collstats_latencyStats_reads_latency",
    "mongodb_collstats_latencyStats_writes_latency"
]
PROMETHEUS_STEP = "10s"

# Time Range for Metrics
def get_time_range(start_offset=0, duration=60):
    """
    Calculate start and end times for Prometheus query.
    start_offset: Seconds before now to start.
    duration: Duration in seconds for the test.
    """
    end_time = datetime.datetime.utcnow()
    start_time = end_time - datetime.timedelta(seconds=duration + start_offset)
    return start_time.isoformat() + "Z", end_time.isoformat() + "Z"

# Function to generate write operations
def write_operations(collection, num_ops=100):
    for _ in range(num_ops):
        collection.insert_one({"key": random.randint(1, 100), "value": "test_value"})
        time.sleep(0.01)  # Simulate delay

# Function to generate read operations
def read_operations(collection, num_ops=100):
    for _ in range(num_ops):
        collection.find_one({"key": random.randint(1, 100)})
        time.sleep(0.01)  # Simulate delay

# Fetch metrics from Prometheus
def fetch_metrics(metric_name, start_time, end_time, step):
    response = requests.get(PROMETHEUS_URL, params={
        "query": metric_name,
        "start": start_time,
        "end": end_time,
        "step": step
    })
    if response.status_code == 200:
        data = response.json()
        if "data" in data and "result" in data["data"]:
            results = data["data"]["result"]
            metrics = []
            for result in results:
                if result["metric"]["database"] != DB_NAME or result["metric"]["collection"] != COLLECTION_NAME:
                    continue
                for value in result["values"]:
                    timestamp, metric_value = value
                    metrics.append({
                        "timestamp": datetime.datetime.fromtimestamp(float(timestamp)),
                        "value": float(metric_value),
                        "metric": metric_name
                    })
            return pd.DataFrame(metrics)
        else:
            print(f"No results for {metric_name}.")
            return pd.DataFrame()
    else:
        print(f"Error fetching {metric_name}: {response.status_code}")
        return pd.DataFrame()

# Main Function
if __name__ == "__main__":
    # Connect to MongoDB
    client = MongoClient(MONGO_URI)
    db = client[DB_NAME]
    collection = db[COLLECTION_NAME]

    # Calculate time range for metrics
    test_duration = 130  # Test duration in seconds
    start_time, end_time = get_time_range(duration=test_duration)

    print("Starting test...")
    # Start Write and Read Operations
    write_operations(collection, num_ops=500)
    read_operations(collection, num_ops=500)
    print("Test completed.")

    # Fetch metrics from Prometheus
    all_metrics = []
    for metric in METRICS:
        print(f"Fetching metric: {metric}")
        df = fetch_metrics(metric, start_time, end_time, PROMETHEUS_STEP)
        if not df.empty:
            all_metrics.append(df)

    # Combine all metrics into a single DataFrame
    if all_metrics:
        metrics_data = pd.concat(all_metrics, ignore_index=True)
        print(metrics_data)

        # Save metrics to CSV
        metrics_file_name = DB_NAME + "_collected_metrics.csv"
        metrics_data.to_csv(metrics_file_name, index=False)
        print("Metrics saved to " + metrics_file_name)
    else:
        print("No metrics collected.")
