module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.29.0"

  cluster_name    = "my-eks-beto2"
  cluster_version = "1.26" # penultima version

  cluster_endpoint_private_access = true # endpoint de comuinicacion. de tener un bastion o una vpn para ingresar al cluster se utiliza, pero debe estar en true de igual manera.
  cluster_endpoint_public_access  = true # ambos puntos de acceso deben estar habilitados.

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # subnets para los wroker nodes

  enable_irsa = true # IAM roles for service accounts. Habilitaremos despues roles de IAM para cuentas de servicio.

  eks_managed_node_group_defaults = { # Se establece un tamaño de disco para los nodos
    disk_size = 50
  }

  # nodos administrados por kubernetes. Enfoque recomendado. k8s puede realizar actualizaciones continuas casi sin downtime.
  eks_managed_node_groups = { # Grupo de nodos estandard con tags asignados. 
    general = {               # primer grupo de nodos
      desired_size = 1
      min_size     = 1
      max_size     = 10

      labels = {  # El uso de tags personalizados en los nodos es comun, ya que es mas facil crear un nuevo grupo de nodos y migrar la carga de trabajo. estas etiquetas se se ajustan a los grupos de nodos que se creen luego.
        role = "general"
      }

      instance_types = ["t3.small"] # tipo de instancia
      capacity_type  = "ON_DEMAND"  # depende de la instancia a utilizar
    }

    spot = {  # segundo grupo de nodos. Se utilizaran instancias spot, mas baratos pero aws los puede recoger en cualquier momento
      desired_size = 1
      min_size     = 1
      max_size     = 10

      labels = {
        role = "spot"
      }

      taints = [{   # forma de etiquetar nodos del clúster para indicar ciertas restricciones o preferencias en la planificación de pods. NO_SCHEDULE, PREFER_NO_SCHEDULE, NO_EXECUTE
        key    = "market"
        value  = "spot"
        effect = "NO_SCHEDULE"  # significa que ningún nuevo pod será programado en un nodo que tenga este taint
      }]
                    # Es importante señalar que los taints deben coincidir con las tolerancias (effect) de los pods para que la planificación sea efectiva.

      instance_types = ["t3.micro"]
      capacity_type  = "SPOT"
    }
  }

# agg el manejo de configmap y agg los roles, usuario y grupos
  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = module.eks_admins_iam_role.iam_role_arn
      username = module.eks_admins_iam_role.iam_role_name
      groups   = ["system:masters"]
    },
  ]

# permitir el acceso desde el plano de control de EKS al puerto "webhook" del controlador del balanceador de carga de AWS.
  node_security_group_additional_rules = {
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    }
  }

  tags = {
    Environment = "develop"
  }
}

# debe autorizar a terraform para acceder a la API de Kubernetes y modificar aws-auth en el configmap
  # https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2009
data "aws_eks_cluster" "default" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "default" {
  name = module.eks.cluster_id
}
provider "kubernetes" {
    host                   = data.aws_eks_cluster.default.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
    # token                  = data.aws_eks_cluster_auth.default.token # metodo de autenticacion por medio de token temporal

    exec { # metodo por bloque exacto para recuperar el token con cada ejecucion de k8s 
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.default.id]
      command     = "aws"
    }
  }
