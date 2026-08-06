#### GENERAL CONFIGS ####

variable "project_name" {
  type        = string
  description = "Nome do projeto. Usado como prefixo para os recursos criados e para as chaves de parametros no SSM Parameter Store."
  default     = "infra-network" # 
}

variable "region" {
  type        = string
  description = "Regiao da AWS onde os recursos serao criados (ex: us-east-1)."
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "O valor de 'region' deve seguir o formato de uma regiao AWS valida, ex: us-east-1."
  }
}

variable "environment" {
  type        = string
  description = "Nome do ambiente (dev, staging, prod). Usado para tagging e organizacao dos recursos."
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "O valor de 'environment' deve ser um dos seguintes: dev, staging, prod."
  }
}
