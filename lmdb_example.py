#! /bin/false
import lmdb
with lmdb.open('t.lmdb') as env:
  with env.begin(write=True) as txn:
    for i in xrange(1000):
      txn.put(str(i ** 5), str(i))

# Expected output:
# (0, '0')
# (1, '1')
# (32, '2')
# (243, '3')
# (1024, '4')
# (3125, '5')
# (7776, '6')
# (16807, '7')
# (32768, '8')
# (59049, '9')
with lmdb.open('t.lmdb') as env:
  with env.begin() as txn:
    for i in xrange(100000):
      v = txn.get(str(i))
      if v is not None:
        print (i, v)
