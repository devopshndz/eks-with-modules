# escalar automáticamente segun la carga que se tenga.
# se puede utilizar karpenter, el cual crea nodos de kubernetes usando instancias ec2 segun la carga seleccionando el tipo de instancia apropiado.
# Utilizar un cluster-autoscaler. Se usa luego de escalar grupos para ajustar el tamaño de la carga

module "cluster_autoscaler_irsa_role" { # para cuentas de servicio de eks para poder tener permismos de modificacion de grupos despues de escalar
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.3.1"

  role_name                        = "cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_ids   = [module.eks.cluster_id]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
}
