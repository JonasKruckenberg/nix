let
  jonas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF4p5xyCPbCfuOf+bCNXTi0pcDNXsAdcABSEcgx/WujU";

  # ardmore's dedicated agenix host key (the key at age.identityPaths) lets the server decrypt
  # at activation.
  ardmore = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGUKx/lzVEe1tJbz4Dcx58PoNMGvQ8O3zjKiJjasDJbs";
in
{
  "bulletin-smtp.age".publicKeys = [
    jonas
    ardmore
  ];
}
