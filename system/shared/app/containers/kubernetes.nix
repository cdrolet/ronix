# kubectl, kubectx & kubens - Kubernetes client, context and namespace switcher
#
# Purpose: Command-line interface for Kubernetes cluster management
# Platform: Cross-platform
# Website:
#   https://kubernetes.io/
#   https://github.com/ahmetb/kubectx
#
# Features:
#   - Manage Kubernetes clusters
#   - Deploy and manage applications
#   - Inspect cluster resources
#   - View logs and debug
#   - kubectx: Switch between Kubernetes contexts quickly
#   - kubens: Switch between Kubernetes namespaces quickly
#   - Interactive mode with fzf integration
#   - Rename contexts for easier identification
#
# Installation: Via nixpkgs
{
  config,
  pkgs,
  lib,
  ...
}: let
  appHelpers = import ../../../shared/lib/app-helpers.nix {inherit lib;};
  hasKubectl = appHelpers.hasAppInCategory config "containers" "kubernetes";
in {
  # Install Kubernetes tools
  # Note: kubectx package includes both kubectx and kubens binaries
  home.packages = [
    pkgs.kubectl # Kubernetes CLI
    pkgs.kubectx # Includes kubectx and kubens
  ];

  # Warn if kubectx is installed without kubectl
  warnings = lib.optional (!hasKubectl) ''
    kubectx requires 'kubectl' to be installed.
    The 'kubernetes' app includes both kubectl and kubectx.
  '';

  # Shell aliases
  home.shellAliases = {
    k = "kubectl";
    kgp = "kubectl get pods";
    kgs = "kubectl get services";
    kgd = "kubectl get deployments";
    kdp = "kubectl describe pod";
    kl = "kubectl logs";
    kexec = "kubectl exec -it";
    kctx = "kubectx";
    kns = "kubens"; # Provided by kubectx package
  };
}
