provider "kubernetes" {
    config_path    = "~/.kube/config"
    config_context = var.context
}

module "strimzi_ns" {
  source = "./modules/strimzi"
}

#Namespace para deploy do cluster operator
#resource "kubernetes_namespace" "kafka_cluster" {
#    metadata {
#      name = "production"
#    }
#}

resource "kubernetes_role_binding" "strimzi_cluster_operator" {
  metadata {
    name = "strimzi-cluster-operator"
    namespace = "application"
    labels = {
      app = "strimzi"
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = "strimzi-cluster-operator"
    namespace = "strimzi"
  }

  role_ref {
    kind     = "ClusterRole"
    name     = "strimzi-cluster-operator-namespaced"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "null_resource" "apply_cluster_role" {
  provisioner "local-exec" {
    command = "kubectl create -f modules/strimzi/manifests/031-RoleBinding-strimzi-cluster-operator-entity-operator-delegation.yaml -n application"
  }

}


resource "null_resource" "apply_kubectl_create" {
  provisioner "local-exec" {
    command = "kubectl create -f modules/strimzi/manifests/ -n strimzi"
  }

  depends_on = [null_resource.apply_cluster_role]
}

resource "null_resource" "apply_kafka_manifest" {
  provisioner "local-exec" {
    command = "kubectl create -n application -f modules/kafka/manifests/ "
  }

  depends_on = [null_resource.apply_kubectl_create]
}

resource "null_resource" "wait_cluster_ready" {
  provisioner "local-exec" {
    command = "kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n application"
  }
  depends_on = [null_resource.apply_kafka_manifest]

}

resource "kubernetes_job" "kafka_producer_job" {
  metadata {
    name = "kafka-producer-job"
    namespace = "application"
  }

  spec {
    template {
      metadata {
        labels = {
          job = "kafka-producer"
        }
      }

      spec {
        container {
          name  = "kafka-producer-container"
          image = "strimzi/kafka:latest" # Imagem do Kafka do Strimzi que contém o kafka-producer-perf-test
          command = ["bin/kafka-producer-perf-test.sh"]
          args = [
            "--topic", "app-topic",
            "--num-records", "1000",  # Número total de mensagens a serem produzidas
            "--record-size", "1024",  # Tamanho de cada mensagem
            "--throughput", "100",    # Taxa de produção de mensagens por segundo
            "--producer-props",
            "bootstrap.servers=my-cluster-kafka-brokers:9092",  # Endereço do bootstrap server
            "acks=all"
          ]
        }
        restart_policy = "Never"
      }
    }
  }
  depends_on = [null_resource.wait_cluster_ready]
}









#resource "null_resource" "cleanup" {
#  # Este recurso não faz nada além de executar um comando local durante o terraform destroy
#  triggers = {
#    always_run = "${timestamp()}"
#  }
#
#  provisioner "local-exec" {
#    command = "kubectl delete -f modules/strimzi/manifests/031-RoleBinding-strimzi-cluster-operator-entity-operator-delegation.yaml -n application"
#    
#    when = destroy
#  }
#}


#locals {
#  kafka_crd = yamldecode(file("${path.module}/modules/strimzi/manifests/040-Crd-kafka.yaml"))
#  kafka_manifest = yamldecode(file("${path.module}/modules/kafka/manifests/kafka.yaml"))
#}


#resource "kubernetes_manifest" "install_kafka_crd" {
#  manifest = local.kafka_crd
#  depends_on = [null_resource.apply_kubectl_create]
#}

#resource "kubernetes_manifest" "my_kafka_cluster" {
#  manifest = local.kafka_manifest
#  depends_on = [kubernetes_manifest.install_kafka_crd]
#}modules/strimzi/manifests/031-ClusterRole-strimzi-entity-operator.yaml


#comandos

#kubectl delete -f modules/strimzi/manifests/031-RoleBinding-strimzi-cluster-operator-entity-operator-delegation.yaml -n application
#kubectl delete -f modules/strimzi/manifests/ -n strimzi
#kubectl delete -n application -f modules/kafka/manifests/


#bin/kafka-console-consumer.sh --bootstrap-server my-cluster-kafka-brokers:9092 --topic app-topico --from-beginning
