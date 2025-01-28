#!/usr/bin/python

from ansible.module_utils.basic import AnsibleModule
from pymongo import MongoClient
from pymongo.errors import PyMongoError
import json
import os

DOCUMENTATION = r'''
---
module: mongodb_import_json
short_description: Import a JSON file into a MongoDB collection
version_added: "1.0.0"
description:
    - This module imports a JSON file into a specified MongoDB collection.
    - It supports both single-document JSON and arrays of documents.
options:
    login_host:
        description:
            - The MongoDB server hostname or IP address.
        required: true
        type: str
    login_port:
        description:
            - The MongoDB server port number.
        required: true
        type: int
    login_user:
        description:
            - The username for MongoDB authentication.
        required: true
        type: str
    login_password:
        description:
            - The password for MongoDB authentication.
        required: true
        type: str
    login_database:
        description:
            - The database to authenticate against.
        required: true
        type: str
    collection_name:
        description:
            - The name of the MongoDB collection to import data into.
        required: true
        type: str
    file_path:
        description:
            - The path to the JSON file to be imported.
        required: true
        type: str
author:
    - Your Name (@yourgithubhandle)
'''

EXAMPLES = r'''
- name: Import JSON file into MongoDB collection
  mongodb_import_json:
    login_host: "localhost"
    login_port: 27017
    login_user: "admin"
    login_password: "password"
    login_database: "mydb"
    collection_name: "mycollection"
    file_path: "/path/to/mydata.json"
'''

RETURN = r'''
inserted_ids:
    description: List of IDs of the inserted documents.
    returned: when successful
    type: list
    sample: ["61d3e953f7e5b3ab3d5f47a1", "61d3e953f7e5b3ab3d5f47a2"]
message:
    description: A message describing the result of the operation.
    returned: always
    type: str
    sample: "Successfully imported data into mycollection"
'''

#!/usr/bin/python

from ansible.module_utils.basic import AnsibleModule
from pymongo import MongoClient
from pymongo.errors import PyMongoError
import json
import os


def import_json(params):
    """Import a JSON file into a MongoDB collection."""
    try:
        # Check if file exists
        if not os.path.exists(params['file_path']):
            return {"failed": True, "msg": f"File not found: {params['file_path']}"}

        # Read JSON file
        with open(params['file_path'], 'r') as file:
            json_data = json.load(file)

        # Connect to MongoDB
        client = MongoClient(
            host=params['login_host'],
            port=params['login_port'],
            username=params['login_user'],
            password=params['login_password'],
            authSource=params['login_database']
        )
        db = client[params['login_database']]
        collection = db[params['collection_name']]

        # Insert data into collection
        if isinstance(json_data, list):
            result = collection.insert_many(json_data)
            inserted_ids = [str(_id) for _id in result.inserted_ids]
        else:
            result = collection.insert_one(json_data)
            inserted_ids = [str(result.inserted_id)]

        return {
            "changed": True,
            "inserted_ids": inserted_ids,
            "message": f"Successfully imported data into {params['collection_name']}"
        }

    except PyMongoError as e:
        return {"failed": True, "msg": f"MongoDB operation failed: {e}"}
    except json.JSONDecodeError:
        return {"failed": True, "msg": f"Invalid JSON in file: {params['file_path']}"}

def main():
    # Define module arguments
    module_args = dict(
        login_host=dict(type='str', required=True),
        login_port=dict(type='int', required=True),
        login_user=dict(type='str', required=True),
        login_password=dict(type='str', required=True, no_log=True),
        login_database=dict(type='str', required=True),
        collection_name=dict(type='str', required=True),
        file_path=dict(type='str', required=True),
    )

    # Initialize the module
    module = AnsibleModule(argument_spec=module_args, supports_check_mode=True)

    # Call the import function
    result = import_json(module.params)

    # Handle result
    if result.get("failed"):
        module.fail_json(**result)
    else:
        module.exit_json(**result)


if __name__ == '__main__':
    main()
