config :libcluster,
  topologies: [
    plant_cluster: [
      strategy: Cluster.Strategy.Epmd,
      config: [
        hosts: [
          # IP вашего Mac
          :"node1@192.168.1.10",
          # IP вашего ПК
          :"node2@192.168.1.20"
        ]
      ],
      connect: {:net_kernel, :connect_node, []}
    ]
  ]
