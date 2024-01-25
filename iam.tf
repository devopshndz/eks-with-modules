# otorgar acceso a cargas de trabajo mediante IAM a otros usuarios y roles.
# Accesos mediante IAM Role:

module "allow_eks_access_iam_policy" { # politica de permiso de acceso a eks. Se necesita actualizar inicialmente el contexto de k8s y obtener acceso al cluster.
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.3.1"

  name          = "allow-eks-access"
  create_policy = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:DescribeCluster",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

module "eks_admins_iam_role" { # Iam role que debemos usar para acceder al cluster. Lo vincularemos con grupo de k8s sistem master con acceso completo a k8s
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.3.1"

  role_name         = "eks-admin"
  create_role       = true
  role_requires_mfa = false # opcional, activar la autenticacion mutifactor.

  custom_role_policy_arns = [module.allow_eks_access_iam_policy.arn] # se adjunta la politica que se acaba de crear con el modulo anterior

  trusted_role_arns = [ # Esta es una lista de ARN de roles de confianza
    "arn:aws:iam::${module.vpc.vpc_owner_id}:root" # ARN de rol de confianza específico. En este caso, se está usando el ARN del propietario de la VPC (Virtual Private Cloud) en la que se encuentra el clúster de EKS.
  ]
}

# module "user_prueba_iam_user" { # creacion de usuario de prueba para asignacion de roles
#   source  = "terraform-aws-modules/iam/aws//modules/iam-user"
#   version = "5.3.1"

#   name                          = "userprueba"
#   create_iam_access_key         = false # deshabilitada la creacion de claves de acceso 
#   create_iam_user_login_profile = false # deshabilitado el perfil de inicio de sesion
#   # lo generamos desde la interfaz de uuario

#   force_destroy = true
# }

module "allow_assume_eks_admins_iam_policy" { # politica que permite asumir el rol de admin de eks
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.3.1"

  name          = "allow-assume-eks-admin-iam-role"
  create_policy = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
        ]
        Effect   = "Allow"
        Resource = module.eks_admins_iam_role.iam_role_arn
      },
    ]
  })
}

module "eks_admins_iam_group" { # grupo de iam con la politica anterior.
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "5.3.1"

  name                              = "eks-admin"
  attach_iam_self_management_policy = false
  create_group                      = true
  # group_users                       = [module.user_prueba_iam_user.iam_user_name] # se agrega al usuario 1 a este grupo
  custom_group_policy_arns          = [module.allow_assume_eks_admins_iam_policy.arn]
}

