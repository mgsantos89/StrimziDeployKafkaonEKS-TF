#Namespace para deploy do cluster operator
resource "kubernetes_namespace" "strimzi" {
    metadata {
      name = "strimzi"
    }
}