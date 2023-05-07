# AKS with Terraform
Azure Kubernetes Service (AKS) with Terraform.

## Prerequisites

- Create [Azure account](https://portal.azure.com)
- Install [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Install [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

## Creating credentials

Once you've established an Azure account and installed az on your machine, it's necessary to sign in prior to initiating the creation process.

```bash
az login 
```

[check latency](https://www.azurespeed.com/Azure/Latency)

```bash
# List of available regions
az account list-locations --query "[].{Name:name, DisplayName:displayName}" -o table
```

An authentication prompt should have appeared in your browser. Adhere to the given guidelines. With that completed, we can advance by generating a new resource group. If you're a novice to Azure, be aware that all components are arranged within resource groups.

```bash
# Create resource group
az group create --name aks-test --location northeurope

# List the resource groups
az group list -o table
```

## Azure Provider

For more information please visit and read the official [documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs).

For the first initialization we need the following files/configs:

```bash
.
├── provider.tf
└── variables.tf
```

### provider.tf

- provider "azurerm": This line specifies that the Terraform script will use the "azurerm" provider to manage Azure resources.
- features {}: This block is a mandatory configuration for the "azurerm" provider, which is used to enable or disable specific resource provider features. As of version 2.x of the AzureRM Provider, an empty features block is required to be specified even if no features are enabled or disabled. In the given configuration, the features block is empty, which means that all resource provider features will use their default settings.

### variables.tf

- region: The Azure region where the resources will be deployed (default value: "northeurope").
- resource_group: The name of the resource group to be created or used (default value: "aks-test").
- cluster_name: The name of the Kubernetes cluster to be created (default value: "aks-test").
- control_nodes: The name of the Kubernetes control plane nodes. (default value: "akscontrol")
- worker_noded: The name of the Kubernetes worke nodes. (default value: "aksworker")
- dns_prefix: The DNS prefix for the Kubernetes cluster (default value: "aks-test").
- k8s_version: The version of Kubernetes to be used for the cluster. No default value is provided, so it must be specified when running terraform apply.
- min_node_count: The minimum number of nodes in the Kubernetes cluster's node pool (default value: 3).
- max_node_count: The maximum number of nodes in the Kubernetes cluster's node pool (default value: 6).
- machine_type: The virtual machine size for the nodes in the cluster (default value: "Standard_D2_v2").

Initialize the project:

```bash
terraform init
```

Retrieve the **supported** Kubernetes versions for AKS in the specified location (region).

```bash
az aks get-versions --location northeurope -o table
```

Apply the changes:

```bash
terraform apply
```

## Creating the Control Plane

A Kubernetes cluster typically comprises a control plane and at least one group of worker nodes. When using AKS, we can establish the default worker node group during the creation of the control plane, with the option to add more later on. We will begin with setting up the control plane and default node group, and then progress to incorporating extra groups. The [azurerm_kubernetes_cluster](https://www.terraform.io/docs/providers/azurerm/r/kubernetes_cluster.html) module can be utilized to generate an AKS control plane and a default worker node group.

```bash
.
├── controlPlane.tf
├── provider.tf
├── variables.tf
```

- resource "azurerm_kubernetes_cluster" "primary": This line defines a resource of type azurerm_kubernetes_cluster with the name "primary". This resource will create an AKS cluster.
- name, location, resource_group_name, dns_prefix, and kubernetes_version are attributes specifying the cluster's name, region, resource group, DNS prefix, and Kubernetes version, respectively. These values are derived from the corresponding variables defined elsewhere in your Terraform code.
- default_node_pool is a block that configures the default worker node pool for the AKS cluster:
    - name: The name of the default node pool, set using the var.control_nodes variable.
    - vm_size: The size of the Virtual Machines (VMs) in the node pool, determined by the var.machine_type variable.
    - enable_auto_scaling: A boolean flag enabling auto-scaling for the node pool.
    - max_count and min_count: The maximum and minimum number of nodes allowed in the auto-scaling node pool, set using the var.max_node_count and var.min_node_count variables.
- identity is a block that sets up the identity for the AKS cluster:
    - type = "SystemAssigned": This line specifies that the AKS cluster will use a System Assigned Managed Identity, which is an Azure Active Directory identity automatically created and managed by Azure.

To make it more convenient when running future commands that may require a valid Kubernetes version, we will save the chosen version in an environment variable.

```bash
# Kubernetes Version
export K8S_VER='1.26.0'
```

At this point, we can proceed to apply the configuration and establish the control plane.

```bash
terraform apply --var k8s_version=$K8S_VER
```

Assuming you don't remember the cluster name, resource group and region, or you didn't pay close attention, we can still access the required information using Terraform outputs, as long as it's available in the Terraform state. This scenario offers an excellent opportunity to showcase how Terraform outputs can be helpful in extracting specific information.

### output.tf

- cluster_name: This output variable displays the value of the input variable cluster_name, which represents the name of the Kubernetes cluster.
- region: This output variable shows the value of the input variable region, which indicates the region in which the resources are deployed.
- resource_group: This output variable presents the value of the input variable resource_group, which refers to the resource group that contains the deployed resources.

```bash
# Update the state file to reflect the actual state of the infrastructure.
terraform refresh --var k8s_version=$K8S_VER 

# Outputs:
cluster_name = "aks-test"
region = "northeurope"
resource_group = "aks-test"
```

By running the following command allows you to update your local kubeconfig file with the necessary information to interact with your AKS cluster using kubectl or other Kubernetes tools, even if you don't have the cluster name and resource group information readily available.

```bash
az aks get-credentials --name $(terraform output --raw cluster_name) --resource-group $(terraform output --raw resource_group)
```

```bash
kubectl get nodes -o wide
```

## Creating Worker nodes

Worker nodes can be managed using the [azurerm_kubernetes_cluster_node_pool](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_node_pool.html) module in Terraform.

```bash
.
├── controlPlane.tf
├── output.tf
├── provider.tf
├── variables.tf
└── workerNodes.tf
```

### workerNodes.tf

- resource "azurerm_kubernetes_cluster_node_pool" "secondary": This line creates a new secondary node pool for an AKS cluster using the azurerm_kubernetes_cluster_node_pool resource type and assigns it the identifier secondary.
- name = var.worker_nodes: This line sets the name of the secondary node pool using the variable worker_nodes.
- kubernetes_cluster_id = azurerm_kubernetes_cluster.primary.id: This line associates the secondary node pool with an existing AKS cluster, using the cluster's ID, which is retrieved from the azurerm_kubernetes_cluster.primary resource.
- vm_size = var.machine_type: This line specifies the virtual machine size (the type of worker nodes) for the secondary node pool using the variable machine_type.
- enable_auto_scaling = true: This line enables auto-scaling for the secondary node pool, allowing it to automatically adjust the number of nodes based on demand.
- max_count = var.max_node_count: This line sets the maximum number of nodes allowed in the secondary node pool using the variable max_node_count.
- min_count = var.min_node_count: This line sets the minimum number of nodes allowed in the secondary node pool using the variable min_node_count.


```bash
terraform apply --var k8s_version=$K8S_VER
```

We've successfully established a cluster by employing Infrastructure as Code via Terraform!

```bash
kubectl get nodes -o wide
```

### Destroying the Cluster and resources.

Destroy the AKS cluster.

```bash
terraform destroy --var k8s_version=$K8S_VER --target azurerm_kubernetes_cluster.primary
```

Delete the resource group. Please note that deleting a resource group will also delete all resources contained within it. 

```bash
az group delete --name aks-test --yes --no-wait
```


