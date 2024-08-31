module "github_repository" {
    source = "github.com/den-vasyliev/tf-github-repository"
    github_owner           = var.github_owner      # match with module variable
    github_token           = var.github_token 
    repository_name = var.FLUX_GITHUB_REPO
    public_key_openssh = module.tls_private_key.public_key_openssh
    public_key_openssh_title = "flux0"
    
}

module "tls_private_key" {
    source = "./modules/tf-hashicorp-tls-keys"
    algorithm = "RSA"
}
module "gke_cluster" {
  source         = "github.com/SartSR/tf-google-gke-cluster"
  GOOGLE_REGION  = var.GOOGLE_REGION
  GOOGLE_PROJECT = var.GOOGLE_PROJECT
  GKE_NUM_NODES  = 1
  GKE_MACHINE_TYPE = var.GKE_MACHINE_TYPE
}
module "flux_bootstrap" {
    source = "github.com/SartSR/tf-fluxcd-flux-bootstrap"
    github_repository = "${var.github_owner}/${var.FLUX_GITHUB_REPO}"
    github_token      = var.github_token
    private_key = module.tls_private_key.private_key_pem
    config_path = module.gke_cluster.kubeconfig
  
}
module "gke-workload-identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  use_existing_k8s_sa = true
  name                = "kustomize-controller"
  namespace           = "flux-system"
  cluster_name        = "main"
  project_id          = var.GOOGLE_PROJECT
  location            = var.GOOGLE_REGION
  annotate_k8s_sa     = true
  roles               = ["roles/cloudkms.cryptoKeyEncrypterDecrypter"]
}

module "kms" {
  source          = "github.com/den-vasyliev/terraform-google-kms"
  project_id      = var.GOOGLE_PROJECT
  keyring         = "sops-flux"
  location        = "global"
  keys            = ["sops-key-flux"]
  prevent_destroy = false
}


