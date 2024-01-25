module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"

  name = "vpc-eks-beto"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.0.0/19", "10.0.32.0/19"] # worker nodes y ruta a nat
  public_subnets  = ["10.0.64.0/19", "10.0.96.0/19"] # para exponer la app a internet con igw

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
# El controlador del equilibrador de carga (helm-lb-controller) utiliza etiquetas para descubrir subredes en las que puede crear equilibradores de carga
# Utiliza una una equita "elb" para implementar balanceadores de carga públicos para exponer servicios a Internet y "internal-elb" para que los balanceadores de carga privados 
# expongan servicios solo dentro de su VPC.

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false # 1 unica puerta nat o una por zonas para mayor disponibilidad. Buena practica: una unica nat e implementar ips elasticas.
  
  enable_dns_hostnames = true # se utiliza para tener compatibilidad con DNS. Es comun que muchos servicios de AWS lo requieran, ejemplo EFS, podriamos montar un unico EFS en multiples pods
  enable_dns_support   = true

  tags = {
    Environment = "develop"
  }
}
