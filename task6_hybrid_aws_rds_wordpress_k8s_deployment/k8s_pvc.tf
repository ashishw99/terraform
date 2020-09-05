resource "kubernetes_persistent_volume_claim" "mypvc" {
  metadata {
    name = "wordpress-pvc"
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
    
  }
}
