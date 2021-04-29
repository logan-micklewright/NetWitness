db = db.getSiblingDB('security-server')

print("CUT_TO_HERE")

printjson(  db.getCollection('role').find({ createdBy : { $ne : "system" } }, { _id: 1, permissions: 1}).toArray() );
