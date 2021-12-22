# FMDB 4 (written in Swift)

Gus is playing around with porting FMDB to Swift. This is a work in progress obviously.


## Random Stuff:

The various format: apis (such as `executeUpdateWithFormat:`) are not present. I'm not sure they will be - they feel kind of … wrong.

FMDatabaseQueue has not been implemented. Actually a bunch of things are missing.

## Changes from the Objective-C version

Subscripting a result set will no longer return [NSNull null], instead it'll return nil for null values. Is that good or bad?




