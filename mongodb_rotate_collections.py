#!/usr/bin/python

from ansible.module_utils.basic import AnsibleModule
from pymongo import MongoClient
from pymongo.errors import PyMongoError

DOCUMENTATION = r'''
---
module: mongodb_rotate_collections
short_description: Rotate MongoDB collections by removing older documents
version_added: "1.0.0"
author: Steve Widdoes
description:
    - This module connects to a MongoDB collection, counts the number of documents,
      and deletes the oldest entries if the total exceeds a specified limit.
    - The oldest documents are determined using the "dateCollected" field.
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
        no_log: true
    login_database:
        description:
            - The database to authenticate against.
        required: true
        type: str
    collection_name:
        description:
            - The name of the MongoDB collection to rotate.
        required: true
        type: str
    keep_count:
        description:
            - The number of most recent documents to retain.
        required: true
        type: int
author:
    - Your Name (@yourgithubhandle)
'''

EXAMPLES = r'''
- name: Rotate MongoDB collections and keep only the last 5 records
  mongodb_rotate_collections:
    login_host: "mongodb.example.com"
    login_port: 27017
    login_user: "admin"
    login_password: "securepassword"
    login_database: "mydatabase"
    collection_name: "CDRIFT"
    keep_count: 5
  register: result

- debug:
    msg:
      - "Changed: {{ result.changed }}"
      - "Deleted IDs: {{ result.deleted_ids }}"
      - "Remaining Count: {{ result.remaining_count }}"
'''

RETURN = r'''
changed:
    description: Indicates whether any documents were deleted.
    returned: always
    type: bool
deleted_ids:
    description: List of deleted document IDs.
    returned: when documents were deleted
    type: list
remaining_count:
    description: The number of documents left after rotation.
    returned: always
    type: int
message:
    description: Status message regarding the rotation.
    returned: always
    type: str
'''

def rotate_collections(params):
    """Rotate oldest collections if count exceeds the limit."""
    try:
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

        # Count documents in the collection
        count = collection.count_documents({})
        excess = count - params['keep_count']

        # Delete oldest documents if excess exists
        if excess > 0:
            oldest_docs = collection.find().sort([("dateCollected", 1)]).limit(excess)
            deleted_ids = [doc["_id"] for doc in oldest_docs]
            collection.delete_many({"_id": {"$in": deleted_ids}})
            return {"changed": True, "deleted_ids": deleted_ids, "remaining_count": count - excess}
        else:
            return {"changed": False, "message": "No documents deleted, within limit."}
    except PyMongoError as e:
        return {"failed": True, "msg": f"MongoDB operation failed: {e}"}


def main():
    module_args = dict(
        login_host=dict(type='str', required=True),
        login_port=dict(type='int', required=True),
        login_user=dict(type='str', required=True),
        login_password=dict(type='str', required=True, no_log=True),
        login_database=dict(type='str', required=True),
        collection_name=dict(type='str', required=True),
        keep_count=dict(type='int', required=True),
    )

    module = AnsibleModule(argument_spec=module_args, supports_check_mode=True)
    result = rotate_collections(module.params)

    if result.get("failed"):
        module.fail_json(**result)
    else:
        module.exit_json(**result)


if __name__ == '__main__':
    main()
