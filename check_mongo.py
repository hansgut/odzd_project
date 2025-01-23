from pymongo import MongoClient

def list_databases_and_collections():
    try:
        # Connect to the MongoDB server on localhost
        client = MongoClient("mongodb://172.174.98.4:27017/")

        # Retrieve all databases
        databases = client.list_database_names()
        print("Databases and their collections:")

        for db_name in databases:
            print(f"\nDatabase: {db_name}")

            # Access the database
            db = client[db_name]

            # Retrieve all collections in the database
            collections = db.list_collection_names()
            if collections:
                for collection_name in collections:
                    print(f"  - Collection: {collection_name}")
            else:
                print("  (No collections found)")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    list_databases_and_collections()
