let
  jonas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF4p5xyCPbCfuOf+bCNXTi0pcDNXsAdcABSEcgx/WujU";

  # ardmore's dedicated agenix host key (the key at age.identityPaths) lets the server decrypt
  # at activation.
  ardmore = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILbXc4uZ30kUyGz+Z4HmIBHs9Ph3rQqRGRmsANceUvIc";
in
{
  "bulletin-smtp.age".publicKeys = [
    jonas
    ardmore
  ];
}
