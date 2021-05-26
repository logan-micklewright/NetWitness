db = db.getSiblingDB('security-server')

print("CUT_TO_HERE")

printjson(  db.getCollection('role').find({  }, { _id: 1, permissions: 1}).toArray() );
