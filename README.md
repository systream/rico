rico - RIAK connector
=====

Maintain connections towards RIAK, and simplify some usual cases

## Pools

You can set up as many pools as you want. It can be configured in sys.config 

```erlang
 {pools, #{
        default => #{
          pool_size => 5,
          host => "localhost",
          port => "8087",
          user => "rico",
          pw => "ricopw",
          cacertfile => {priv_dir, rico, "rootCA.crt"},
          certfile => {priv_dir, rico, "rico.crt"},
          keyfile => {priv_dir, rico, "rico.key"}
        }
      }
    }
```

### certs
Please keep it mind. only secure connection supported.
Cert path can be set with `{priv_dir, app_name, "filename"}` so the file will be read from the app's priv dir, or
you can set absolute path like `"/path/to/a/file"`. 

#### Default pool
Default pool's properties can be overwritten with OS env parameters: 
* RIAK_HOST for RIAK host
* RIAK_PORT for RIAK port
* RIAK_USER for RIAK user
* RIAK_PW for RIAK user's pw
* RIAK_CACERTFILE for RIAK connection's cacertfile (only full path can be used)
* RIAK_CERTFILE for RIAK connection's certfile (only full path can be used)
* RIAK_KEYFILE for RIAK connection's keyfile (only full path can be used)
* POOL_SIZE for size of the pool


#### setup RIAK certs

#### Install riak
#### Generate ROOT
```bash
## Generate Root CA and CSR
openssl genrsa -out rootCA.key 2048
openssl req -new -key rootCA.key -out rootCA.csr -subj "/C=HU/O=Systream/OU=CliServ/CN=rootCA"

openssl x509 -req -days 365 -in rootCA.csr -signkey rootCA.key -out rootCA.crt
```

#### Generate RIAK Node's cert
```bash
# riak  node's cert
openssl genrsa -out riak_node.key 2048
openssl req -new -key riak_node.key -out riak_node.csr -subj "/C=HU/O=Systream/OU=CliServ/CN=systream.hu"

openssl x509 -req -days 365 -in riak_node.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out riak_node.crt

```

You need to set up the cert path in `riak.config`. You need to set 3 files
* rootCA.crt
* riak_node.key
* riak_node.crt

```bash
# generate user cert

openssl genrsa -out rico.key 2048
openssl req -new -key rico.key -out rico.csr -subj "/C=HU/O=Systream/OU=CliServ/CN=rico"

openssl x509 -req -days 365 -in rico.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out rico.crt
```

You need for the client the following files:
* rico.key 
* rico.crt 
* rootCA.crt


Build
-----

    $ rebar3 compile
