db = db.getSiblingDB('security-server')

print("CUT_TO_HERE")

printjson( db.getCollection('user').find( { successfulLoginTimestamps : { $exists: false } }, { _id: 1, name: 1} ).toArray() );