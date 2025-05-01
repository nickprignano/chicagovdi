# Azure Prerequisites Setup for Nerdio Manager for Enterprise
# This script sets up the Azure prerequisites for Nerdio Manager for Enterprise in an empty subscription

# Run as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as an Administrator!"
    break
}

Write-Host "Starting Azure prerequisites setup for Nerdio Manager for Enterprise..." -ForegroundColor Green

# Step 1: Install required PowerShell modules
Write-Host "Installing required PowerShell modules..." -ForegroundColor Cyan
$requiredModules = @(
    "Az.Accounts",
    "Az.Resources",
    "Az.Network",
    "Az.Compute",
    "Az.DesktopVirtualization",
    "Az.Storage"
)

foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing $module module..." -ForegroundColor Yellow
        Install-Module -Name $module -Force -AllowClobber
    } else {
        Write-Host "$module module already installed" -ForegroundColor Green
    }
}

# Step 2: Connect to Azure
Write-Host "Connecting to Azure..." -ForegroundColor Cyan
Connect-AzAccount

# Step 3: List and select subscriptions
$subscriptions = Get-AzSubscription
Write-Host "Available Subscriptions:" -ForegroundColor Cyan
for ($i = 0; $i -lt $subscriptions.Count; $i++) {
    Write-Host "[$i] $($subscriptions[$i].Name) ($($subscriptions[$i].Id))"
}

$subscriptionIndex = Read-Host "Select the subscription to use (enter the number)"
$subscription = $subscriptions[$subscriptionIndex]
$subscriptionId = $subscription.Id
$subscriptionName = $subscription.Name

# Set context to the selected subscription
Write-Host "Setting context to subscription: $subscriptionName" -ForegroundColor Cyan
Set-AzContext -Subscription $subscriptionId

# Step 4: Register necessary resource providers
Write-Host "Registering required Azure resource providers..." -ForegroundColor Cyan
$requiredProviders = @(
    "Microsoft.AAD",
    "Microsoft.Authorization",
    "Microsoft.Compute",
    "Microsoft.DesktopVirtualization",
    "Microsoft.KeyVault",
    "Microsoft.Network",
    "Microsoft.ResourceGraph",
    "Microsoft.Resources",
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.Web",
    "Microsoft.ManagedIdentity"
)

foreach ($provider in $requiredProviders) {
    Write-Host "Registering provider: $provider" -ForegroundColor Yellow
    Register-AzResourceProvider -ProviderNamespace $provider
}

# Step 5: Create a Resource Group for Nerdio Manager
$location = Read-Host "Enter Azure region for deployment (e.g., eastus, westeurope)"
$rgName = Read-Host "Enter name for the Nerdio Manager resource group"

Write-Host "Creating resource group: $rgName in $location..." -ForegroundColor Cyan
New-AzResourceGroup -Name $rgName -Location $location

# Step 6: Create a Virtual Network for AVD
$vnetName = Read-Host "Enter name for the Virtual Network"
$vnetAddressPrefix = Read-Host "Enter address space for VNet (e.g., 10.0.0.0/16)"
$subnetName = Read-Host "Enter name for the subnet"
$subnetAddressPrefix = Read-Host "Enter address range for subnet (e.g., 10.0.0.0/24)"

Write-Host "Creating Virtual Network: $vnetName..." -ForegroundColor Cyan
$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
$vnet = New-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet

# Step 7: Create a Network Security Group
$nsgName = "$vnetName-nsg"
Write-Host "Creating Network Security Group: $nsgName..." -ForegroundColor Cyan
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $rgName -Location $location -Name $nsgName

# Add RDP inbound rule
Write-Host "Adding RDP rule to NSG..." -ForegroundColor Cyan
Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name "Allow-RDP" -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 | Set-AzNetworkSecurityGroup

# Associate NSG to subnet
Write-Host "Associating NSG with subnet..." -ForegroundColor Cyan
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet
$vnet = Set-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet -AddressPrefix $subnetAddressPrefix -NetworkSecurityGroup $nsg | Set-AzVirtualNetwork

# Step 8: Export information for Nerdio Manager setup
$outputFile = "$env:USERPROFILE\nerdio-setup-info.txt"
@"
Nerdio Manager for Enterprise - Setup Information
------------------------------------------------
Date: $(Get-Date)

Subscription: $subscriptionName ($subscriptionId)
Resource Group: $rgName
Location: $location

Virtual Network: $vnetName
Virtual Network ID: $($vnet.Id)
Subnet: $subnetName
Subnet ID: $($vnet.Subnets[0].Id)

Next Steps:
1. Install Nerdio Manager for Enterprise from the Azure Marketplace
2. Use the subscription, resource group, and region information above
3. During Nerdio Manager setup, select the Virtual Network and Subnet created by this script
"@ | Out-File -FilePath $outputFile

Write-Host "Azure prerequisites for Nerdio Manager for Enterprise have been set up successfully!" -ForegroundColor Green
Write-Host "Setup information has been saved to: $outputFile" -ForegroundColor Yellow
Write-Host "You can now proceed with installing Nerdio Manager for Enterprise from the Azure Marketplace." -ForegroundColor Yellow
