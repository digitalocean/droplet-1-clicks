storage "raft" {
    path        = "/vault/data"
    node_id     = "node1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

disable_mlock   = true
# port 8200
api_addr        = "http://0.0.0.0:8200"
# port 8201
cluster_addr    = "http://0.0.0.0:8201"
ui              = true