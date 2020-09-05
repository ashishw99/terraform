provider "kubernetes" {
  config_context = "minikube"
}

resource "kubernetes_namespace" "hybridwp" {
	metadata {
		name = "hybrid-wordpress"
	}
}

resource "kubernetes_deployment" "wp-deployment" {
	depends_on = [
		kubernetes_persistent_volume_claim.mypvc ,
		aws_db_instance.wp-backend
	]
	metadata {
		name = "k8s-wp"
		labels = {
			app = "wp"
		}
	}

    spec {
		replicas = 3
		selector {
			match_labels = {
				app = "wp"
			}
		}
		template{
			metadata {
				labels = {
					app = "wp"
				}
			}

			spec {		
				container {
					image = "wordpress:4.8-apache"
					env {
						name = "WORDPRESS_DB_HOST"
						value = "aws_db_instance.wp-backend.address"
					}
					env {
						name = "WORDPRESS_DB_USER"
						value = "aws_db_instance.wp-backend.username"
					}
					env {
						name = "WORDPRESS_DB_PASSWORD"
						value = "aws_db_instance.wp-backend.password"
					}
					env {
						name = "WORDPRESS_DB_NAME"
						value = "aws_db_instance.wp-backend.name"
					}	
					
					name = "wp-frontend-container"
					port {
						container_port = 80
					}
					volume_mount {
						name = "wp-persistent-storage"
						mount_path = "/var/www/html"
					
					}						
				}
				volume {
					name = "wp-persistent-storage"
					persistent_volume_claim {
						claim_name = kubernetes_persistent_volume_claim.mypvc.metadata.0.name
					}
				}
				
		  }
	   }
	}
}


