# se crea una función de IAM para el controlador del balanceador de carga con permisos para crear y administrar balanceadores de carga de AWS.
module "aws_load_balancer_controller_irsa_role" { # rol del lb controller
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.3.1"

  role_name = "aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" { # lanzador del helm, por defecto crea 2 replicas, pero para este demo se utilizará 1.
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.4.4"

  set {
    name  = "replicaCount"
    value = 1 # 2 por defecto
  }

  set {
    name  = "clusterName" # importante espefificar
    value = module.eks.cluster_id
  }

  set {
    name  = "serviceAccount.name" # importante espefificar
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" # importante espefificar para permitir que esta cuenta de servicio asuma el rol de iam
    value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
  }
}

