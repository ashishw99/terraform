

resource "kubernetes_service" "wpsvc" {
  depends_on = [kubernetes_deployment.wp-deployment]
  metadata {
    name = "wp-service"
    labels = {
      app = "wp"
    }
  }
  spec {
    selector = {
      app = "wp"
    }
    port {
      # Fixed The nodePort 
      node_port   = 30402
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}

output "wp-endpoint-url" {
  value = " Connect to the url : 192.168.99.101:${kubernetes_service.wpsvc.spec[0].port[0].node_port}"
 }